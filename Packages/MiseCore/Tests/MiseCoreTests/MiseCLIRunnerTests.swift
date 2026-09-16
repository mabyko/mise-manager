import Darwin
import Foundation
import Testing
@testable import MiseCore

/// Timeout and cancellation behaviour of the real runner, driven by /bin/sh and a fake `mise`.
/// Every wait here is bounded: a stuck runner fails the test instead of hanging the suite.
struct MiseCLIRunnerTests {
    /// Long enough for `env → sh → echo` under a loaded parallel test run; the tests measure the
    /// deadline itself, not how quickly a process starts.
    static let deadline: Duration = .seconds(1)

    /// Writes an executable `mise` stand-in whose body is `script` (sh) and returns its path.
    static func fakeMise(_ script: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mise-cli-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("mise").path
        try ("#!/bin/sh\n" + script + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    static func cli(mise script: String, queryTimeout: Duration = deadline, killGrace: Duration = .seconds(2)) throws -> MiseCLI {
        MiseCLI(environment: ["MISE_BIN": try fakeMise(script), "PATH": "/usr/bin:/bin"], queryTimeout: queryTimeout, killGrace: killGrace)
    }

    /// The pids a script printed on its first output line, proving it is running and streaming live.
    /// `output` never finishes, so the wait is raced against a watchdog and yields [] on timeout.
    static func pids(from cli: MiseCLI, within limit: Duration = .seconds(10)) async -> [pid_t] {
        await withTaskGroup(of: [pid_t].self) { group in
            group.addTask {
                for await line in cli.output { return line.line.split(separator: " ").compactMap { pid_t($0) } }
                return []
            }
            group.addTask { try? await Task.sleep(for: limit); return [] }
            let first = await group.next() ?? []
            group.cancelAll()
            return first
        }
    }

    static func isGone(_ pid: pid_t) -> Bool { kill(pid, 0) == -1 }

    /// Orphans are reaped by launchd, so allow a moment for a grandchild to disappear.
    static func exits(_ pid: pid_t, within limit: Duration = .seconds(2)) async -> Bool {
        let start = ContinuousClock.now
        while !isGone(pid) {
            if ContinuousClock.now - start > limit { return false }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return true
    }

    @Test func onlyReadOnlyQueriesAreBounded() {
        for query in [["--version"], ["ls", "--installed", "--json"], ["ls", "--global", "--json"], ["ls-remote", "python", "--json"],
                      ["plugins", "ls", "--user", "--outdated"], ["plugins", "ls", "--core"], ["plugins", "ls-remote", "--urls"]] {
            #expect(MiseCLI.isQuery(query), "\(query)")
        }
        for mutation in [["install", "-y", "node@22"], ["use", "-g", "node@22"], ["uninstall", "-y", "node@22"],
                         ["self-update", "-y", "--no-plugins"], ["plugins", "install", "-y", "x"], ["plugins", "update", "x"],
                         ["plugins", "uninstall", "-y", "x"], []] {
            #expect(!MiseCLI.isQuery(mutation), "\(mutation)")
        }
    }

    @Test func hungQueryTimesOutAndIsReaped() async throws {
        let cli = try Self.cli(mise: "echo $$; exec sleep 30")
        let start = ContinuousClock.now
        let task = Task { try await cli.runMise(["ls-remote", "python", "--json"]) }
        let pid = try #require(await Self.pids(from: cli).first)
        await #expect(throws: MiseError("mise ls-remote python --json timed out after 1.0 seconds")) { try await task.value }
        #expect(Self.isGone(pid))
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test func closedPipesStillHitTheQueryDeadline() async throws {
        // stdout/stderr reach EOF immediately, but the child lives on: the deadline must still fire.
        let cli = try Self.cli(mise: "echo $$; exec >&- 2>&-; exec sleep 30")
        let start = ContinuousClock.now
        let task = Task { try await cli.runMise(["ls", "--installed", "--json"]) }
        let pid = try #require(await Self.pids(from: cli).first)
        await #expect(throws: MiseError("mise ls --installed --json timed out after 1.0 seconds")) { try await task.value }
        #expect(Self.isGone(pid))
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test func ignoredSIGTERMEscalatesToSIGKILL() async throws {
        let cli = try Self.cli(mise: "trap '' TERM; echo $$; sleep 30", killGrace: .milliseconds(300))
        let start = ContinuousClock.now
        let task = Task { try await cli.runMise(["--version"]) }
        let pid = try #require(await Self.pids(from: cli).first)
        await #expect(throws: MiseError("mise --version timed out after 1.0 seconds")) { try await task.value }
        #expect(Self.isGone(pid))
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test func mutationsIgnoreTheQueryTimeout() async throws {
        let cli = try Self.cli(mise: "sleep 0.5; echo installed; echo warn >&2", queryTimeout: .milliseconds(100))
        let result = try await cli.runMise(["install", "-y", "node@22"])
        #expect(result == CommandResult(stdout: "installed\n", stderr: "warn\n", exitCode: 0))
    }

    @Test func cancellationTerminatesTheProcessGroupAndThrows() async throws {
        let cli = MiseCLI()
        // The backgrounded sleep inherits our stdout pipe: only a group signal reaches it.
        let task = Task { try await cli.runShell("/bin/sh", ["-c", "sleep 30 & echo $$ $!; wait"]) }
        let pids = await Self.pids(from: cli)
        let (shell, grandchild) = (try #require(pids.first), try #require(pids.last))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(Self.isGone(shell))
        #expect(await Self.exits(grandchild))
    }

    @Test func cancellationOfAnExecdChildThrowsAndReaps() async throws {
        let cli = MiseCLI()
        let task = Task { try await cli.runShell("/bin/sh", ["-c", "echo $$; exec sleep 30"]) }
        let pid = try #require(await Self.pids(from: cli).first)
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(Self.isGone(pid))
    }

    @Test func cancellationAfterPipesClosedThrowsAndReaps() async throws {
        let cli = MiseCLI()
        let task = Task { try await cli.runShell("/bin/sh", ["-c", "echo $$; exec >&- 2>&-; exec sleep 30"]) }
        let pid = try #require(await Self.pids(from: cli).first)
        try await Task.sleep(for: .milliseconds(200))  // let both readers reach EOF first
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(Self.isGone(pid))
    }

    @Test func cancellationBeforeLaunchSpawnsNothing() async throws {
        let cli = MiseCLI()
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("mise-cli-tests-\(UUID().uuidString)").path
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await cli.runShell("/bin/sh", ["-c", "touch '\(marker)'"])
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        try await Task.sleep(for: .milliseconds(200))
        #expect(!FileManager.default.fileExists(atPath: marker))
    }
}
