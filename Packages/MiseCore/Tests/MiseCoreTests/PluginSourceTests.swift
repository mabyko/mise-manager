import Testing
@testable import MiseCore

// Mirrors src/mainview/core/utils.test.ts.
struct PluginSourceTests {
    @Test func normalizesOwnerRepoShorthandIntoGitHubUrl() {
        #expect(PluginSource.normalizeInstallURL("nyrst/asdf-zoxide.git") == "https://github.com/nyrst/asdf-zoxide.git")
        #expect(PluginSource.normalizeInstallURL("https://example.com/repo.git") == "https://example.com/repo.git")
        #expect(PluginSource.normalizeInstallURL("asdf:nyrst/asdf-zoxide") == "asdf:nyrst/asdf-zoxide")
    }

    @Test func comparesAliasesGitAndTrailingSlashAsTheSameSourceToken() {
        #expect(PluginSource.normalizeSourceToken("asdf:nyrst/asdf-zoxide.git/")
            == PluginSource.normalizeSourceToken("https://github.com/nyrst/asdf-zoxide"))
        #expect(PluginSource.normalizeSourceToken("vfox:version-fox/vfox-nodejs")
            == PluginSource.normalizeSourceToken("https://github.com/version-fox/vfox-nodejs.git"))
    }

    @Test func detectsDefaultUrlsByComparingRemoteCatalogSourceTokens() {
        #expect(PluginSource.isDefaultURL(
            "flutter", gitUrl: "asdf:asdf-community/asdf-flutter",
            remote: [PluginDefinitionInfo(name: "flutter", url: "https://github.com/asdf-community/asdf-flutter.git")]))
    }

    @Test func treatsToolAliasAsCustomEvenWhenUrlMatchesRemoteDefault() {
        let url = "https://github.com/asdf-community/asdf-flutter.git"
        #expect(PluginSource.isCustomUserURL(
            PluginDefinitionInfo(name: "flutter", url: url, source: "tool_alias"),
            remote: [PluginDefinitionInfo(name: "flutter", url: url)]))
    }

    @Test func keepsUrlLessOfficialRemotePluginsDisplayedAsDefault() {
        #expect(!PluginSource.isCustomUserURL(
            PluginDefinitionInfo(name: "node", url: nil, source: "mise_user"),
            remote: [PluginDefinitionInfo(name: "node", url: nil)]))
    }
}
