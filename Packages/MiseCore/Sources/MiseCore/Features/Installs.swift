/// Plugin definitions (installs tab). Port of src/mainview/features/installs.ts.
public enum PluginInstallPlan: Equatable, Sendable {
    /// Keeps the dialog open.
    case invalid(log: String)
    /// Closes the dialog without installing.
    case skip(log: String)
    case install(plugin: String, gitUrl: String?, force: Bool, removeToolAlias: Bool)
}

extension AppState {
    public func reloadPluginDefinitions() async {
        guard !busy else { return }
        await loadPluginDefinitions()
    }

    private func loadPluginDefinitions() async {
        setBusy(true, Strings.loadingPluginDefinitions)
        installsError = nil
        do {
            async let users = mise.installedUserPluginInfos()
            async let core = mise.corePluginNames()
            async let tools = mise.installedToolNames()
            async let remote = mise.remotePluginInfos()
            let (userInfos, coreNames, toolNames, remoteInfos) = try await (users, core, tools, remote)
            installedUserPluginInfos = userInfos
            installedPluginNames = userInfos.map(\.name)
            corePluginNames = coreNames
            installedToolNames = toolNames
            remotePluginInfos = remoteInfos
            remotePluginNames = Array(Set(remoteInfos.map(\.name))).sorted { $0.localizedCompare($1) == .orderedAscending }
            installsLoaded = true
            addLog("Loaded install sources: remotePlugins=\(remotePluginNames.count), userPlugins=\(installedPluginNames.count), corePlugins=\(corePluginNames.count), installedTools=\(installedToolNames.count).")
            setBusy(false)
        } catch {
            installsError = error.localizedDescription
            addLog("Failed to load plugin definitions: \(error.localizedDescription)")
            setBusy(false, Strings.loadFailed)
        }
    }

    public func checkPluginDefinitionUpdates() async {
        if busy { return }
        setBusy(true, Strings.checkingPluginUpdates)
        pluginUpdatesError = nil
        defer { pluginUpdatesCheckedAt = Self.nowLabel(); setBusy(false) }
        do {
            outdatedPluginNames = try await mise.outdatedPluginDefinitions()
            addLog("Plugin updates: \(outdatedPluginNames.count) available.")
        } catch {
            outdatedPluginNames = []
            pluginUpdatesError = error.localizedDescription
            addLog("Plugin update check failed: \(error.localizedDescription)")
        }
    }

    public func updatePluginDefinition(_ plugin: String) async {
        guard !busy, !updateCheckRunning, pluginUpdatesError == nil, outdatedPluginNames.contains(plugin) else { return }
        setBusy(true, Strings.updatingPluginDefinition(plugin))
        pluginUpdateResult = nil
        var updated = false
        do {
            _ = try await mise.updatePluginDefinition(plugin)
            updated = true
            pluginUpdateResult = Strings.pluginUpdated(plugin)
            // A plugin can change its remote version list; discard all old candidates.
            for index in plugins.indices { plugins[index].status = .idle }
            toolsCheckedAt = nil
            addLog(pluginUpdateResult!)
        } catch {
            pluginUpdateResult = Strings.pluginUpdateFailed(plugin, error.localizedDescription)
            addLog(pluginUpdateResult!)
        }
        setBusy(false)
        if updated { await checkPluginDefinitionUpdates() }
    }

    public func installPluginDefinition(_ plugin: String, gitUrl: String? = nil, force: Bool = false, removeToolAlias: Bool = false) async {
        if busy { return }
        setBusy(true, Strings.installingPlugin(plugin, force: force))
        do {
            let result = try await mise.installPluginDefinition(plugin: plugin, gitUrl: gitUrl, force: force, removeToolAlias: removeToolAlias)
            await loadPluginDefinitions()
            let url = gitUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            addLog("\(plugin): plugin \(force ? "updated" : "installed")\(url.isEmpty ? "" : " (\(url))").")
            if result.stdout.contains("Updated tool_alias") || result.stdout.contains("Removed tool_alias") {
                addLog("\(plugin): \(result.stdout.split(separator: "\n").last ?? "")")
            }
        } catch {
            addLog("\(plugin): plugin \(force ? "update" : "install") failed - \(error.localizedDescription)")
            setBusy(false, Strings.pluginInstallFailed(plugin, force: force))
        }
    }

