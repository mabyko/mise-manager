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
}

extension AppState {
    public var updateSummary: UpdateSummary {
        var items: [UpdateItem] = []
        for tool in plugins {
            for series in ToolStatus.installedSeries(tool) {
                if let update = series.update {
                    items.append(UpdateItem(id: "\(tool.name)@\(update)", kind: .series, name: tool.name,
                                            label: "\(tool.name) \(series.major).x", from: series.current, to: update))
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
                                    to: MiseStatus.normalizeVersionToken(miseLatestVersion) ?? ""))
        }
        if pluginUpdatesError == nil {
            for name in outdatedPluginNames {
                items.append(UpdateItem(id: "plugin:\(name)", kind: .plugin, name: name, label: Strings.Summary.plugin(name),
                                        from: Strings.Summary.installedSource, to: Strings.Summary.latestSource))
            }
        }
        let errors = [toolsError, miseCurrentError, miseLatestError, pluginUpdatesError].compactMap { $0 }
            + plugins.filter { $0.status == .error }.map { "\($0.name): \($0.error ?? Strings.ToolStatus.checkFailed)" }
        let settled: Set<MiseStatusKey> = [.upToDate, .aheadOrCustom, .updateAvailable, .updatedNeedsReload]
        let unchecked = !toolsLoaded || toolsCheckedAt == nil || miseLatestCheckedAt == nil || pluginUpdatesCheckedAt == nil
            || !settled.contains(mise.key)
            || plugins.contains { $0.status != .done || ($0.sameMajorLatest == nil && $0.releaseLatest == nil && $0.latestByMajor.isEmpty) }
        return UpdateSummary(items: items, errors: errors, attention: unchecked || !errors.isEmpty)
    }
}
