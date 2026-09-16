import Testing
@testable import MiseCore

// Mirrors src/mainview/core/miseStatus.test.ts.
struct MiseStatusTests {
    func input(_ patch: (inout MiseStatusInput) -> Void = { _ in }) -> MiseStatusInput {
        var input = MiseStatusInput(version: "2026.8.6 macos-arm64 (2026-08-14)", latestVersion: "v2026.8.7")
        patch(&input)
        return input
    }

    @Test func extractsTheSemverTokenFromMiseOutput() {
        #expect(MiseStatus.normalizeVersionToken("2026.8.6 macos-arm64 (2026-08-14)") == "2026.8.6")
        #expect(MiseStatus.normalizeVersionToken("v1.2.3-rc.1") == "1.2.3-rc.1")
        #expect(MiseStatus.normalizeVersionToken("garbage") == nil)
        #expect(MiseStatus.normalizeVersionToken(nil) == nil)
    }

    @Test func updateAvailableOnlyWhenLatestIsNewer() {
        let snapshot = MiseStatus.snapshot(input())
        #expect(snapshot.key == .updateAvailable)
        #expect(snapshot.canUpdate)
    }

    @Test func upToDateWhenVersionsMatch() {
        let snapshot = MiseStatus.snapshot(input { $0.latestVersion = "v2026.8.6" })
        #expect(snapshot.key == .upToDate)
        #expect(!snapshot.canUpdate)
    }

    @Test func aheadOrCustomWhenCurrentIsNewerThanLatest() {
        let snapshot = MiseStatus.snapshot(input { $0.version = "2026.9.0 macos-arm64"; $0.latestVersion = "v2026.8.7" })
        #expect(snapshot.key == .aheadOrCustom)
        #expect(!snapshot.canUpdate)
    }

    @MainActor @Test func selfUpdateImmediatelyReflectsTheInstalledVersion() async {
        let runner = FakeRunner()
        runner.queue("--version", [
            FakeRunner.ok("2026.9.7 macos-arm64"),
            FakeRunner.ok("2026.9.8 macos-arm64"),
        ])
        let state = makeState(runner, latest: { "v2026.9.8" })
        state.miseVersion = "2026.9.7 macos-arm64"
        state.miseLoaded = true
        await state.checkLatestMiseRelease()
        #expect(state.miseStatus.canUpdate)

        state.openMiseUpdateDialog()
        await state.confirmMiseSelfUpdate()

        #expect(runner.calls.suffix(3) == [["--version"], ["self-update", "-y", "--no-plugins"], ["--version"]])
        #expect(state.miseVersion == "2026.9.8 macos-arm64")
        #expect(state.miseStatus.key == .upToDate)
        #expect(!state.miseStatus.canUpdate)
        #expect(!state.pendingMiseUpdateConfirm)
        #expect(!state.busy)
        #expect(!state.updateSummary.items.contains { $0.kind == .mise })

        await state.reloadMiseVersion()
        #expect(state.miseStatus.key == .upToDate)
        state.miseLatestVersion = "v2026.9.9"
        #expect(state.miseStatus.canUpdate)
    }

    @Test func selfUpdateInFlightReportsUpdating() {
        #expect(MiseStatus.snapshot(input { $0.progressLabel = Strings.runningMiseSelfUpdate }).key == .updating)
    }

    @MainActor @Test func selfUpdateRevalidatesStateAndExposesFailureForTheTray() async {
        let runner = FakeRunner()
        let state = makeState(runner)
        state.miseVersion = "2026.9.7"
        state.miseLatestVersion = "v2026.9.8"
        state.miseLoaded = true
        state.miseLatestLoaded = true
        state.updateCheckRunning = true
        await state.confirmMiseSelfUpdate()
        #expect(!runner.called(prefix: "self-update"))

        state.updateCheckRunning = false
        state.miseLatestVersion = state.miseVersion
        await state.confirmMiseSelfUpdate()
        #expect(!runner.called(prefix: "self-update"))

        state.miseLatestVersion = "v2026.9.8"
        runner.fail("self-update -y --no-plugins", "Use your package manager to update mise")
        await state.confirmMiseSelfUpdate()
        #expect(runner.count("self-update -y --no-plugins") == 1)
        #expect(state.miseSelfUpdateError == "Use your package manager to update mise")
        #expect(!state.busy)
    }

    @Test func anyCheckErrorBlocksUpdating() {
        #expect(MiseStatus.snapshot(input { $0.currentError = "boom" }).key == .checkFailed)
        #expect(MiseStatus.snapshot(input { $0.latestError = "boom" }).key == .checkFailed)
    }

    @Test func loadingUntilBothVersionsArrive() {
        #expect(MiseStatus.snapshot(input { $0.loaded = false }).key == .loading)
        #expect(MiseStatus.snapshot(input { $0.latestLoaded = false }).key == .loading)
    }

    @Test func unparsableVersionsAreNotComparable() {
        #expect(MiseStatus.snapshot(input { $0.version = "unknown" }).key == .notChecked)
    }
}
