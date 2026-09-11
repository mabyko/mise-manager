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

/// Port of src/mainview/core/toolStatus.ts.
public enum ToolStatus {
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
