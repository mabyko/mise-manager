import Foundation

/// Spawns mise (and the install helpers), streaming every output line into `output`.
/// The resolved mise path is cached once found; while missing it is re-resolved on every
/// call so an in-app install is picked up immediately.
public actor MiseCLI: CommandRunner {
    /// Single-consumer stream of all subprocess output. The app fans it out to the log and status bar.
    public nonisolated let output: AsyncStream<OutputLine>
    private let emit: AsyncStream<OutputLine>.Continuation
    private let environment: [String: String]
    private var cachedExecutable: String?

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
        (output, emit) = AsyncStream.makeStream()
    }

    public func executable() -> String {
        if let cached = cachedExecutable, FileManager.default.fileExists(atPath: cached) { return cached }
        let resolved = PathResolver.resolveMiseExecutable(environment: environment)
        if resolved.hasPrefix("/"), FileManager.default.fileExists(atPath: resolved) { cachedExecutable = resolved }
        return resolved
    }

    public func runMise(_ args: [String]) async throws -> CommandResult {
        let exe = executable()
        let path = PathResolver.augmentedPATH(environment: environment)
        guard FileManager.default.fileExists(atPath: exe) else {
            throw MiseError("failed to spawn mise executable '\(exe)' (PATH='\(path)'): No such file or directory")
        }
        do {
            return try await Self.run(program: exe, args, path: path, environment: environment, emit: emit)
        } catch {
            throw MiseError("failed to spawn mise executable '\(exe)' (PATH='\(path)'): \(error.localizedDescription)")
        }
    }

    // ponytail: also uses the augmented PATH (Rust used the bare process env, which
    // lacks /opt/homebrew/bin inside a GUI app, so `brew` could not be found).
    public func runShell(_ program: String, _ args: [String]) async throws -> CommandResult {
        do {
            return try await Self.run(program: program, args, path: PathResolver.augmentedPATH(environment: environment), environment: environment, emit: emit)
        } catch {
            throw MiseError(error.localizedDescription)
        }
    }

    /// `/usr/bin/env <program> args…` so bare names resolve against the PATH we pass in.
    static func run(
        program: String, _ args: [String], path: String, environment base: [String: String],
        emit: AsyncStream<OutputLine>.Continuation
    ) async throws -> CommandResult {
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

        let (status, statusContinuation) = AsyncStream<Int32>.makeStream()
        process.terminationHandler = { finished in
            statusContinuation.yield(finished.terminationStatus)
            statusContinuation.finish()
        }
        try process.run()

        async let out = collect(stdout.fileHandleForReading, .stdout, emit)
        async let err = collect(stderr.fileHandleForReading, .stderr, emit)
        let (collectedOut, collectedErr) = try await (out, err)
        var exitCode: Int32 = -1
        for await code in status { exitCode = code }
        return CommandResult(stdout: collectedOut, stderr: collectedErr, exitCode: exitCode)
    }

    private static func collect(
        _ handle: FileHandle, _ stream: OutputLine.Stream, _ emit: AsyncStream<OutputLine>.Continuation
    ) async throws -> String {
        var collected = ""
        for try await line in handle.bytes.lines {
            emit.yield(OutputLine(stream: stream, line: line))
            collected += line + "\n"
        }
        return collected
    }
}
