public struct UpdateItem: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable { case series, major, mise, plugin }
    public let id: String
    public let kind: Kind
    public let name: String
    public let label: String
    public let from: String
    public let to: String
}

/// The app, popover and menu-bar count all describe the same pending installs.
public struct UpdateSummary: Equatable, Sendable {
    public let items: [UpdateItem]
    public let errors: [String]
    public let attention: Bool
    /// Checked lines mise has no latest version for (`node 27.x` with only pre-releases, an `http:`
    /// tool), or a whole tool when it has no line at all. Checking again cannot change that, so they
    /// are listed instead of raising `attention`, and never pass as up to date.
    public let uncomparable: [String]
}

extension AppState {
    public var updateSummary: UpdateSummary {
        var items: [UpdateItem] = []
        for tool in plugins {
            for series in ToolStatus.installedSeries(tool) {
                if let update = series.update {
                    items.append(UpdateItem(id: "\(tool.name)@\(update)", kind: .series, name: tool.name,
                                            label: "\(tool.name) \(series.line).x", from: series.current, to: update))
                }
            }
            if let major = ToolStatus.update(tool)?.major, !items.contains(where: { $0.name == tool.name && $0.to == major }) {
                items.append(UpdateItem(id: "\(tool.name)@\(major)", kind: .major, name: tool.name,
                                        label: Strings.Summary.newMajor(tool.name),
                                        from: tool.activeGlobalVersion ?? Strings.Summary.unselected, to: major))
            }
        }
        let mise = miseStatus
        if mise.canUpdate {
            items.append(UpdateItem(id: "mise", kind: .mise, name: "mise", label: "mise",
                                    from: MiseStatus.normalizeVersionToken(miseVersion) ?? "",
                                    to: MiseStatus.normalizeVersionToken(miseEligibleVersion) ?? ""))
        }
        if pluginUpdatesError == nil {
            for name in outdatedPluginNames {
                items.append(UpdateItem(id: "plugin:\(name)", kind: .plugin, name: name, label: Strings.Summary.plugin(name),
                                        from: Strings.Summary.installedSource, to: Strings.Summary.latestSource))
            }
        }
        let errors = [toolsError, miseCurrentError, miseLatestError, pluginUpdatesError].compactMap { $0 }
            + plugins.filter { $0.status == .error }.map { "\($0.name): \($0.error ?? Strings.ToolStatus.checkFailed)" }
        let settled: Set<MiseStatusKey> = [.upToDate, .aheadOrCustom, .updateAvailable, .releaseWaiting]
        let unchecked = !toolsLoaded || toolsCheckedAt == nil || miseLatestCheckedAt == nil || pluginUpdatesCheckedAt == nil
            || !settled.contains(mise.key)
            || plugins.contains { $0.status != .done }
        let uncomparable = plugins.filter { $0.status == .done }.flatMap { tool -> [String] in
            let unanswered = ToolStatus.installedSeries(tool).filter { $0.latest == nil }.map { "\(tool.name) \($0.line).x" }
            let runtimes = tool.installedVersions.filter(Version.isLinelessRuntime).map { "\(tool.name) \($0)" }
            if !unanswered.isEmpty || !runtimes.isEmpty { return unanswered + runtimes }
            return tool.sameMajorLatest == nil && tool.releaseLatest == nil && tool.latestByLine.isEmpty ? [tool.name] : []
        }
        return UpdateSummary(items: items, errors: errors, attention: unchecked || !errors.isEmpty, uncomparable: uncomparable)
    }
}