    public func uninstallPluginDefinition(_ plugin: String) async {
        if busy { return }
        setBusy(true, Strings.removingPlugin(plugin))
        do {
            _ = try await mise.uninstallPluginDefinition(plugin)
            await loadPluginDefinitions()
            addLog("\(plugin): plugin removed.")
        } catch {
            addLog("\(plugin): plugin remove failed - \(error.localizedDescription)")
            setBusy(false)
        }
    }

    // MARK: Plugin URL dialog

    public func openInstallPluginDialog(_ plugin: String) {
        pendingPluginUrlDialog = .install(pluginName: plugin)
        pendingPluginNameValue = ""
        pendingPluginUrlValue = ""
    }

    public func openCustomPluginDialog() {
        pendingPluginUrlDialog = .customInstall
        pendingPluginNameValue = ""
        pendingPluginUrlValue = ""
    }

    public func openEditPluginDialog(_ plugin: String) {
        guard let userInfo = PluginSource.userPluginInfo(plugin, in: installedUserPluginInfos) else {
            addLog("\(plugin): cannot edit URL because user plugin is not installed.")
            return
        }
        pendingPluginUrlDialog = .edit(pluginName: plugin)
        pendingPluginNameValue = ""
        pendingPluginUrlValue = userInfo.url ?? ""
    }

    public func closePluginUrlDialog() {
        pendingPluginUrlDialog = nil
        pendingPluginNameValue = ""
        pendingPluginUrlValue = ""
    }

    /// Pure decision core of the plugin URL dialog: what to send to mise, or why not.
    public static func resolvePluginInstallPlan(
        dialog: PluginUrlDialog, nameValue: String, urlValue: String,
        installedUserPluginInfos: [PluginDefinitionInfo], remotePluginInfos: [PluginDefinitionInfo]
    ) -> PluginInstallPlan {
        let rawGitUrl = urlValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let gitUrl = PluginSource.normalizeInstallURL(rawGitUrl)

        switch dialog {
        case .customInstall:
            let name = nameValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { return .invalid(log: "Custom plugin: plugin name required.") }
            if !name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }) {
                return .invalid(log: "\(name): plugin name can only contain letters, numbers, dot, underscore, dash.")
            }
            if gitUrl.isEmpty { return .invalid(log: "\(name): Git URL is required for custom plugin install.") }
            return .install(plugin: name, gitUrl: gitUrl, force: false, removeToolAlias: false)

        case .install(let pluginName):
            return .install(plugin: pluginName, gitUrl: gitUrl.isEmpty ? nil : gitUrl, force: false, removeToolAlias: false)

        case .edit(let pluginName):
            if rawGitUrl.isEmpty { return .invalid(log: "\(pluginName): URL is required for edit.") }
            let userInfo = PluginSource.userPluginInfo(pluginName, in: installedUserPluginInfos)
            var nextGitUrl: String? = gitUrl.isEmpty ? nil : gitUrl
            var removeToolAlias = false
            if PluginSource.isDefaultURL(pluginName, gitUrl: nextGitUrl, remote: remotePluginInfos) {
                nextGitUrl = nil
                removeToolAlias = userInfo?.source == "tool_alias"
            }
            if !removeToolAlias, (userInfo?.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == rawGitUrl {
                return .skip(log: "\(pluginName): URL unchanged; plugin update skipped.")
            }
            return .install(plugin: pluginName, gitUrl: nextGitUrl, force: true, removeToolAlias: removeToolAlias)
        }
    }

    public func submitPluginUrlDialog() async {
        guard let dialog = pendingPluginUrlDialog, !busy else { return }
        let plan = Self.resolvePluginInstallPlan(
            dialog: dialog, nameValue: pendingPluginNameValue, urlValue: pendingPluginUrlValue,
            installedUserPluginInfos: installedUserPluginInfos, remotePluginInfos: remotePluginInfos)
        switch plan {
        case .invalid(let log):
            addLog(log)
        case .skip(let log):
            closePluginUrlDialog()
            addLog(log)
        case .install(let plugin, let gitUrl, let force, let removeToolAlias):
            closePluginUrlDialog()
            await installPluginDefinition(plugin, gitUrl: gitUrl, force: force, removeToolAlias: removeToolAlias)
        }
    }
}
