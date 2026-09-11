import Testing
@testable import MiseCore

// Mirrors src/mainview/features/updates.test.ts and the action half of core/runtime.test.ts.
@MainActor struct UpdatesTests {
    @Test func allUpdateSourcesAreCheckedOnceAndOverlappingChecksAreSkipped() async {
        let runner = FakeRunner()
        let state = makeState(runner, latest: { runner.mark("__latest__"); return "v9.9.9" })
        runner.reply("--version", "2026.9.5 macos-arm64")
        runner.installed([("node", "22.14.0", ["22.14.0"])])
        runner.reply("ls-remote node --json", #"["22.14.0"]"#)

        async let first: Void = state.checkAllUpdates()
        await state.checkAllUpdates()
        await first

        for key in ["--version", "ls --installed --json", "__latest__", "ls-remote node --json", "plugins ls --user --outdated"] {
            #expect(runner.count(key) == 1, "\(key)")
        }
        #expect(runner.index("--version")! < runner.index("ls --installed --json")!)
        #expect(runner.index("ls --installed --json")! < runner.index("__latest__")!)
        #expect(runner.index("__latest__")! < runner.index("ls-remote node --json")!)
        #expect(!state.updateCheckRunning)
        #expect(!state.busy)
        #expect(state.progressLabel == Strings.checkComplete)

        state.busy = true
        await state.checkAllUpdates()
        #expect(runner.count("--version") == 1)
    }

    @Test func theOwnerHandlesATrayInstallOnceAndKeepsTheGlobalDefault() async {
        let runner = FakeRunner()
        let state = makeState(runner)
        state.plugins = [PluginRow(
            name: "node", activeGlobalVersion: "26.0.0", installedVersions: ["26.0.0", "24.20.0"],
            latestByMajor: ["26": "26.1.0", "24": "24.21.0"], sameMajorLatest: "26.1.0", releaseLatest: "26.1.0",
            checkedVersions: 20, status: .done)]
        runner.installed([("node", "26.0.0", ["26.0.0", "24.20.0", "24.21.0"])])
        let id = state.updateSummary.items.first { $0.to == "24.21.0" }!.id

        await state.run(.apply(id: id))
        #expect(runner.count("install -y node@24.21.0") == 1)
        #expect(!runner.called(prefix: "use"))
        #expect(state.plugins[0].installedVersions.contains("24.21.0"))
        #expect(state.plugins[0].activeGlobalVersion == "26.0.0")
        #expect(state.updateSummary.items.map(\.to) == ["26.1.0"])

        await state.run(.apply(id: id))
        await state.run(.use(name: "node", version: "99.0.0"))
        #expect(runner.calls.filter { $0.first == "install" }.count == 1)
        #expect(!runner.called(prefix: "use"))

        state.updateCheckRunning = true
        await state.run(.apply(id: state.updateSummary.items[0].id))
        #expect(runner.calls.filter { $0.first == "install" }.count == 1)
    }
}

@MainActor struct StartupTests {
    @Test func missingMiseLandsOnTheMiseTabWithoutTouchingTools() async {
        let runner = FakeRunner()
        let state = makeState(runner)
        runner.fail("--version", "not found")
        await state.startup()
        #expect(!state.miseIsInstalled)
        #expect(state.activeTab == .mise)
        #expect(state.progressLabel == Strings.miseRequired)
        #expect(!runner.called(prefix: "ls"))
    }

    @Test func intervalTimerIsArmedEvenWhenMiseIsMissing() async {
        let runner = FakeRunner()
        let state = makeState(runner)
        state.settings.checkIntervalHours = 1
        runner.fail("--version", "not found")
        await state.startup()
        #expect(state.intervalTask != nil)
        state.settings.checkIntervalHours = 0
        state.scheduleIntervalChecks()
        #expect(state.intervalTask == nil)
    }

    @Test func startupWithoutAutomaticChecksLoadsToolsButNeverChecksRemotes() async {
        let runner = FakeRunner()
        let state = makeState(runner)
        state.settings.checkOnStartup = false
        runner.reply("--version", "2026.9.5")
        runner.installed([("node", "22.14.0", ["22.14.0"])])
        await state.startup()
        #expect(state.miseVersion == "2026.9.5")
        #expect(state.plugins.map(\.name) == ["node"])
        #expect(!runner.called(prefix: "ls-remote"))
        #expect(!state.busy)
    }
}
