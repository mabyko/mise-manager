import Testing
@testable import MiseCore

// Mirrors the plan_plugin_update tests in src-tauri/src/actions.rs.
struct UpdatePlannerTests {
    func plan(_ plugin: String, _ base: String, _ channels: Bool, _ stdout: String) -> PluginUpdateInfo {
        UpdatePlanner.plan(plugin: plugin, baseVersion: base, includeChannels: channels, remoteStdout: stdout)
    }

    @Test func computesSameMajorReleaseAndPreReleaseColumns() {
        let info = plan("node", "20.1.0", false, "20.2.0\n21.0.0\n22.0.0-rc1\nlts\n20.1.0")
        // "lts" is dropped without channels; 22.0.0-rc1 > base so it surfaces.
        #expect(info.sameMajorLatest == "20.2.0")
        #expect(info.releaseLatest == "21.0.0")
        #expect(info.overallLatest == "22.0.0-rc1")
        #expect(info.checkedVersions == 4)
        #expect(info.error == nil)
    }

    @Test func pythonPreReleasesAreFilteredOutEntirely() {
        let info = plan("python", "3.12.0", false, "3.13.0a1\n3.12.1\n3.13.0")
        #expect(info.releaseLatest == "3.13.0")
        #expect(info.overallLatest == nil)
        #expect(info.checkedVersions == 2)
    }

    @Test func preReleaseNotNewerThanSemverBaseStaysHidden() {
        let info = plan("node", "22.0.0", false, "21.0.0\n22.0.0-rc1\n22.0.0")
        #expect(info.releaseLatest == "22.0.0")
        #expect(info.overallLatest == nil)
    }

    @Test func nonSemverBaseRequiresPreReleaseAtLeastReleaseLatest() {
        let info = plan("java", "system", true, "17.0.0\n18-ea\n17.0.1")
        #expect(info.releaseLatest == "17.0.1")
        #expect(info.overallLatest == "18-ea")
        #expect(info.sameMajorLatest == nil)
    }

    @Test func acceptsJsonRemoteListings() {
        let info = plan("node", "1.0.0", false, #"["1.0.0", {"version": "1.1.0"}]"#)
        #expect(info.releaseLatest == "1.1.0")
        #expect(info.checkedVersions == 2)
    }

    @Test func tracksEachMajorWithoutPromotingPrereleases() {
        let info = plan("node", "26.0.0", false, #"["24.20.0","26.0.0","24.21.0","26.1.0","24.22.0-rc.1","27.0.0-rc.1"]"#)
        #expect(info.latestByMajor["24"] == "24.21.0")
        #expect(info.latestByMajor["26"] == "26.1.0")
        #expect(info.latestByMajor["27"] == nil)
        #expect(info.sameMajorLatest == "26.1.0")
        #expect(info.releaseLatest == "26.1.0")
    }
}
