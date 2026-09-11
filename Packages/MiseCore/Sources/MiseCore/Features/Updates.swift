/// One entry point for startup, manual and scheduled checks. Checks never install.
extension AppState {
    public func checkAllUpdates() async {
        if busy || updateCheckRunning || !miseIsInstalled { return }
        updateCheckRunning = true
        defer { updateCheckRunning = false }
        await reloadMiseVersion()
        // Show local tools before waiting for network-dependent release checks.
        await reloadAndCheckTools(check: false)
        await checkLatestMiseRelease()
        if toolsError == nil { await checkUpdates() }
        await checkPluginDefinitionUpdates()
        let clean = toolsError == nil && miseCurrentError == nil && miseLatestError == nil && pluginUpdatesError == nil
        setBusy(false, clean ? Strings.checkComplete : Strings.ready, progress: clean ? 100 : nil)
    }
}
