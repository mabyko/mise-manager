import Testing
@testable import MiseCore

// Mirrors the tests in src-tauri/src/mise.rs and catalog.rs.
struct ParsersTests {
    @Test func parsesRemoteVersionsFromJsonStringsAndObjects() {
        #expect(Parsers.parseRemoteVersions(#"["1.0.0", {"version": "1.1.0"}, {"other": 1}, 42]"#) == ["1.0.0", "1.1.0"])
    }

    @Test func fallsBackToPlainTextLines() {
        #expect(Parsers.parseRemoteVersions("1.0.0\n  1.1.0  \n\n") == ["1.0.0", "1.1.0"])
        #expect(Parsers.parseRemoteVersions("   ").isEmpty)
    }

    @Test func parsesPluginInfoLinesWithOptionalUrls() {
        let parsed = Parsers.parsePluginInfoLines("node https://example.com/node.git\ncore *builtin\nplain\n")
        #expect(parsed.count == 3)
        #expect(parsed[0].url == "https://example.com/node.git")
        #expect(parsed[1].url == nil)
        #expect(parsed[2].url == nil)
    }

    @Test func pluginCheckParsesTablesButDoesNotHideRemoteFailures() throws {
        #expect(try Parsers.parseOutdatedPlugins(
            stdout: "node https://example.com/node main abc def\npython url main 123 456\n", stderr: "") == ["node", "python"])
        #expect(try Parsers.parseOutdatedPlugins(stdout: "", stderr: "mise All plugins are up to date\n").isEmpty)
        #expect(throws: MiseError.self) {
            try Parsers.parseOutdatedPlugins(stdout: "", stderr: "mise WARN plugin: remote unavailable\nmise All plugins are up to date\n")
        }
    }

    @Test func globalVersionsPreserveEverySelectionAndRejectUnreadableData() throws {
        let globals = try Parsers.parseGlobalPlugins(#"{"node":[{"version":"26.0.0"},{"version":"24.20.0"}]}"#)
        #expect(globals["node"] == ["26.0.0", "24.20.0"])
        for invalid in ["invalid", "[]", #"{"node":{}}"#, #"{"node":[{}]}"#] {
            #expect(throws: MiseError.self, "\(invalid)") { try Parsers.parseGlobalPlugins(invalid) }
        }
        #expect(try Parsers.parseGlobalPlugins("{}").isEmpty)
    }

    @Test func installedVersionsAreDedupedNewestFirst() throws {
        let installed = try Parsers.parseInstalledPlugins(#"{"node":[{"version":"20.1.0"},{"version":"22.0.0"},{"version":"20.1.0"}],"odd":"x"}"#)
        #expect(installed == ["node": ["22.0.0", "20.1.0"]])
        #expect(throws: MiseError.self) { try Parsers.parseInstalledPlugins("nope") }
        // One odd element must not drop the whole tool.
        #expect(try Parsers.parseInstalledPlugins(#"{"node":[{"version":"1.0.0"},"junk",{"version":"2.0.0"}]}"#) == ["node": ["2.0.0", "1.0.0"]])
    }
}
