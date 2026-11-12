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
            $0.latestByLine = ["24": "24.21.0", "26": "26.1.0"]
            $0.sameMajorLatest = "26.1.0"
            $0.releaseLatest = "26.1.0"
        }
        #expect(ToolStatus.installedSeries(multi) == [
            InstalledSeries(line: "26", current: "26.1.0", latest: "26.1.0", update: nil),
            InstalledSeries(line: "24", current: "24.20.0", latest: "24.21.0", update: "24.21.0"),
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
        // mise's latest can trail what is installed (a backend's own idea of latest): never a downgrade.
        var older = multi
        older.latestByLine = ["24": "24.19.5", "26": "26.0.9"]
        #expect(!ToolStatus.hasUpdates(older))
    }

    @Test func vendorLinesGetTheirOwnUpdateButNoNewMajorOffer() {
        let java = PluginRow(
            name: "java", installedVersions: ["temurin-25.0.5+8.0.LTS", "temurin-21.0.12+101.0.LTS", "temurin-21.0.11+9.0.LTS"],
            latestByLine: ["temurin-25": "temurin-25.0.5+8.0.LTS", "temurin-21": "temurin-21.0.13+9.0.LTS"],
            sameMajorLatest: "temurin-25.0.5+8.0.LTS", releaseLatest: "27.0.1+1", status: .done)
        #expect(ToolStatus.installedSeries(java) == [
            InstalledSeries(line: "temurin-25", current: "temurin-25.0.5+8.0.LTS", latest: "temurin-25.0.5+8.0.LTS", update: nil),
            InstalledSeries(line: "temurin-21", current: "temurin-21.0.12+101.0.LTS", latest: "temurin-21.0.13+9.0.LTS", update: "temurin-21.0.13+9.0.LTS"),
        ])
        // The tool's overall latest is another vendor's build, so it is never offered as a new major.
        #expect(ToolStatus.update(java) == nil)
        #expect(ToolStatus.label(java) == Strings.ToolStatus.updateAvailable)
        #expect(ToolStatus.cleanupCandidates(java) == ["temurin-21.0.11+9.0.LTS"])
        var current = java
        current.latestByLine["temurin-21"] = "temurin-21.0.12+101.0.LTS"
        #expect(ToolStatus.label(current) == Strings.ToolStatus.latestStable)
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

    @Test func installedVersionsAreGroupedByMajorAndOnlyOlderPatchesAreSuperseded() {
        let multi = with {
            $0.activeGlobalVersion = "26.13.1"
            $0.installedVersions = ["26.13.1", "24.22.3", "24.22.2", "22.23.5", "lts"]
            $0.unusedVersions = ["24.22.2", "22.23.5"]
        }
        func v(_ version: String, global: Bool = false, superseded: Bool = false, unused: Bool?) -> InstalledVersion {
            InstalledVersion(version: version, isGlobal: global, isSuperseded: superseded, isUnused: unused)
        }
        #expect(ToolStatus.versionGroups(multi) == [
            InstalledVersionGroup(line: "26", versions: [v("26.13.1", global: true, unused: false)]),
            InstalledVersionGroup(line: "24", versions: [v("24.22.3", unused: false), v("24.22.2", superseded: true, unused: true)]),
            InstalledVersionGroup(line: "22", versions: [v("22.23.5", unused: true)]),
            InstalledVersionGroup(line: nil, versions: [v("lts", unused: false)]),
        ])
        #expect(ToolStatus.cleanupCandidates(multi) == ["24.22.2"])
        #expect(ToolStatus.isUnused(multi, ["24.22.2", "22.23.5"]) == true)
        #expect(ToolStatus.isUnused(multi, ["24.22.2", "24.22.3"]) == false)
    }

    @Test func cleanUpNeverOffersTheGlobalVersionOrAVersionInUseAndToleratesUnknownUsage() {
        let older = with {
            $0.activeGlobalVersion = "24.22.1"
            $0.installedVersions = ["24.22.3", "24.22.2", "24.22.1", "24.22.0"]
            $0.unusedVersions = ["24.22.0"]
        }
        #expect(ToolStatus.cleanupCandidates(older) == ["24.22.0"])
        let unknown = with { $0.activeGlobalVersion = "24.22.1"; $0.installedVersions = older.installedVersions }
        #expect(ToolStatus.cleanupCandidates(unknown) == ["24.22.2", "24.22.0"])
        #expect(ToolStatus.isUnused(unknown, ["24.22.2"]) == nil)
        #expect(ToolStatus.versionGroups(unknown).first?.versions.map(\.isUnused) == [nil, nil, false, nil])
        #expect(ToolStatus.cleanupCandidates(with { $0.installedVersions = ["temurin-25.0.5", "temurin-21.0.12"] }).isEmpty)
    }

    @Test func toolNamesSplitTheBackendPrefixForDisplay() {
        #expect(ToolName.backend("node") == nil)
        #expect(ToolName.short("node") == "node")
        #expect(ToolName.initials("node") == "no")
        #expect(ToolName.backend("http:tla2tools") == "http")
        #expect(ToolName.short("http:tla2tools") == "tla2tools")
        #expect(ToolName.initials("http:tla2tools") == "tl")
        #expect(ToolName.initials("npm:@antfu/ni") == "ni")
        #expect(ToolName.short("odd:") == "odd:")
    }

    @Test func installOnlyClearsUpdatesWithoutMovingTheGlobalDefaultOrAdvertisingADowngrade() {
        #expect(!ToolStatus.hasUpdates(with { $0.installedVersions = ["22.14.0", "22.15.0", "24.0.0"] }))
        #expect(ToolStatus.update(with { $0.installedVersions = ["22.14.0", "22.16.0", "24.1.0"] }) == nil)
    }
}
