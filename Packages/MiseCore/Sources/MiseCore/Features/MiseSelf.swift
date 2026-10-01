/// mise itself: version, latest release, self-update, installation. Port of features/mise.ts.
extension AppState {
    public func reloadMiseVersion() async {
        guard !busy else { return }
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
        guard !busy else { return }
        setBusy(true, Strings.checkingLatestMise)
        defer { miseLatestLoaded = true; miseLatestCheckedAt = Self.nowLabel() }
        do {
            let releases = try await latestRelease()
            let policy = try await mise.releasePolicy()
            miseReleases = releases
            miseLatestVersion = releases.first?.version
            miseEligibleVersion = policy.eligibleVersion
            miseMinimumReleaseAge = policy.minimumAge
            miseLatestError = nil
            addLog("Loaded mise releases: latest \(miseLatestVersion ?? "unknown"), eligible \(policy.eligibleVersion), minimum release age \(policy.minimumAge).")
            setBusy(false)
        } catch {
            miseLatestError = error.localizedDescription
            addLog("Failed to check latest mise release: \(error.localizedDescription)")
            setBusy(false, Strings.checkFailed)
        }
    }

    public func openMiseUpdateDialog() {
        guard !busy, !updateCheckRunning else { return }
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
            // Re-read mise settings and eligibility after confirmation; never pin a version
            // (an explicit version would bypass mise's release-age safety policy).
            let policy: MiseReleasePolicy
            do { policy = try await mise.releasePolicy() }
            catch {
                miseLatestError = error.localizedDescription
                throw error
            }
            miseEligibleVersion = policy.eligibleVersion
            miseMinimumReleaseAge = policy.minimumAge
            guard let current = MiseStatus.normalizeVersionToken(miseVersion),
                  Version.compare(current, policy.eligibleVersion) == .orderedAscending else {
                miseLastResult = "적용 정책(\(policy.minimumAge))을 만족하는 새 업데이트가 없습니다."
                addLog("mise update skipped: eligible version \(policy.eligibleVersion).")
                setBusy(false)
                return
            }
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
            let before = MiseStatus.normalizeVersionToken(result.beforeVersion) ?? current
            let after = MiseStatus.normalizeVersionToken(result.afterVersion)
            let changed = after != nil && before != after
            setBusy(false, changed ? Strings.updateComplete : "mise 버전이 변경되지 않았습니다.", progress: changed ? 100 : nil)
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
