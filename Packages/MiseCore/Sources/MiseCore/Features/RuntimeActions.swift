/// Commands the tray (and later the menu bar) can issue. Every command is re-validated against live state.
public enum RuntimeAction: Equatable, Sendable {
    case check
    case apply(id: String)
    case use(name: String, version: String)
    case open(tab: ActiveTab, name: String? = nil)
}

extension AppState {
    public func run(_ action: RuntimeAction) async {
        if case .open(let tab, let name) = action {
            activeTab = tab
            if let name, plugin(name) != nil { selectedToolName = name }
            showMainWindow()
            if tab == .installs, !installsLoaded, !busy, !updateCheckRunning { await reloadPluginDefinitions() }
            return
        }
        if busy || updateCheckRunning || pendingDelete != nil || pendingMajorUpdate != nil || pendingMiseUpdateConfirm || pendingPluginUrlDialog != nil { return }
        switch action {
        case .check:
            await checkAllUpdates()
        case .use(let name, let version):
            if plugin(name)?.installedVersions.contains(version) == true { await useInstalledVersion(name, version) }
        case .apply(let id):
            guard let item = updateSummary.items.first(where: { $0.id == id }) else { return }
            switch item.kind {
            case .series: await updateInstalledSeries(item.name, item.to)
            case .plugin: await updatePluginDefinition(item.name)
            case .mise:
                await run(.open(tab: .mise, name: item.name))
                openMiseUpdateDialog()
            case .major:
                await run(.open(tab: .updater, name: item.name))
                requestMajorUpdate(item.name, item.to)
            }
        case .open: break
        }
    }
}
