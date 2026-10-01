import Foundation
import Testing
@testable import MiseCore

@MainActor struct MiseReleaseTests {
    func state(_ runner: FakeRunner) -> AppState {
        let defaults = UserDefaults(suiteName: "mise-releases.\(UUID().uuidString)")!
        runner.replyMiseReleasePolicy()
        runner.reply("version --json", #"{"latest":"2026.9.17"}"#)
        let state = AppState(mise: Mise(runner: runner), settings: Settings(defaults: defaults), latestRelease: {
            [MiseRelease(version: "2026.9.18", publishedAt: Date(timeIntervalSince1970: 1790772661)),
             MiseRelease(version: "2026.9.17", publishedAt: Date(timeIntervalSince1970: 1790676379))]
        })
        state.miseVersion = "2026.9.17 macos-arm64"
        state.miseLoaded = true
        state.toolsLoaded = true
        state.toolsCheckedAt = "checked"
        state.pluginUpdatesCheckedAt = "checked"
        return state
    }

    @Test func waitingReleasesDoNotCountAsUpdatesOrUncheckedItems() async {
        let runner = FakeRunner()
        let state = state(runner)
        await state.checkLatestMiseRelease()
        #expect(state.miseLatestVersion == "2026.9.18")
        #expect(state.miseEligibleVersion == "2026.9.17")
        #expect(state.miseMinimumReleaseAge == "24h")
        #expect(state.miseStatus.key == .releaseWaiting)
        #expect(!state.miseStatus.canUpdate)
        #expect(state.misePendingReleases.map(\.version) == ["2026.9.18"])
        #expect(state.updateSummary.items.isEmpty)
        #expect(!state.updateSummary.attention)
        state.openMiseUpdateDialog()
        await state.confirmMiseSelfUpdate()
        #expect(!state.pendingMiseUpdateConfirm)
        #expect(!runner.called(prefix: "self-update"))

        // mise re-evaluates publication ages on every query, including cached indexes.
        runner.reply("version --json", #"{"latest":"2026.9.18"}"#)
        await state.checkLatestMiseRelease()
        #expect(state.miseStatus.canUpdate)
        #expect(state.misePendingReleases.isEmpty)
        #expect(state.updateSummary.items.map(\.to) == ["2026.9.18"])
    }

    @Test func anOlderEligibleUpdateAndANewerWaitingReleaseCoexist() async {
        let runner = FakeRunner()
        let state = state(runner)
        state.miseVersion = "2026.9.16"
        await state.checkLatestMiseRelease()
        #expect(state.miseStatus.canUpdate)
        #expect(state.updateSummary.items.map(\.to) == ["2026.9.17"])
        #expect(state.misePendingReleases.map(\.version) == ["2026.9.18"])
    }

    @Test func policySettingsFollowMisePrecedenceIncludingZeroAndAbsoluteDates() async throws {
        let runner = FakeRunner()
        let state = state(runner)
        for (specific, global, expected) in [
            (nil, nil, "24h"),
            (nil, "7d", "7d"),
            ("0s", "7d", "0s"),
            ("2026-09-01", nil, "2026-09-01"),
        ] as [(String?, String?, String)] {
            runner.replyMiseReleasePolicy(age: specific, globalAge: global)
            #expect(try await state.mise.releasePolicy().minimumAge == expected)
        }
        runner.replyMiseReleasePolicy(age: "0s")
        runner.reply("version --json", #"{"latest":"2026.9.18"}"#)
        await state.checkLatestMiseRelease()
        #expect(state.miseMinimumReleaseAge == "0s")
        #expect(state.misePendingReleases.isEmpty)
        #expect(state.miseStatus.canUpdate)
    }

    @Test func failedPolicyQueriesNeverFallBackToUnrestrictedLatest() async {
        let runner = FakeRunner()
        let state = state(runner)
        await state.checkLatestMiseRelease()
        for response in [#"{"latest":null}"#, #"{"latest":"unknown"}"#, "not json"] {
            runner.reply("version --json", response)
            await state.checkLatestMiseRelease()
            #expect(state.miseLatestError != nil)
            #expect(state.miseStatus.key == .checkFailed)
            #expect(!state.miseStatus.canUpdate)
            #expect(state.misePendingReleases.isEmpty)
            #expect(state.updateSummary.items.isEmpty)
        }
        runner.replyMiseReleasePolicy(repository: "company/mise")
        await state.checkLatestMiseRelease()
        #expect(state.miseLatestError?.contains("사용자 지정") == true)
        #expect(!state.miseStatus.canUpdate)
        runner.replyMiseReleasePolicy()
        runner.fail("settings get self_update.minimum_release_age", "failed to read configuration")
        await state.checkLatestMiseRelease()
        #expect(state.miseLatestError == "failed to read configuration")
        #expect(!state.miseStatus.canUpdate)
    }

    @Test func confirmationRechecksPolicyAndAnUnchangedVersionStillWaits() async {
        let runner = FakeRunner()
        let state = state(runner)
        state.miseVersion = "2026.9.16"
        await state.checkLatestMiseRelease()
        state.openMiseUpdateDialog()
        runner.reply("version --json", #"{"latest":"2026.9.16"}"#)
        await state.confirmMiseSelfUpdate()
        #expect(!runner.called(prefix: "self-update"))
        #expect(!state.pendingMiseUpdateConfirm)
        #expect(!state.busy)

        runner.reply("version --json", #"{"latest":"2026.9.17"}"#)
        await state.checkLatestMiseRelease()
        runner.queue("--version", [FakeRunner.ok("2026.9.16"), FakeRunner.ok("2026.9.17")])
        await state.confirmMiseSelfUpdate()
        #expect(runner.calls.contains(["self-update", "-y", "--no-plugins"]))
        #expect(state.miseStatus.key == .releaseWaiting)
        #expect(state.updateSummary.items.isEmpty)
        #expect(state.misePendingReleases.map(\.version) == ["2026.9.18"])
    }

    @Test func noOpSelfUpdateDoesNotReportAnInstalledUpdate() async {
        let runner = FakeRunner()
        let state = state(runner)
        state.miseVersion = "2026.9.16"
        await state.checkLatestMiseRelease()
        runner.reply("--version", "2026.9.16")
        await state.confirmMiseSelfUpdate()
        #expect(state.miseVersion == "2026.9.16")
        #expect(state.progressLabel == "mise 버전이 변경되지 않았습니다.")
        #expect(state.progress != 100)
    }

    @Test func confirmationPolicyFailureDisablesUpdatesButCommandFailureAllowsRetry() async {
        let runner = FakeRunner()
        let state = state(runner)
        state.miseVersion = "2026.9.16"
        await state.checkLatestMiseRelease()
        runner.fail("settings get self_update.minimum_release_age", "policy query failed")
        await state.confirmMiseSelfUpdate()
        #expect(state.miseLatestError == "policy query failed")
        #expect(!state.miseStatus.canUpdate)
        #expect(state.updateSummary.items.isEmpty)
        #expect(!runner.called(prefix: "self-update"))

        runner.replyMiseReleasePolicy()
        await state.checkLatestMiseRelease()
        runner.fail("self-update -y --no-plugins", "update failed")
        await state.confirmMiseSelfUpdate()
        #expect(state.miseLatestError == nil)
        #expect(state.miseStatus.canUpdate)
        #expect(state.miseSelfUpdateError != nil)
    }

    @Test(arguments: ["2026.9.16", "2026.9.17"])
    func failedBeforeVersionQueryUsesKnownVersion(after: String) async {
        let runner = FakeRunner()
        let state = state(runner)
        state.miseVersion = "2026.9.16"
        await state.checkLatestMiseRelease()
        runner.queue("--version", [FakeRunner.failure("version query failed"), FakeRunner.ok(after)])
        await state.confirmMiseSelfUpdate()
        #expect(state.miseVersion == after)
        #expect((state.progress == 100) == (after != "2026.9.16"))
        if after == "2026.9.16" {
            #expect(state.progressLabel == "mise 버전이 변경되지 않았습니다.")
        }
    }

    @Test func releaseIndexRequiresValidPublicationMetadataAndSortsCalendarVersions() throws {
        let releases = try ReleaseChecker.parseIndex("v2026.9.9\t100\nv2026.9.18\t200\nv2026.9.18\t200\n")
        #expect(releases.map(\.version) == ["2026.9.18", "2026.9.9"])
        #expect(releases.first?.publishedAt == Date(timeIntervalSince1970: 200))
        for invalid in ["", "v2026.9.18", "v2026.9.18\tgarbage", "v2026.9.18\tnan", "v2026.9.18-rc.1\t100"] {
            #expect(throws: MiseError.self) { try ReleaseChecker.parseIndex(invalid) }
        }
    }
}
