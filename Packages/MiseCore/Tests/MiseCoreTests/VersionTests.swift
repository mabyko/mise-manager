import Foundation
import Testing
@testable import MiseCore

// Mirrors src-tauri/src/version.rs tests and src/shared/version.test.ts.
struct VersionTests {
    @Test func comparesNumericPartsNotLexicographically() {
        #expect(Version.compare("1.2.3", "1.2.10") == .orderedAscending)
        #expect(Version.compare("1.10.0", "1.9.0") == .orderedDescending)
        #expect(Version.compare("2.0.0", "2.0.0") == .orderedSame)
    }

    @Test func missingPartsCountAsZeroThenRawTiebreak() {
        #expect(Version.compare("1.2", "1.2.0") == .orderedAscending)
    }

    @Test func preReleaseSortsBelowReleaseOfSameParts() {
        #expect(Version.compare("2.0.0-rc.1", "2.0.0") == .orderedAscending)
        #expect(Version.compare("2.0.0", "2.0.0-rc.1") == .orderedDescending)
    }

    @Test func preReleaseDetection() {
        #expect(Version.isPreRelease("3.0.0-alpha"))
        #expect(Version.isPreRelease("3.13.0a1"))
        #expect(Version.isPreRelease("1.0.0rc2"))
        #expect(!Version.isPreRelease("1.2.3"))
        #expect(!Version.isPreRelease("1.2.3+build5"))
        #expect(Version.isPreRelease("nightly-2024"))
    }

    @Test func flutterStableChannelSuffixIsNotAPreRelease() {
        for version in ["3.50.0-stable", "1.5.4-hotfix.2-stable", "1.7.8+hotfix.4-stable"] {
            #expect(!Version.isPreRelease(version), "\(version)")
        }
        #expect(Version.isPreRelease("3.22.0-0.1.pre-beta"))
        #expect(Version.compare("3.50.0-stable", "3.47.9-stable") == .orderedDescending)
        let plan = UpdatePlanner.plan(
            plugin: "flutter", baseVersion: "stable", includeChannels: false,
            remoteStdout: #"["3.47.9-stable","3.50.0-stable","stable"]"#)
        #expect(plan.releaseLatest == "3.50.0-stable")
        #expect(plan.latestByMajor == ["3": "3.50.0-stable"])
    }

    @Test func stableFilterOnlyAppliesToPythonAndRuby() {
        #expect(!Version.isStable(plugin: "python", version: "3.13.0a1"))
        #expect(Version.isStable(plugin: "python", version: "3.12.1"))
        #expect(!Version.isStable(plugin: "ruby", version: "3.4.0-preview1"))
        #expect(Version.isStable(plugin: "node", version: "20.0.0-nightly"))
    }

    @Test func majorExtraction() {
        #expect(Version.major(of: "10.1.2") == 10)
        #expect(Version.major(of: "1") == 1)
        #expect(Version.major(of: "v1.2") == nil)
        #expect(Version.major(of: "system") == nil)
    }

    @Test func pickLatestPrefersHighest() {
        #expect(Version.pickLatest(["1.9.0", "1.10.0", "1.2.0"]) == "1.10.0")
        #expect(Version.pickLatest([String]()) == nil)
    }

    @Test func nonSemverFallbackUsesNaturalCompare() {
        #expect(Version.compare("temurin-21", "temurin-8") == .orderedDescending)
        #expect(Version.compare("Temurin-8", "temurin-8") == .orderedSame)
    }
}
