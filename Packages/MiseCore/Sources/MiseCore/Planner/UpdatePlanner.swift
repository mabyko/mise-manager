/// Update rules for the updater columns, separated from the mise calls so they are
/// testable without a mise binary.
public enum UpdatePlanner {
    /// `lineLatest` and `releaseLatest` are mise's own answers (`mise latest <tool>@<line>` and
    /// `mise latest <tool>`): each backend knows its naming and what counts as a pre-release, so
    /// nothing here guesses stability from a version string. The remote list only feeds the
    /// opt-in pre-release candidate.
    public static func plan(
        plugin: String, baseVersion: String, includeChannels: Bool, remoteStdout: String,
        lineLatest: [String: String], releaseLatest: String?
    ) -> PluginUpdateInfo {
        let unique = Parsers.dedupe(Parsers.parseRemoteVersions(remoteStdout)
            .filter { includeChannels || Version.startsWithDigit($0) })
        let preReleaseLatest = Version.pickLatest(unique.filter { Version.startsWithDigit($0) && Version.isPreRelease($0) })

        // A pre-release only counts as "overall latest" when (semver base) it is newer than the
        // base, or (non-semver base) it is at least the release latest.
        let isBaseSemver = Version.startsWithDigit(baseVersion)
        let overallLatest = preReleaseLatest.flatMap { pre -> String? in
            let qualifies = isBaseSemver
                ? Version.compare(pre, baseVersion) == .orderedDescending
                : releaseLatest.map { Version.compare(pre, $0) != .orderedAscending } ?? false
            return qualifies ? pre : nil
        }

        // An answer outside the line that was asked for is never offered as that line's update.
        let latestByLine = lineLatest.filter { Version.line(of: $0.value) == $0.key }
        return PluginUpdateInfo(
            plugin: plugin, baseVersion: baseVersion,
            sameMajorLatest: Version.line(of: baseVersion).flatMap { latestByLine[$0] },
            latestByLine: latestByLine, releaseLatest: releaseLatest, overallLatest: overallLatest,
            checkedVersions: unique.count
        )
    }
}
