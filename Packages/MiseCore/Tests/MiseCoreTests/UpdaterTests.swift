import Testing
@testable import MiseCore

// Mirrors src/mainview/features/updater.test.ts. Logs are newest-first, so logs[0] is the latest line.
@MainActor struct UpdaterTests {
    func setup() -> (FakeRunner, AppState) {
        let runner = FakeRunner()
        // What mise reports after an action: the new version landed on disk.
        runner.installed([("node", "22.14.0", ["22.15.0", "22.14.0"])])
        runner.reply("ls-remote node --json", #"["22.15.0","24.0.0","22.14.0"]"#)
        let state = makeState(runner)
        state.plugins = [row()]
        return (runner, state)
    }

    func row(_ patch: (inout PluginRow) -> Void = { _ in }) -> PluginRow {
        var row = PluginRow(
            name: "node", activeGlobalVersion: "22.14.0", installedVersions: ["22.14.0"],
            sameMajorLatest: "22.15.0", releaseLatest: "24.0.0", checkedVersions: 10, status: .done)
        patch(&row)
        return row
    }

    @Test func updatingAnOlderInstalledMajorPreservesTheGlobalVersionEvenWithAutomaticSwitching() async {
        let (runner, state) = setup()
        state.settings.switchGlobalAfterUpdate = true
        state.plugins = [row { $0.activeGlobalVersion = "26.0.0"; $0.installedVersions = ["26.0.0", "24.20.0"]; $0.latestByMajor = ["24": "24.21.0", "26": "26.1.0"] }]
        runner.installed([("node", "26.0.0", ["26.0.0", "24.21.0", "24.20.0"])])
        await state.updateInstalledSeries("node", "24.21.0")
        #expect(runner.count("install -y node@24.21.0") == 1)
        #expect(!runner.called(prefix: "use"))
        #expect(state.plugin("node")?.activeGlobalVersion == "26.0.0")
        #expect(state.plugin("node")?.installedVersions.contains("24.20.0") == true)
        await state.updateInstalledSeries("node", "24.21.0")
        await state.updateInstalledSeries("node", "27.0.0")
        #expect(runner.calls.filter { $0.first == "install" }.count == 1)
    }

    @Test func seriesUpdatesInstallOnlyByDefaultAndSwitchTheActiveMajorOnlyWhenEnabled() async {
        let (runner, state) = setup()
        state.plugins = [row { $0.latestByMajor = ["22": "22.15.0"] }]
        await state.updateInstalledSeries("node", "22.15.0")
        #expect(!runner.called(prefix: "use"))
        state.plugins = [row { $0.latestByMajor = ["22": "22.15.0"] }]
        state.settings.switchGlobalAfterUpdate = true
        await state.updateInstalledSeries("node", "22.15.0")
        #expect(runner.count("use -g -y node@22.15.0") == 1)
    }

    @Test func updateKeepsTheInstalledVersionVisibleWhenSwitchingGlobalFails() async {
        let (runner, state) = setup()
        runner.fail("use -g -y node@22.15.0", "use exploded")
        await state.updateToVersion("node", "22.15.0")
        #expect(runner.count("install -y node@22.15.0") == 1)
        let node = state.plugin("node")
        #expect(node?.status == .error)
        #expect(node?.error == "use exploded")
        #expect(node?.installedVersions == ["22.15.0", "22.14.0"])
        #expect(state.logs[0].contains("installed 22.15.0 but switching global failed - use exploded"))
        #expect(!state.busy)
    }

    @Test func updateStopsBeforeSwitchingGlobalWhenTheInstallFails() async {
        let (runner, state) = setup()
        runner.fail("install -y node@22.15.0", "install exploded")
        await state.updateToVersion("node", "22.15.0")
        #expect(!runner.called(prefix: "use"))
        #expect(state.plugin("node")?.status == .error)
        #expect(state.plugin("node")?.error == "install exploded")
        #expect(state.logs[0].contains("install failed - install exploded"))
        #expect(!state.busy)
    }

    @Test func successfulUpdateReReadsTheRowFromMiseAndClearsAStaleError() async {
        let (runner, state) = setup()
        state.plugins = [row { $0.status = .error; $0.error = "old" }]
        runner.installed([("node", "22.15.0", ["22.15.0", "22.14.0"])])
        await state.updateToVersion("node", "22.15.0")
        // The base moved (22.14 -> 22.15), so the candidates are re-checked against the new base.
        #expect(runner.count("ls-remote node --json") == 1)
        let node = state.plugin("node")
        #expect(node?.status == .done)
        #expect(node?.error == nil)
        #expect(node?.activeGlobalVersion == "22.15.0")
        #expect(node?.checkedVersions == 3)
        #expect(state.logs[1].contains("updated to 22.15.0"))
        #expect(state.logs[0].contains("checked 3 version(s), base=22.15.0"))
    }

    @Test func aRefreshFailureAfterASuccessfulCommandIsReportedAsARefreshFailure() async {
        let (runner, state) = setup()
        runner.fail("ls --installed --json", "ls exploded")
        await state.useInstalledVersion("node", "22.14.0")
        #expect(state.logs[1].contains("switched global version to 22.14.0"))
        #expect(state.plugin("node")?.status == .error)
        #expect(state.plugin("node")?.error == "refresh failed after success - ls exploded")
        #expect(state.logs[0].contains("refresh failed after success - ls exploded"))
        #expect(!state.busy)
    }

    @Test func installOnlyKeepsTheVerifiedCandidatesWhenTheBaseVersionDoesNotMove() async {
        let (runner, state) = setup()
        await state.installVersion("node", "24.0.0")
        #expect(runner.count("install -y node@24.0.0") == 1)
        #expect(!runner.called(prefix: "ls-remote"))
        let node = state.plugin("node")
        #expect(node?.status == .done)
        #expect(node?.sameMajorLatest == "22.15.0")
        #expect(node?.installedVersions == ["22.15.0", "22.14.0"])
        #expect(state.logs[0].contains("installed 24.0.0."))
        #expect(!state.busy)
    }

    @Test func switchingGlobalToAnotherMajorReChecksCandidatesForTheNewBase() async {
        let (runner, state) = setup()
        state.plugins = [row { $0.installedVersions = ["22.14.0", "20.19.0"] }]
        runner.installed([("node", "20.19.0", ["22.14.0", "20.19.0"])])
        runner.reply("ls-remote node --json", #"["20.19.0","20.20.0","22.14.0","22.15.0","24.0.0"]"#)
        await state.useInstalledVersion("node", "20.19.0")
        #expect(runner.count("ls-remote node --json") == 1)
        let node = state.plugin("node")!
        #expect(node.status == .done)
        #expect(node.activeGlobalVersion == "20.19.0")
        #expect(node.sameMajorLatest == "20.20.0")
        #expect(ToolStatus.update(node) == ToolUpdate(primary: "20.20.0", major: "24.0.0"))
    }

    @Test func aFailedCommandWhoseBaseStillMovedDropsTheStaleCandidates() async {
        let (runner, state) = setup()
        state.plugins = [row { $0.installedVersions = ["22.14.0", "20.19.0"] }]
        runner.fail("use -g -y node@20.19.0", "use exploded")
        runner.installed([("node", "20.19.0", ["22.14.0", "20.19.0"])])
        await state.useInstalledVersion("node", "20.19.0")
        #expect(!runner.called(prefix: "ls-remote"))
        let node = state.plugin("node")!
        #expect(node.status == .error)
        #expect(node.error == "use exploded")
        #expect(node.activeGlobalVersion == "20.19.0")
        #expect(node.sameMajorLatest == nil)
        #expect(node.releaseLatest == nil)
        #expect(ToolStatus.update(node) == nil)
    }

    @Test func aRowWhoseLastCheckFailedIsReCheckedAfterASuccessfulCommand() async {
        let (runner, state) = setup()
        state.plugins = [row { $0.status = .error; $0.error = "network down" }]
        await state.installVersion("node", "22.15.0")
        #expect(runner.count("ls-remote node --json") == 1)
        #expect(state.logs[0].contains("base=22.14.0"))
        #expect(state.plugin("node")?.status == .done)
        #expect(state.plugin("node")?.error == nil)
        #expect(state.plugin("node")?.checkedVersions == 3)
    }

    @Test func retryReconcilesVersionsFromMiseBeforeCheckingAndKeepsARefreshFailure() async {
        let (runner, state) = setup()
        state.plugins = [row { $0.status = .error; $0.error = "refresh failed after success - ls exploded" }]
        await state.retryCheck("node")
        #expect(runner.count("ls --installed --json") == 1)
        #expect(runner.count("ls-remote node --json") == 1)
        #expect(state.logs[0].contains("base=22.14.0"))
        #expect(state.plugin("node")?.status == .done)
        #expect(state.plugin("node")?.error == nil)
        #expect(state.plugin("node")?.installedVersions == ["22.15.0", "22.14.0"])
        #expect(!state.busy)
        #expect(state.progressLabel == Strings.checkComplete)

        runner.fail("ls --installed --json", "ls exploded again")
        await state.retryCheck("node")
        #expect(runner.count("ls-remote node --json") == 1)
        #expect(state.plugin("node")?.status == .error)
        #expect(state.plugin("node")?.error == "refresh failed - ls exploded again")
        #expect(!state.busy)
    }

    @Test func deleteRefusesTheActiveGlobalVersionAndDropsAToolMiseNoLongerLists() async {
        let (runner, state) = setup()
        await state.deleteInstalledVersion("ghost", "1.0.0")
        #expect(state.logs.isEmpty)
        await state.deleteInstalledVersion("node", "22.14.0")
        #expect(!runner.called(prefix: "uninstall"))
        #expect(state.logs.first?.contains("cannot delete active global version") == true)

        state.plugins = [row { $0.activeGlobalVersion = nil; $0.installedVersions = ["22.14.0"] }]
        runner.installed([])
        await state.deleteInstalledVersion("node", "22.14.0")
        #expect(runner.count("uninstall -y node@22.14.0") == 1)
        #expect(state.plugin("node") == nil)
        #expect(!state.busy)
    }

    @Test func actionsAreNoOpsWhileAnotherActionIsRunning() async {
        let (runner, state) = setup()
        state.busy = true
        await state.useInstalledVersion("node", "22.14.0")
        await state.reloadAndCheckTools()
        #expect(runner.calls.isEmpty)
    }

    @Test func reloadRecordsALoadErrorAndSkipsChecksAndAGoodLoadChecksEveryTool() async {
        let (runner, state) = setup()
        let listing = runner.calls.isEmpty ? #"{"node":[{"version":"22.15.0"},{"version":"22.14.0"}]}"# : ""
        runner.queue("ls --installed --json", [FakeRunner.failure("mise missing"), FakeRunner.ok(listing)])
        await state.reloadAndCheckTools()
        #expect(state.toolsLoaded)
        #expect(state.toolsError == "mise missing")
        #expect(!state.busy)
        #expect(!runner.called(prefix: "ls-remote"))

        await state.reloadAndCheckTools()
        #expect(state.toolsError == nil)
        #expect(runner.count("ls-remote node --json") == 1)
        let node = state.plugin("node")
        #expect(node?.status == .done)
        #expect(node?.checkedVersions == 3)
        #expect(node?.installedVersions == ["22.15.0", "22.14.0"])
        #expect(!state.busy)
        #expect(state.progressLabel == Strings.checkComplete)
        #expect(state.progress == 100)
    }
}
