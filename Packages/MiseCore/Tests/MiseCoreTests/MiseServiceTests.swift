import Foundation
import Testing
@testable import MiseCore

struct MiseServiceTests {
    @Test func deletingTheActiveGlobalVersionIsRefusedBeforeAnyUninstall() async throws {
        let runner = FakeRunner(["ls --global --json": CommandResult(stdout: #"{"node":[{"version":"22.0.0"}]}"#, stderr: "", exitCode: 0)])
        let mise = Mise(runner: runner)
        await #expect(throws: MiseError("cannot delete active global version")) {
            try await mise.deleteVersion(plugin: "node", version: "22.0.0")
        }
        #expect(await runner.calls == [["ls", "--global", "--json"]])
    }

    @Test func checkingUpdatesNeverInstalls() async throws {
        let runner = FakeRunner(["ls-remote node --json": CommandResult(stdout: #"["20.1.0","20.2.0"]"#, stderr: "", exitCode: 0)])
        let info = try await Mise(runner: runner).checkPluginUpdates(plugin: "node", baseVersion: "20.1.0", includeChannels: false)
        #expect(info.sameMajorLatest == "20.2.0")
        #expect(await runner.calls == [["ls-remote", "node", "--json"]])
    }

    @Test func remoteFailureBecomesAnErrorRowNotAThrow() async throws {
        let runner = FakeRunner(["ls-remote node --json": CommandResult(stdout: "", stderr: "boom\n", exitCode: 1)])
        let info = try await Mise(runner: runner).checkPluginUpdates(plugin: "node", baseVersion: "1", includeChannels: false)
        #expect(info.error == "boom")
    }

    @Test func installedPluginsMergeGlobalOnlyTools() async throws {
        let runner = FakeRunner([
            "ls --installed --json": CommandResult(stdout: #"{"node":[{"version":"20.1.0"},{"version":"22.0.0"}]}"#, stderr: "", exitCode: 0),
            "ls --global --json": CommandResult(stdout: #"{"node":[{"version":"22.0.0"}],"ruby":[{"version":"3.4.0"}]}"#, stderr: "", exitCode: 0),
        ])
        let plugins = try await Mise(runner: runner).installedPlugins()
        #expect(plugins == [
            PluginSummary(name: "node", activeGlobalVersion: "22.0.0", installedVersions: ["22.0.0", "20.1.0"]),
            PluginSummary(name: "ruby", activeGlobalVersion: "3.4.0", installedVersions: []),
        ])
    }

    @Test func nonZeroExitUsesStderrThenFallback() async throws {
        let runner = FakeRunner(["plugins ls --core": CommandResult(stdout: "", stderr: "", exitCode: 2)])
        await #expect(throws: MiseError("failed to run 'mise plugins ls --core'")) {
            try await Mise(runner: runner).corePluginNames()
        }
    }
}

// Runs against the real mise when it is installed: proves spawning, PATH resolution, streaming and `ls --json` parsing.
struct MiseCLIIntegrationTests {
    static var miseAvailable: Bool { PathResolver.resolveMiseExecutable().hasPrefix("/") }

    @Test(.enabled(if: miseAvailable)) func versionIsStreamedAndReturned() async throws {
        let cli = MiseCLI()
        let version = try await Mise(runner: cli).version()
        #expect(version?.isEmpty == false)
        var first: OutputLine?
        for await line in cli.output { first = line; break }
        #expect(first?.stream == .stdout)
        #expect(first?.line == version)
    }

    @Test(.enabled(if: miseAvailable)) func installedPluginsParseRealOutput() async throws {
        let plugins = try await Mise(runner: MiseCLI()).installedPlugins()
        #expect(plugins.allSatisfy { !$0.name.isEmpty })
    }

    @Test func unknownExecutableReportsSpawnFailure() async throws {
        let cli = MiseCLI()
        let result = try await cli.runShell("definitely-not-a-real-binary-xyz", [])
        #expect(result.exitCode != 0)
    }
}
