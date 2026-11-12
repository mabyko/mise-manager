/// One installed line of a tool (`24`, `temurin-21`; see `Version.line`), tracked independently
/// of the global selection.
public struct InstalledSeries: Equatable, Sendable {
    public let line: String
    public let current: String
    public let latest: String?
    public let update: String?
    public init(line: String, current: String, latest: String?, update: String?) {
        self.line = line; self.current = current; self.latest = latest; self.update = update
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

/// Installed versions of one line; `line` is nil for channels such as `stable`.
public struct InstalledVersionGroup: Equatable, Sendable, Identifiable {
    public let line: String?
    public let versions: [InstalledVersion]
    public var id: String { line ?? "other" }
    /// Several versions of one line: only then do "newest of the line" and "superseded" mean anything.
    public var hasSiblings: Bool { line != nil && versions.count > 1 }
    public init(line: String?, versions: [InstalledVersion]) { self.line = line; self.versions = versions }
}

/// Port of src/mainview/core/toolStatus.ts.
public enum ToolStatus {
    /// Installed versions by line, newest line first and newest version first within it;
    /// versions without a line come last.
    public static func versionGroups(_ plugin: PluginRow) -> [InstalledVersionGroup] {
        var byLine: [String?: [String]] = [:]
        for version in plugin.installedVersions { byLine[Version.line(of: version), default: []].append(version) }
        let lines = byLine.keys.sorted { a, b in
            switch (a, b) {
            case let (x?, y?): Version.compare(x, y) == .orderedDescending
            case (nil, _): false
            case (_, nil): true
            }
        }
        return lines.map { line in
            let versions = byLine[line]!.sorted { Version.compare($0, $1) == .orderedDescending }
            return InstalledVersionGroup(line: line, versions: versions.enumerated().map { index, version in
                InstalledVersion(
                    version: version, isGlobal: version == plugin.activeGlobalVersion,
                    isSuperseded: line != nil && index > 0,
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
        var newest: [String: String] = [:]
        for version in plugin.installedVersions {
            guard let line = Version.line(of: version) else { continue }
            if let previous = newest[line], Version.compare(version, previous) != .orderedDescending { continue }
            newest[line] = version
        }
        let baseLine = plugin.baseVersion.flatMap(Version.line(of:))
        return newest.keys.sorted { Version.compare($0, $1) == .orderedDescending }.map { line in
            let current = newest[line]!
            // mise's answer for the line; whether it is stable is mise's call, not guessed here.
            let latest = plugin.status == .done ? plugin.latestByLine[line] ?? (baseLine == line ? plugin.sameMajorLatest : nil) : nil
            // Only a newer version is an update: mise's latest can trail what is already installed.
            let update = latest.flatMap { Version.compare($0, current) == .orderedDescending ? $0 : nil }
            return InstalledSeries(line: line, current: current, latest: latest, update: update)
        }
    }

    public static func hasUpdates(_ plugin: PluginRow) -> Bool {
        update(plugin) != nil || installedSeries(plugin).contains { $0.update != nil }
    }

    /// The global line's update and a newer numeric major. A vendor line such as `temurin-21` gets
    /// no "new major" offer: mise's overall latest could silently switch the vendor.
    public static func update(_ plugin: PluginRow) -> ToolUpdate? {
        guard plugin.status == .done, let base = plugin.baseVersion, let baseMajor = Version.major(of: base) else { return nil }
        func needsInstall(_ version: String) -> Bool {
            !plugin.installedVersions.contains {
                Version.line(of: $0) == Version.line(of: version) && Version.compare($0, version) != .orderedAscending
            }
        }
        func newer(_ candidate: String?) -> String? {
            candidate.flatMap {
                needsInstall($0) && Version.compare($0, base) == .orderedDescending ? $0 : nil
            }
        }
        let primary = newer(plugin.sameMajorLatest)
        let major = newer(plugin.releaseLatest).flatMap { Version.major(of: $0).map { $0 > baseMajor } == true ? $0 : nil }
        return primary == nil && major == nil ? nil : ToolUpdate(primary: primary, major: major)
    }

    /// Versions the "other versions" inspector may offer to install: mise's answers and, on request,
    /// the pre-release candidate. Never the global version, never older than the base, and for a
    /// vendor line never another line (the tool's overall latest can be another vendor's build).
    public static func otherCandidates(_ plugin: PluginRow, includePrerelease: Bool) -> [String] {
        let base = plugin.baseVersion
        let baseLine = base.flatMap(Version.line(of:))
        let vendorLine = baseLine != nil && base.flatMap(Version.major(of:)) == nil
        var seen = Set<String>()
        return [plugin.sameMajorLatest, plugin.releaseLatest, includePrerelease ? plugin.overallLatest : nil]
            .compactMap { $0 }
            .filter { candidate in
                guard candidate != plugin.activeGlobalVersion, seen.insert(candidate).inserted else { return false }
                // A channel such as `stable` has nothing to order candidates against, so they are listed.
                // A runtime without a line (pypy3.10-…, semeru-openj9-…) gets none: nothing here is
                // known to be the same runtime.
                guard let base, baseLine != nil else { return base?.contains(where: \.isNumber) != true }
                if vendorLine, Version.line(of: candidate) != baseLine { return false }
                return Version.compare(candidate, base) == .orderedDescending
            }
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
        guard let base = plugin.baseVersion, Version.line(of: base) != nil else { return Strings.ToolStatus.channel }
        if hasUpdates(plugin) { return Strings.ToolStatus.updateAvailable }
        if Version.startsWithDigit(base), Version.isPreRelease(base) { return Strings.ToolStatus.prerelease }
        // mise had no answer for the line in use: that is not the same as being up to date.
        if plugin.sameMajorLatest == nil { return Strings.ToolStatus.noComparison }
        return Strings.ToolStatus.latestStable
    }
}
