/// Tool list, update checks and version actions. Port of src/mainview/features/updater.ts.
extension AppState {
    // MARK: Tool list

    /// Reloads the tool list from mise. False (with toolsError set) when mise could not be read.
    func loadPlugins() async -> Bool {
        setBusy(true, Strings.loadingPlugins)
        toolsCheckedAt = nil
        toolsError = nil
        defer { toolsLoaded = true }
        do {
            plugins = try await mise.installedPlugins().map(PluginRow.init)
            addLog("Loaded \(plugins.count) plugin(s).")
            setBusy(false)
            return true
        } catch {
            toolsError = error.localizedDescription
            addLog("Failed to load plugins: \(error.localizedDescription)")
            setBusy(false, Strings.loadFailed)
            return false
        }
    }

    /// Re-reads one row's versions from mise. Nil when mise no longer lists the tool (row dropped).
    func refreshPlugin(_ name: String) async throws -> PluginRow? {
        guard let found = try await mise.installedPlugins().first(where: { $0.name == name }) else {
            plugins.removeAll { $0.name == name }
            addLog("\(name): no longer listed by mise; removed from the list.")
            return nil
        }
        updatePlugin(name) {
            $0.activeGlobalVersion = found.activeGlobalVersion
            $0.installedVersions = found.installedVersions
        }
        return plugin(name)
    }

    // MARK: Update checks

    func checkPlugin(_ row: PluginRow) async {
        guard let base = row.baseVersion else {
            updatePlugin(row.name) { $0.status = .error; $0.error = "no active/installed version to compare" }
            addLog("\(row.name): no base version found.")
            return
        }
        updatePlugin(row.name) { $0.status = .checking }
        do {
            let result = try await mise.checkPluginUpdates(plugin: row.name, baseVersion: base, includeChannels: false)
            updatePlugin(row.name) {
                $0.latestByMajor = result.latestByMajor
                $0.sameMajorLatest = result.sameMajorLatest
                $0.releaseLatest = result.releaseLatest
                $0.overallLatest = result.overallLatest
                $0.checkedVersions = result.checkedVersions
                $0.status = result.error == nil ? .done : .error
                $0.error = result.error
            }
            addLog(result.error.map { "\(row.name): \($0)" }
                ?? "\(row.name): checked \(result.checkedVersions) version(s), base=\(base).")
        } catch {
            updatePlugin(row.name) { $0.status = .error; $0.error = error.localizedDescription }
            addLog("\(row.name): \(error.localizedDescription)")
        }
    }

    /// Checks every tool, four at a time. Never installs anything.
    public func checkUpdates() async {
        if busy || plugins.isEmpty { return }
        setBusy(true, Strings.checkingUpdates, progress: 0)
        for index in plugins.indices { plugins[index].status = .idle; plugins[index].error = nil }

        let queue = plugins
        let total = Double(queue.count)
        var next = 0
        var processed = 0.0
        await withTaskGroup(of: String.self) { group in
            for _ in 0..<min(4, queue.count) {
                let row = queue[next]
                next += 1
                setBusy(true, Strings.checking(row.name), progress: processed / total * 100)
                group.addTask { await self.checkPlugin(row); return row.name }
            }
            for await name in group {
                processed += 1
                setBusy(true, Strings.checking(name), progress: processed / total * 100)
                if next < queue.count {
                    let row = queue[next]
                    next += 1
                    group.addTask { await self.checkPlugin(row); return row.name }
                }
            }
        }
        toolsCheckedAt = Self.nowLabel()
        setBusy(false, Strings.checkComplete, progress: 100)
    }

    /// Full refresh: reload the tool list, then check every tool. Safe to await from app start-up.
    public func reloadAndCheckTools(check: Bool = true) async {
        if busy { return }
        if await loadPlugins(), check { await checkUpdates() }
    }

    /// Row-level retry: reconcile the row's versions from mise first, then check it.
    public func retryCheck(_ name: String) async {
        if busy || plugin(name) == nil { return }
        setBusy(true, Strings.checking(name))
        updatePlugin(name) { $0.status = .checking }
        defer { setBusy(false, Strings.checkComplete) }
        do {
            if let row = try await refreshPlugin(name) { await checkPlugin(row) }
        } catch {
            let message = "refresh failed - \(error.localizedDescription)"
            updatePlugin(name) { $0.status = .error; $0.error = message }
            addLog("\(name): \(message)")
        }
    }

    // MARK: Version actions

    /// Candidates are only meaningful for the base they were checked against. After a successful
    /// mutation a verified row whose base did not move stays done; anything else is re-checked so a
    /// cached 22.15 is never offered as a same-major update for 20.x.
    func settlePlugin(before: PluginRow, row: PluginRow) async {
        if before.status == .done && before.baseVersion == row.baseVersion {
            updatePlugin(row.name) { $0.status = .done; $0.error = nil }
        } else {
            await checkPlugin(row)
        }
    }

