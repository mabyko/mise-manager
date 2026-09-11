/// App launch flow (was main.ts) and the scheduled check timer (was App.svelte's setInterval).
extension AppState {
    public func startup() async {
        scheduleIntervalChecks()
        setBusy(true, Strings.checkingMise)
        await checkMiseInstallationStatus()
        guard miseIsInstalled else {
            activeTab = .mise
            setBusy(false, Strings.miseRequired)
            return
        }
        setBusy(false)
        if settings.checkOnStartup {
            await checkAllUpdates()
        } else {
            await reloadMiseVersion()
            await reloadAndCheckTools(check: false)
        }
    }

    /// (Re)starts the periodic check for the current `checkIntervalHours`; 0 stops it.
    public func scheduleIntervalChecks() {
        intervalTask?.cancel()
        intervalTask = nil
        let hours = settings.checkIntervalHours
        guard hours > 0 else { return }
        intervalTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(hours * 3600))
                guard !Task.isCancelled else { return }
                await self?.checkAllUpdates()
            }
        }
    }
}
