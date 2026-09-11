import Foundation
import Testing
@testable import MiseCore

// Mirrors the tests in src-tauri/src/config.rs; the editor must preserve everything it doesn't own.
struct ToolAliasEditorTests {
    let sample = "# my mise config\n[tools]\nnode = \"22\" # pinned\n\n[tool_alias]\n\"node\" = \"https://old.example/node.git\"\n"

    @Test func parsesQuotedAndBareKeys() {
        #expect(ToolAliasEditor.parse(sample)["node"] == "https://old.example/node.git")
        #expect(ToolAliasEditor.parse("[tool_alias]\npython = 'https://py.example' # c\n")["python"] == "https://py.example")
        #expect(ToolAliasEditor.parse("").isEmpty)
        #expect(ToolAliasEditor.parse("not toml [").isEmpty)
    }

    @Test func updateReplacesExistingAliasAndPreservesEverythingElse() throws {
        let next = try ToolAliasEditor.update(sample, plugin: "node", gitUrl: "https://new.example/node.git")
        #expect(ToolAliasEditor.parse(next)["node"] == "https://new.example/node.git")
        #expect(next.contains("# my mise config"))
        #expect(next.contains("node = \"22\" # pinned"))
        #expect(!next.contains("old.example"))
    }

    @Test func updateKeepsTheTrailingCommentOnTheEditedLine() throws {
        let input = "[tool_alias]\nnode = \"https://old.example/node.git\" # pinned source\n"
        let next = try ToolAliasEditor.update(input, plugin: "node", gitUrl: "https://new.example/node.git")
        #expect(next.contains("# pinned source"))
        #expect(!next.contains("old.example"))
        #expect(ToolAliasEditor.parse(next)["node"] == "https://new.example/node.git")
    }

    @Test func updateCreatesSectionWhenMissing() throws {
        let next = try ToolAliasEditor.update("", plugin: "python", gitUrl: "https://example/py.git")
        #expect(next.contains("[tool_alias]"))
        #expect(ToolAliasEditor.parse(next)["python"] == "https://example/py.git")

        let withOther = try ToolAliasEditor.update("[tools]\nnode = \"22\"\n", plugin: "python", gitUrl: "https://example/py.git")
        #expect(withOther.contains("[tools]"))
        #expect(ToolAliasEditor.parse(withOther)["python"] != nil)
    }

    @Test func removeDeletesOnlyTheTargetAlias() throws {
        let two = try ToolAliasEditor.update(sample, plugin: "python", gitUrl: "https://example/py.git")
        let next = try ToolAliasEditor.remove(two, plugin: "node")
        let aliases = ToolAliasEditor.parse(next)
        #expect(aliases["node"] == nil)
        #expect(aliases["python"] != nil)
        #expect(next.contains("# my mise config"))
    }

    @Test func removeWithoutSectionIsANoOp() throws {
        let input = "[tools]\nnode = \"22\"\n"
        #expect(try ToolAliasEditor.remove(input, plugin: "node") == input)
    }

    @Test func writingThroughASymlinkedConfigKeepsTheLink() throws {
        let dir = NSTemporaryDirectory() + "mise-manager-symlink-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let real = dir + "/real.toml", link = dir + "/config.toml"
        try "[tools]\nnode = \"22\"\n".write(toFile: real, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: real)
        _ = try ToolAliasEditor.updateUserAlias(at: link, plugin: "node", gitUrl: "https://example/node.git")
        #expect(try FileManager.default.attributesOfItem(atPath: link)[.type] as? FileAttributeType == .typeSymbolicLink)
        #expect(ToolAliasEditor.parse(try String(contentsOfFile: real, encoding: .utf8))["node"] == "https://example/node.git")
    }

    @Test func updateRefusesToClobberInvalidToml() {
        #expect(throws: MiseError.self) { try ToolAliasEditor.update("not toml [", plugin: "node", gitUrl: "url") }
    }

    @Test func multiLineValuesElsewhereAreLeftAlone() throws {
        let input = "[tools]\nnode = [\n  \"22\",\n  \"20\",\n]\ndesc = \"\"\"\nmulti [ line\n\"\"\"\n\n[tool_alias]\nnode = \"u\"\n"
        let next = try ToolAliasEditor.update(input, plugin: "ruby", gitUrl: "r")
        #expect(next.hasPrefix("[tools]\nnode = [\n  \"22\",\n  \"20\",\n]\ndesc = \"\"\"\nmulti [ line\n\"\"\"\n\n[tool_alias]\nnode = \"u\"\nruby = \"r\"\n"))
    }
}
