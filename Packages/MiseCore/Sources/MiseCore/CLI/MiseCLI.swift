import Foundation
import Darwin

/// Spawns mise (and the install helpers), streaming every output line into `output`.
/// The resolved mise path is cached once found; while missing it is re-resolved on every
/// call so an in-app install is picked up immediately.
public actor MiseCLI: CommandRunner {
    /// Single-consumer stream of all subprocess output. The app fans it out to the log and status bar.
    public nonisolated let output: AsyncStream<OutputLine>
    private let emit: AsyncStream<OutputLine>.Continuation
    private let environment: [String: String]
    /// Ceiling for read-only queries (`ls`, `ls-remote`, …) so a hung mise cannot freeze the UI.
    private let queryTimeout: Duration
    /// How long a terminated process gets to exit before it is SIGKILLed.
    private let killGrace: Duration
    private var cachedExecutable: String?

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        queryTimeout: Duration = .seconds(120), killGrace: Duration = .seconds(2)
    ) {
        self.environment = environment
        self.queryTimeout = queryTimeout
        self.killGrace = killGrace
        (output, emit) = AsyncStream.makeStream()
    }

    public func executable() -> String {
        if let cached = cachedExecutable, FileManager.default.fileExists(atPath: cached) { return cached }
        let resolved = PathResolver.resolveMiseExecutable(environment: environment)
        if resolved.hasPrefix("/"), FileManager.default.fileExists(atPath: resolved) { cachedExecutable = resolved }
        return resolved
    }

    /// Only these are bounded by `queryTimeout`; anything else may be installing or updating
    /// and runs to completion (task cancellation still stops it).
    static func isQuery(_ args: [String]) -> Bool {
        switch args.first {
        case "--version", "ls", "ls-remote": true
        case "plugins": args.count > 1 && ["ls", "ls-remote"].contains(args[1])
        default: false
        }
    }

    public func runMise(_ args: [String]) async throws -> CommandResult {
        let exe = executable()
        let path = PathResolver.augmentedPATH(environment: environment)
        guard FileManager.default.fileExists(atPath: exe) else {
            throw MiseError("failed to spawn mise executable '\(exe)' (PATH='\(path)'): No such file or directory")
        }
        do {
            return try await Self.run(
                program: exe, args, path: path, environment: environment,
                timeout: Self.isQuery(args) ? queryTimeout : nil, killGrace: killGrace, emit: emit)
        } catch let error as MiseError {
            throw error
        } catch let error as CancellationError {
            throw error
        } catch {
            throw MiseError("failed to spawn mise executable '\(exe)' (PATH='\(path)'): \(error.localizedDescription)")
        }
    }

    // ponytail: also uses the augmented PATH (Rust used the bare process env, which
    // lacks /opt/homebrew/bin inside a GUI app, so `brew` could not be found).
    public func runShell(_ program: String, _ args: [String]) async throws -> CommandResult {
        do {
            return try await Self.run(
                program: program, args, path: PathResolver.augmentedPATH(environment: environment),
                environment: environment, timeout: nil, killGrace: killGrace, emit: emit)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw MiseError(error.localizedDescription)
        }
    }

    /// `/usr/bin/env <program> args…` so bare names resolve against the PATH we pass in.
    /// On timeout, cancellation or a pipe failure the child's process group is terminated
    /// (SIGKILL after `killGrace`) and the child reaped before the error propagates.
    static func run(
        program: String, _ args: [String], path: String, environment base: [String: String],
        timeout: Duration?, killGrace: Duration, emit: AsyncStream<OutputLine>.Continuation
    ) async throws -> CommandResult {
        try Task.checkCancellation()  // cancelled before launch: spawn nothing
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [program] + args
        var environment = base
        environment["PATH"] = path
        process.environment = environment
        let stdout = Pipe(), stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        // `status` feeds the cancellable task group below; `reaped` lets the cleanup path wait for
        // the kill to land from a task that has already been cancelled.
        let (status, statusContinuation) = AsyncStream<Int32>.makeStream()
        let (reaped, reapedContinuation) = AsyncStream<Int32>.makeStream()
        process.terminationHandler = { finished in
            for continuation in [statusContinuation, reapedContinuation] {
                continuation.yield(finished.terminationStatus)
                continuation.finish()
            }
        }
        try process.run()
        let pid = process.processIdentifier
        let reap = Task { for await _ in reaped {} }

        do {
            let result = try await withThrowingTaskGroup(of: Event.self) { group in
                group.addTask { .stdout(try await collect(stdout.fileHandleForReading, .stdout, emit)) }
                group.addTask { .stderr(try await collect(stderr.fileHandleForReading, .stderr, emit)) }
                group.addTask { var code: Int32 = -1; for await finished in status { code = finished }; return .exit(code) }
                if let timeout {
                    group.addTask {
                        try await Task.sleep(for: timeout)
                        let command = ([URL(fileURLWithPath: program).lastPathComponent] + args).joined(separator: " ")
                        throw MiseError("\(command) timed out after \(timeout)")
                    }
                }
                var result = CommandResult(stdout: "", stderr: "", exitCode: -1)
                for _ in 0..<3 {
                    guard let event = try await group.next() else { break }
                    switch event {
                    case .stdout(let text): result.stdout = text
                    case .stderr(let text): result.stderr = text
                    case .exit(let code): result.exitCode = code
                    }
                }
                group.cancelAll()  // both pipes at EOF and the child reaped: stop the timer
                return result
            }
            // Cancelled readers return whatever they had so far; never pass that off as a result.
            try Task.checkCancellation()
            return result
        } catch {
            // Foundation makes the child the leader of its own process group, so signalling the
            // group also reaches mise's own children (git, plugin scripts) that share our pipes.
            // ponytail: descendants that leave the group or outlive the leader are not chased.
            if getpgid(pid) == pid { kill(-pid, SIGTERM) }
            let killer = Task {
                try await Task.sleep(for: killGrace)
                if getpgid(pid) == pid { kill(-pid, SIGKILL) }
            }
            await reap.value
            killer.cancel()
            throw error
        }
    }

    private enum Event { case stdout(String), stderr(String), exit(Int32) }

    private static func collect(
        _ handle: FileHandle, _ stream: OutputLine.Stream, _ emit: AsyncStream<OutputLine>.Continuation
    ) async throws -> String {
        // FileHandle.bytes shares a serial IO actor: an idle pipe can block all other pipes.
        let bytes = AsyncThrowingStream<UInt8, Error> { continuation in
            handle.readabilityHandler = { handle in
                var buffer = [UInt8](repeating: 0, count: 16_384)
                let count = Darwin.read(handle.fileDescriptor, &buffer, buffer.count)
                if count > 0 {
                    for byte in buffer.prefix(count) { continuation.yield(byte) }
                } else if count == 0 {
                    handle.readabilityHandler = nil
                    continuation.finish()
                } else if errno != EINTR {
                    let error = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                    handle.readabilityHandler = nil
                    continuation.finish(throwing: error)
                }
            }
        }
        defer { handle.readabilityHandler = nil }
        var collected = ""
        for try await line in bytes.lines {
            emit.yield(OutputLine(stream: stream, line: line))
            collected += line + "\n"
        }
        return collected
    }
}
