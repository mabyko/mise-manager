/// One installed major line of a tool, tracked independently of the global selection.
public struct InstalledSeries: Equatable, Sendable {
    public let major: UInt64
    public let current: String
    public let latest: String?
    public let update: String?
    public init(major: UInt64, current: String, latest: String?, update: String?) {
        self.major = major; self.current = current; self.latest = latest; self.update = update
    }
}

public struct ToolUpdate: Equatable, Sendable {
    public let primary: String?
    public let major: String?
    public init(primary: String?, major: String?) { self.primary = primary; self.major = major }
}

/// One installed version with what tells it apart from its siblings.
public struct InstalledVersion: Equatable, Sendable, Identifiable {
    public let version: String
    public let isGlobal: Bool
    /// A newer version of the same major is installed, so this one is a clean-up candidate.
    public let isSuperseded: Bool
    /// What mise reports: true = nothing tracked selects it, false = in use, nil = unknown.
    public let isUnused: Bool?
    public var id: String { version }
    public init(version: String, isGlobal: Bool, isSuperseded: Bool, isUnused: Bool?) {
        self.version = version; self.isGlobal = isGlobal; self.isSuperseded = isSuperseded; self.isUnused = isUnused
    }
}

/// Installed versions of one major line; `major` is nil for channel or vendor-prefixed versions.
public struct InstalledVersionGroup: Equatable, Sendable, Identifiable {
    public let major: UInt64?
    public let versions: [InstalledVersion]
    public var id: String { major.map(String.init) ?? "other" }
    /// Several versions of one numeric major: only then do "newest of the line" and "superseded" mean anything.
    public var hasSiblings: Bool { major != nil && versions.count > 1 }
    public init(major: UInt64?, versions: [InstalledVersion]) { self.major = major; self.versions = versions }
}

/// Port of src/mainview/core/toolStatus.ts.
public enum ToolStatus {
    /// Installed versions by major, newest major first and newest version first within it;
    /// versions without a numeric major come last.
    public static func versionGroups(_ plugin: PluginRow) -> [InstalledVersionGroup] {
        var byMajor: [UInt64?: [String]] = [:]
        for version in plugin.installedVersions { byMajor[Version.major(of: version), default: []].append(version) }
        let majors = byMajor.keys.sorted { a, b in
            switch (a, b) {
            case let (x?, y?): x > y
            case (nil, _): false
            case (_, nil): true
            }
        }
        return majors.map { major in
            let versions = byMajor[major]!.sorted { Version.compare($0, $1) == .orderedDescending }
            return InstalledVersionGroup(major: major, versions: versions.enumerated().map { index, version in
                InstalledVersion(
                    version: version, isGlobal: version == plugin.activeGlobalVersion,
                    isSuperseded: major != nil && index > 0,
                    isUnused: version == plugin.activeGlobalVersion ? false : plugin.unusedVersions.map { $0.contains(version) })
            })
        }
    }

    /// Superseded versions that are safe to offer as one clean-up: never the global selection, and
    /// never a version mise reports as in use.
    public static func cleanupCandidates(_ plugin: PluginRow) -> [String] {
        versionGroups(plugin).flatMap(\.versions)
            .filter { $0.isSuperseded && !$0.isGlobal && $0.isUnused != false }
            .map(\.version)
    }

    /// Usage of several versions as one answer: false if any is in use, true if all are unused, else unknown.
    public static func isUnused(_ plugin: PluginRow, _ versions: [String]) -> Bool? {
        guard let unused = plugin.unusedVersions else { return nil }
        return versions.allSatisfy { unused.contains($0) && $0 != plugin.activeGlobalVersion }
    }

    public static func installedSeries(_ plugin: PluginRow) -> [InstalledSeries] {
        var newest: [UInt64: String] = [:]
        for version in plugin.installedVersions {
            guard let major = Version.major(of: version) else { continue }
            if let previous = newest[major], Version.compare(version, previous) != .orderedDescending { continue }
            newest[major] = version
        }
        let baseMajor = plugin.baseVersion.flatMap(Version.major(of:))
        return newest.keys.sorted(by: >).map { major in
            let current = newest[major]!
            let candidate = plugin.latestByMajor[String(major)] ?? (baseMajor == major ? plugin.sameMajorLatest : nil)
            let latest = plugin.status == .done ? candidate.flatMap { Version.isPreRelease($0) ? nil : $0 } : nil
            let update = latest.flatMap { Version.compare($0, current) == .orderedDescending ? $0 : nil }
            return InstalledSeries(major: major, current: current, latest: latest, update: update)
        }
    }

    public static func hasUpdates(_ plugin: PluginRow) -> Bool {
        update(plugin) != nil || installedSeries(plugin).contains { $0.update != nil }
    }

    /// Verified stable updates only; prereleases stay in the version inspector.
    public static func update(_ plugin: PluginRow) -> ToolUpdate? {
        guard plugin.status == .done, let base = plugin.baseVersion, let baseMajor = Version.major(of: base) else { return nil }
        func needsInstall(_ version: String) -> Bool {
            !plugin.installedVersions.contains {
                Version.major(of: $0) == Version.major(of: version) && Version.compare($0, version) != .orderedAscending
            }
        }
        func newer(_ candidate: String?) -> String? {
            candidate.flatMap {
                needsInstall($0) && !Version.isPreRelease($0) && Version.compare($0, base) == .orderedDescending ? $0 : nil
            }
        }
        let primary = newer(plugin.sameMajorLatest)
        let major = newer(plugin.releaseLatest).flatMap { Version.major(of: $0).map { $0 > baseMajor } == true ? $0 : nil }
        return primary == nil && major == nil ? nil : ToolUpdate(primary: primary, major: major)
    }

    public static func label(_ plugin: PluginRow) -> String {
        switch plugin.status {
        case .error: return Strings.ToolStatus.checkFailed
        case .checking: return Strings.ToolStatus.checking
        case .updating: return Strings.ToolStatus.changing
        case .deleting: return Strings.ToolStatus.deleting
        case .idle, .skipped: return Strings.ToolStatus.unchecked
        case .done: break
        }
        guard let base = plugin.baseVersion, Version.major(of: base) != nil else { return Strings.ToolStatus.channel }
        if hasUpdates(plugin) { return Strings.ToolStatus.updateAvailable }
        if plugin.sameMajorLatest == nil && plugin.releaseLatest == nil { return Strings.ToolStatus.noComparison }
        if Version.isPreRelease(base) { return Strings.ToolStatus.prerelease }
        return Strings.ToolStatus.latestStable
    }
}