    /// One mise mutation on a tool: busy span, row status, then the row is re-read from mise whether
    /// or not the command succeeded, so whatever mise actually did is what the table shows.
    func runToolAction(
        _ name: String, status: PluginStatus, label: String,
        action: () async throws -> Void, okLog: String, failLog: () -> String
    ) async {
        guard !busy, !updateCheckRunning, let before = plugin(name) else { return }
        setBusy(true, label)
        updatePlugin(name) { $0.status = status }
        defer { setBusy(false) }
        do {
            try await action()
        } catch {
            // Best-effort re-read; the command error is what matters. A base that moved anyway
            // (partially applied command) must not keep stale candidates.
            let row = try? await refreshPlugin(name)
            if let row, before.baseVersion != row.baseVersion { updatePlugin(name) { $0.clearCandidates() } }
            updatePlugin(name) { $0.status = .error; $0.error = error.localizedDescription }
            addLog("\(name): \(failLog()) - \(error.localizedDescription)")
            return
        }
        addLog("\(name): \(okLog)")
        do {
            if let row = try await refreshPlugin(name) { await settlePlugin(before: before, row: row) }
        } catch {
            let message = "refresh failed after success - \(error.localizedDescription)"
            updatePlugin(name) { $0.status = .error; $0.error = message }
            addLog("\(name): \(message)")
        }
    }

    public func installVersion(_ name: String, _ version: String) async {
        await runToolAction(
            name, status: .updating, label: Strings.installing("\(name)@\(version)"),
            action: { _ = try await mise.install(plugin: name, version: version) },
            okLog: "installed \(version).", failLog: { "install failed" })
    }

    public func seriesUpdateSwitchesGlobal(_ plugin: PluginRow, _ version: String) -> Bool {
        settings.switchGlobalAfterUpdate && plugin.activeGlobalVersion != nil
            && Version.major(of: plugin.activeGlobalVersion!) == Version.major(of: version)
    }

    /// Series updates install only; the global default moves only when the setting says so.
    public func updateInstalledSeries(_ name: String, _ version: String) async {
        guard !busy, let plugin = plugin(name), ToolStatus.installedSeries(plugin).contains(where: { $0.update == version }) else { return }
        if seriesUpdateSwitchesGlobal(plugin, version) { await updateToVersion(name, version) } else { await installVersion(name, version) }
    }

    public func useInstalledVersion(_ name: String, _ version: String) async {
        await runToolAction(
            name, status: .updating, label: Strings.using("\(name)@\(version)"),
            action: { _ = try await mise.useGlobal(plugin: name, version: version) },
            okLog: "switched global version to \(version).", failLog: { "use failed" })
    }

    /// "Update to X": install then switch global. The old version stays installed.
    public func updateToVersion(_ name: String, _ version: String) async {
        var failLog = "install failed"
        await runToolAction(
            name, status: .updating, label: Strings.updating("\(name)@\(version)"),
            action: {
                _ = try await mise.install(plugin: name, version: version)
                failLog = "installed \(version) but switching global failed"
                _ = try await mise.useGlobal(plugin: name, version: version)
            },
            okLog: "updated to \(version) (installed + switched global).", failLog: { failLog })
    }

    public func deleteInstalledVersion(_ name: String, _ version: String) async {
        guard !busy, let plugin = plugin(name) else { return }
        guard plugin.activeGlobalVersion != version else {
            addLog("\(name): cannot delete active global version \(version).")
            return
        }
        await runToolAction(
            name, status: .deleting, label: Strings.deleting("\(name)@\(version)"),
            action: { _ = try await mise.deleteVersion(plugin: name, version: version) },
            okLog: "deleted \(version).", failLog: { "delete failed" })
    }

    // MARK: Confirm dialogs

    public func requestMajorUpdate(_ name: String, _ version: String) {
        pendingMajorUpdate = PendingMajorUpdate(pluginName: name, fromVersion: plugin(name)?.activeGlobalVersion, targetVersion: version)
    }

    public func confirmMajorUpdate() async {
        guard let pending = pendingMajorUpdate, !busy else { return }
        pendingMajorUpdate = nil
        await updateToVersion(pending.pluginName, pending.targetVersion)
    }

    public func requestDelete(_ name: String, _ version: String) {
        pendingDelete = PendingDelete(pluginName: name, version: version)
    }

    public func confirmDeleteInstalledVersion() async {
        guard let pending = pendingDelete, !busy else { return }
        pendingDelete = nil
        await deleteInstalledVersion(pending.pluginName, pending.version)
    }
}
