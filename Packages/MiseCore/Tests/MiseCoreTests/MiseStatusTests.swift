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

    @Test func needsReloadWinsOverEverythingElse() {
        let snapshot = MiseStatus.snapshot(input { $0.needsReload = true })
        #expect(snapshot.key == .updatedNeedsReload)
        #expect(!snapshot.canUpdate)
    }

    @Test func selfUpdateInFlightReportsUpdating() {
        #expect(MiseStatus.snapshot(input { $0.progressLabel = Strings.runningMiseSelfUpdate }).key == .updating)
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
