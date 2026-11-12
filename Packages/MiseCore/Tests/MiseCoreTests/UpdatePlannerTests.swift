import Testing
@testable import MiseCore

struct UpdatePlannerTests {
    func plan(
        _ base: String, _ stdout: String, lines: [String: String] = [:], release: String? = nil, channels: Bool = false
    ) -> PluginUpdateInfo {
        UpdatePlanner.plan(
            plugin: "tool", baseVersion: base, includeChannels: channels, remoteStdout: stdout,
            lineLatest: lines, releaseLatest: release)
    }

    @Test func miseAnswersFillTheStableColumnsAndTheRemoteListOnlyThePreRelease() {
        let info = plan("20.1.0", "20.2.0\n21.0.0\n22.0.0-rc1\nlts\n20.1.0", lines: ["20": "20.2.0"], release: "21.0.0")
        // "lts" is dropped without channels; 22.0.0-rc1 > base so it surfaces.
        #expect(info.sameMajorLatest == "20.2.0")
        #expect(info.latestByLine == ["20": "20.2.0"])
        #expect(info.releaseLatest == "21.0.0")
        #expect(info.overallLatest == "22.0.0-rc1")
        #expect(info.checkedVersions == 4)
        #expect(info.error == nil)

        // Nothing stable is derived from the list itself: without mise's answers there is no candidate.
        let bare = plan("20.1.0", "20.2.0\n21.0.0")
        #expect(bare.sameMajorLatest == nil)
        #expect(bare.releaseLatest == nil)
        #expect(bare.latestByLine.isEmpty)
    }

    @Test func preReleaseNotNewerThanSemverBaseStaysHidden() {
        #expect(plan("22.0.0", "21.0.0\n22.0.0-rc1\n22.0.0", release: "22.0.0").overallLatest == nil)
    }

    @Test func nonSemverBaseRequiresPreReleaseAtLeastReleaseLatest() {
        let info = plan("system", "17.0.0\n18-ea\n17.0.1", release: "17.0.1", channels: true)
        #expect(info.overallLatest == "18-ea")
        #expect(info.sameMajorLatest == nil)
    }

    @Test func acceptsJsonRemoteListings() {
        #expect(plan("1.0.0", #"["1.0.0", {"version": "1.1.0"}]"#).checkedVersions == 2)
    }

    @Test func vendorLinesAndUnusualNamingNeedNoSpecialCase() {
        let java = plan(
            "temurin-21.0.12+101.0.LTS", "[]",
            lines: ["temurin-21": "temurin-21.0.13+9.0.LTS", "temurin-25": "temurin-25.0.5+8.0.LTS"], release: "27.0.1+1")
        #expect(java.sameMajorLatest == "temurin-21.0.13+9.0.LTS")
        #expect(java.latestByLine["temurin-25"] == "temurin-25.0.5+8.0.LTS")
        #expect(plan("3.47.9-stable", "[]", lines: ["3": "3.50.0-stable"]).sameMajorLatest == "3.50.0-stable")
    }

    @Test func anAnswerOutsideTheRequestedLineIsDropped() {
        let info = plan("24.20.0", "[]", lines: ["2": "22.1.0", "24": "24.21.0", "temurin-21": "21.0.13+9.0.LTS"])
        #expect(info.latestByLine == ["24": "24.21.0"])
    }
}
