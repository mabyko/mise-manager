import Testing
@testable import MiseCore

// Mirrors src/mainview/core/toolStatus.test.ts.
struct ToolStatusTests {
    let node = PluginRow(
        name: "node", activeGlobalVersion: "22.14.0", installedVersions: ["22.14.0"],
        sameMajorLatest: "22.15.0", releaseLatest: "24.0.0", overallLatest: "25.0.0-rc.1", checkedVersions: 10, status: .done)

    func with(_ patch: (inout PluginRow) -> Void) -> PluginRow {
        var row = node
        patch(&row)
        return row
    }

    @Test func tracksAnOlderInstalledMajorEvenWhenTheGlobalMajorIsCurrent() {
        let multi = with {
            $0.activeGlobalVersion = "26.1.0"
            $0.installedVersions = ["24.19.0", "26.1.0", "24.20.0"]
            $0.latestByMajor = ["24": "24.21.0", "26": "26.1.0"]
            $0.sameMajorLatest = "26.1.0"
            $0.releaseLatest = "26.1.0"
        }
        #expect(ToolStatus.installedSeries(multi) == [
            InstalledSeries(major: 26, current: "26.1.0", latest: "26.1.0", update: nil),
            InstalledSeries(major: 24, current: "24.20.0", latest: "24.21.0", update: "24.21.0"),
        ])
        #expect(ToolStatus.update(multi) == nil)
        #expect(ToolStatus.hasUpdates(multi))
        #expect(ToolStatus.label(multi) == Strings.ToolStatus.updateAvailable)
        var installed = multi
        installed.installedVersions.append("24.21.0")
        #expect(!ToolStatus.hasUpdates(installed))
        var failed = multi
        failed.status = .error
        #expect(!ToolStatus.hasUpdates(failed))
        var prerelease = multi
        prerelease.latestByMajor = ["24": "24.22.0-rc.1"]
        #expect(!ToolStatus.hasUpdates(prerelease))
    }

    @Test func stableUpdatePlanSeparatesSameMajorAndMajorUpgradesUsingTheInstalledFallback() {
        #expect(ToolStatus.update(node) == ToolUpdate(primary: "22.15.0", major: "24.0.0"))
        #expect(ToolStatus.update(with { $0.activeGlobalVersion = nil }) == ToolStatus.update(node))
        #expect(ToolStatus.update(with { $0.sameMajorLatest = "22.14.0" }) == ToolUpdate(primary: nil, major: "24.0.0"))
        #expect(ToolStatus.update(with { $0.releaseLatest = "22.15.0" }) == ToolUpdate(primary: "22.15.0", major: nil))
        #expect(ToolStatus.update(with { $0.sameMajorLatest = "22.14.0"; $0.releaseLatest = "22.14.0" }) == nil)
    }

    @Test func failedUnfinishedAndChannelChecksNeverExposeCachedUpdateActions() {
        for status in [PluginStatus.idle, .checking, .updating, .deleting, .error] {
            #expect(ToolStatus.update(with { $0.status = status }) == nil)
            #expect(ToolStatus.label(with { $0.status = status }) != Strings.ToolStatus.latestStable)
        }
        #expect(ToolStatus.update(with { $0.activeGlobalVersion = "stable" }) == nil)
        #expect(ToolStatus.update(with { $0.activeGlobalVersion = nil; $0.installedVersions = [] }) == nil)
        #expect(ToolStatus.label(with { $0.activeGlobalVersion = "stable" }) == Strings.ToolStatus.channel)
    }

    @Test func toolLabelsDistinguishUpdatesMissingComparisonsAndPrereleases() {
        #expect(ToolStatus.label(node) == Strings.ToolStatus.updateAvailable)
        #expect(ToolStatus.label(with { $0.sameMajorLatest = nil; $0.releaseLatest = nil }) == Strings.ToolStatus.noComparison)
        #expect(ToolStatus.label(with { $0.activeGlobalVersion = "25.0.0-rc.1" }) == Strings.ToolStatus.prerelease)
        #expect(ToolStatus.label(with { $0.activeGlobalVersion = "24.0.0" }) == Strings.ToolStatus.latestStable)
    }

    @Test func installOnlyClearsUpdatesWithoutMovingTheGlobalDefaultOrAdvertisingADowngrade() {
        #expect(!ToolStatus.hasUpdates(with { $0.installedVersions = ["22.14.0", "22.15.0", "24.0.0"] }))
        #expect(ToolStatus.update(with { $0.installedVersions = ["22.14.0", "22.16.0", "24.1.0"] }) == nil)
    }
}
