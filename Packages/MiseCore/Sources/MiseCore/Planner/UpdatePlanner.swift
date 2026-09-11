/// Update rules for the updater columns, separated from the mise call so they are
/// testable without a mise binary. Port of actions.rs `plan_plugin_update`.
public enum UpdatePlanner {
    public static func plan(
        plugin: String, baseVersion: String, includeChannels: Bool, remoteStdout: String
    ) -> PluginUpdateInfo {
        let remote = Parsers.parseRemoteVersions(remoteStdout)
            .filter { includeChannels || Version.startsWithDigit($0) }
            .filter { Version.isStable(plugin: plugin, version: $0) }
            .sorted { Version.compare($0, $1) == .orderedAscending }
        let unique = Parsers.dedupe(remote)
        let semver = unique.filter(Version.startsWithDigit)

        let preReleaseLatest = Version.pickLatest(semver.filter(Version.isPreRelease))
        let releaseLatest = Version.pickLatest(semver.filter { !Version.isPreRelease($0) })

        // A pre-release only counts as "overall latest" when (semver base) it is newer than the
        // base, or (non-semver base) it is at least the release latest.
        let isBaseSemver = Version.startsWithDigit(baseVersion)
        let overallLatest = preReleaseLatest.flatMap { pre -> String? in
            let qualifies = isBaseSemver
                ? Version.compare(pre, baseVersion) == .orderedDescending
                : releaseLatest.map { Version.compare(pre, $0) != .orderedAscending } ?? false
            return qualifies ? pre : nil
        }

        var latestByMajor: [String: String] = [:]
        for version in semver where !Version.isPreRelease(version) {
            if let major = Version.major(of: version) { latestByMajor[String(major)] = version }
        }
        let sameMajorLatest = Version.major(of: baseVersion).flatMap { latestByMajor[String($0)] }

        return PluginUpdateInfo(
            plugin: plugin, baseVersion: baseVersion, sameMajorLatest: sameMajorLatest,
            latestByMajor: latestByMajor, releaseLatest: releaseLatest, overallLatest: overallLatest,
            checkedVersions: unique.count
        )
    }
}
