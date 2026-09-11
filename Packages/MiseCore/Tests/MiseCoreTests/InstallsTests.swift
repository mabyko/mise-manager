import Testing
@testable import MiseCore

// Mirrors the non-rendering tests in src/mainview/features/installs.test.ts.
@MainActor struct InstallsTests {
    func setup() -> (FakeRunner, AppState) {
        let runner = FakeRunner()
        return (runner, makeState(runner))
    }

    @Test func pluginChecksExposeFailuresAndUseTheDedicatedUpdateCommandForOneOutdatedPlugin() async {
        let (runner, state) = setup()
        runner.reply("plugins ls --user --outdated", "flutter https://example/flutter main abc def\n")
        await state.checkPluginDefinitionUpdates()
        #expect(state.outdatedPluginNames == ["flutter"])

        runner.reply("plugins ls --user", "flutter\n")
        runner.reply("plugins update flutter", "updated")
        runner.reply("plugins ls --user --outdated", "")
        await state.updatePluginDefinition("flutter")
        #expect(runner.count("plugins update flutter") == 1)
        #expect(!runner.called(prefix: "plugins install"))
        #expect(state.outdatedPluginNames == [])
        #expect(state.pluginUpdateResult?.contains("업데이트했습니다") == true)

        runner.fail("plugins ls --user --outdated", "remote unreachable")
        await state.checkPluginDefinitionUpdates()
        #expect(state.pluginUpdatesError == "remote unreachable")
        #expect(!state.busy)
        await state.updatePluginDefinition("flutter")
        #expect(runner.count("plugins update flutter") == 1)
    }

    @Test func normalizesCustomInstallShorthandAndClearsBusyAfterReload() async {
        let (runner, state) = setup()
        state.pendingPluginUrlDialog = .customInstall
        state.pendingPluginNameValue = "zoxide"
        state.pendingPluginUrlValue = "nyrst/asdf-zoxide.git"
        await state.submitPluginUrlDialog()
        #expect(runner.count("plugins install -y zoxide https://github.com/nyrst/asdf-zoxide.git") == 1)
        #expect(runner.calls.filter { $0.prefix(2) == ["plugins", "install"] }.count == 1)
        #expect(!state.busy)
        #expect(state.pendingPluginUrlDialog == nil)
    }

    @Test func usesDefaultInstallAndRemovesToolAliasWhenEditUrlMatchesRemoteDefault() async {
        let (runner, state) = setup()
        let url = "https://github.com/asdf-community/asdf-flutter.git"
        state.installedUserPluginInfos = [PluginDefinitionInfo(name: "flutter", url: url, source: "tool_alias")]
        state.remotePluginInfos = [PluginDefinitionInfo(name: "flutter", url: url)]
        state.pendingPluginUrlDialog = .edit(pluginName: "flutter")
        state.pendingPluginUrlValue = "asdf:asdf-community/asdf-flutter"
        await state.submitPluginUrlDialog()
        #expect(runner.count("plugins install -y --force flutter") == 1)
        #expect(runner.calls.filter { $0.prefix(2) == ["plugins", "install"] }.count == 1)
    }

    @Test func resolvePluginInstallPlanNormalizesCustomInstallShorthand() {
        #expect(AppState.resolvePluginInstallPlan(
            dialog: .customInstall, nameValue: "zoxide", urlValue: "nyrst/asdf-zoxide.git",
            installedUserPluginInfos: [], remotePluginInfos: []
        ) == .install(plugin: "zoxide", gitUrl: "https://github.com/nyrst/asdf-zoxide.git", force: false, removeToolAlias: false))
    }

    @Test func resolvePluginInstallPlanRejectsInvalidCustomInput() {
        func plan(_ name: String, _ url: String) -> PluginInstallPlan {
            AppState.resolvePluginInstallPlan(dialog: .customInstall, nameValue: name, urlValue: url, installedUserPluginInfos: [], remotePluginInfos: [])
        }
        for (name, url) in [("  ", "owner/repo"), ("bad name", "owner/repo"), ("zoxide", "")] {
            guard case .invalid = plan(name, url) else { Issue.record("\(name)/\(url) should be invalid"); continue }
        }
    }

    @Test func resolvePluginInstallPlanSkipsEditWhenUrlIsUnchanged() {
        let plan = AppState.resolvePluginInstallPlan(
            dialog: .edit(pluginName: "zoxide"), nameValue: "", urlValue: "https://example.com/custom.git",
            installedUserPluginInfos: [PluginDefinitionInfo(name: "zoxide", url: "https://example.com/custom.git", source: "mise_user")],
            remotePluginInfos: [])
        guard case .skip = plan else { Issue.record("expected skip, got \(plan)"); return }
    }

    @Test func resolvePluginInstallPlanRevertsToDefaultInstallWhenEditUrlMatchesRemote() {
        let url = "https://github.com/asdf-community/asdf-flutter.git"
        #expect(AppState.resolvePluginInstallPlan(
            dialog: .edit(pluginName: "flutter"), nameValue: "", urlValue: "asdf:asdf-community/asdf-flutter",
            installedUserPluginInfos: [PluginDefinitionInfo(name: "flutter", url: url, source: "tool_alias")],
            remotePluginInfos: [PluginDefinitionInfo(name: "flutter", url: url)]
        ) == .install(plugin: "flutter", gitUrl: nil, force: true, removeToolAlias: true))
    }

    @Test func leavesFailedInstallsVisibleInProgressLabel() async {
        let (runner, state) = setup()
        runner.fail("plugins install -y zoxide https://github.com/nyrst/asdf-zoxide.git", "GitHub 404")
        state.pendingPluginUrlDialog = .customInstall
        state.pendingPluginNameValue = "zoxide"
        state.pendingPluginUrlValue = "nyrst/asdf-zoxide.git"
        await state.submitPluginUrlDialog()
        #expect(!state.busy)
        #expect(state.progressLabel == Strings.pluginInstallFailed("zoxide", force: false))
        #expect(state.logs.contains { $0.contains("GitHub 404") })
    }
}
