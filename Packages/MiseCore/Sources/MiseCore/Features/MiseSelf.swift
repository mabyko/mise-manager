/// mise itself: version, latest release, self-update, installation. Port of features/mise.ts.
extension AppState {
    public func reloadMiseVersion() async {
        setBusy(true, Strings.loadingMiseVersion)
        do {
            let version = try await mise.version()
            miseVersion = version
            miseLoaded = true
            miseCurrentError = nil
            addLog("Loaded mise version: \(version ?? "unknown").")
            setBusy(false)
        } catch {
            miseLoaded = true
            miseCurrentError = error.localizedDescription
            addLog("Failed to load mise version: \(error.localizedDescription)")
            setBusy(false, Strings.loadFailed)
        }
    }

    public func checkLatestMiseRelease() async {
        setBusy(true, Strings.checkingLatestMise)
        defer { miseLatestLoaded = true; miseLatestCheckedAt = Self.nowLabel() }
        do {
            let latest = try await latestRelease()
            miseLatestVersion = latest
            miseLatestError = nil
            addLog("Loaded latest mise release: \(latest ?? "unknown").")
            setBusy(false)
        } catch {
            miseLatestError = error.localizedDescription
            addLog("Failed to check latest mise release: \(error.localizedDescription)")
            setBusy(false, Strings.checkFailed)
        }
    }

    public func openMiseUpdateDialog() {
        let status = miseStatus
        guard status.canUpdate else {
            addLog("mise update blocked: \(status.buttonHint)")
            return
        }
        pendingMiseUpdateConfirm = true
    }

    public func cancelMiseUpdateDialog() { pendingMiseUpdateConfirm = false }

    public func confirmMiseSelfUpdate() async {
        guard !busy, !updateCheckRunning, miseStatus.canUpdate else { return }
        pendingMiseUpdateConfirm = false
        miseSelfUpdateError = nil
        setBusy(true, Strings.runningMiseSelfUpdate)
        do {
            let result = try await mise.selfUpdate()
            miseVersion = result.afterVersion
            miseLoaded = true
            miseCurrentError = nil
            miseLastResult = [
                "Before: \(result.beforeVersion ?? "unknown")",
                "After: \(result.afterVersion ?? "unknown")",
                result.stdout.isEmpty ? "" : "\nSTDOUT:\n\(result.stdout)",
                result.stderr.isEmpty ? "" : "\nSTDERR:\n\(result.stderr)",
            ].filter { !$0.isEmpty }.joined(separator: "\n")
            addLog("mise self-update finished: \(result.beforeVersion ?? "unknown") -> \(result.afterVersion ?? "unknown").")
            setBusy(false, Strings.updateComplete, progress: 100)
        } catch {
            miseSelfUpdateError = error.localizedDescription
            miseLastResult = "ERROR:\n\(error.localizedDescription)"
            addLog("mise self-update failed: \(error.localizedDescription)")
            setBusy(false, Strings.updateFailed)
        }
    }

    public func checkMiseInstallationStatus() async {
        miseIsInstalled = await mise.isInstalled()
        miseInstalledChecked = true
        if !miseIsInstalled { addLog("mise is not installed on this system.") }
    }

    public func startMiseInstall(_ method: MiseInstallMethod) async {
        if busy || miseInstalling { return }
        miseInstalling = true
        miseInstallMethod = method
        miseLastResult = ""
        setBusy(true, Strings.installingMise(method))
        defer { miseInstalling = false; miseInstallMethod = nil }
        do {
            let result = try await method == .sh ? mise.installViaSh() : mise.installViaBrew()
            miseLastResult = [
                result.success ? "Installation completed successfully!" : "Installation failed.",
                result.stdout.isEmpty ? "" : "\nSTDOUT:\n\(result.stdout)",
                result.stderr.isEmpty ? "" : "\nSTDERR:\n\(result.stderr)",
            ].filter { !$0.isEmpty }.joined(separator: "\n")
            addLog("mise \(method.rawValue) install \(result.success ? "succeeded" : "failed").")
            if result.success {
                addLog("mise installed. Verifying installation...")
                try? await Task.sleep(for: .seconds(2))
                await checkMiseInstallationStatus()
                if miseIsInstalled {
                    addLog("mise installation verified. Loading version...")
                    setBusy(false)
                    await reloadMiseVersion()
                    await checkLatestMiseRelease()
                    await reloadAndCheckTools()
                } else {
                    addLog("mise installation completed but not yet detected in PATH. You may need to restart the app.")
                }
            }
            setBusy(false, result.success ? Strings.installed : Strings.installFailed)
        } catch {
            miseLastResult = "ERROR:\n\(error.localizedDescription)"
            addLog("mise install failed: \(error.localizedDescription)")
            setBusy(false, Strings.installFailed)
        }
    }
}
