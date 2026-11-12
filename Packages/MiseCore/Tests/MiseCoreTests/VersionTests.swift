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
    }

    @Test func aLineIsTheMajorOrAPlainVendorAndMajor() {
        #expect(Version.line(of: "24.22.3") == "24")
        #expect(Version.line(of: "3.50.0-stable") == "3")
        #expect(Version.line(of: "22.0.0-rc1") == "22")
        #expect(Version.line(of: "temurin-21.0.12+101.0.LTS") == "temurin-21")
        #expect(Version.line(of: "corretto-21.0.13.0.11") == "corretto-21")
        #expect(Version.line(of: "zulu-jre-javafx-21.54.109.0") == "zulu-jre-javafx-21")
        #expect(Version.line(of: "graalvm-community-25.0.3") == "graalvm-community-25")
        #expect(Version.line(of: "openjdk-21") == "openjdk-21")
    }

    @Test func namesThatMiseWouldMatchAcrossRuntimesHaveNoLine() {
        // mise answers `python@pypy3` with pypy3.12, `java@semeru-openj9` with JDK 25 and
        // `java@graalvm-22` with +java19: a digit in the name is not the version's major.
        for version in [
            "pypy3.10-7.3.19", "miniconda3-3.11-24.1.2-0", "semeru-openj9-17.0.21.0", "graalvm-22.3.0+java11",
            "liberica-nik-openjdk17-23.0.2+3", "liberica-8u412+9", "kona-21.0.13.b1", "jetbrains-21.0.2-b375.1",
            "temurin-21.0.13-ea", "nightly-2026-11-12", "stable", "lts", "system", "ref:abc123", "path:/opt/node20", "/opt/node20",
        ] {
            #expect(Version.line(of: version) == nil, "\(version)")
        }
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
