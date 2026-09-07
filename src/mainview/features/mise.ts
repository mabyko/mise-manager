import type { MiseSelfUpdateResult } from "../../shared/contracts";
import { getMiseStatusSnapshot } from "../core/miseStatus";
import { rpc } from "../core/rpc";
import { state, setBusy } from "../core/state.svelte";
import { addLog } from "./logs";
import { reloadAndCheckTools } from "./updater";

export async function loadPlatform(): Promise<void> {
	try {
		state.platform = await rpc.request.getPlatform();
	} catch {
		state.platform = "unknown";
	}
}

export async function reloadMiseVersion(): Promise<void> {
	setBusy(true, "Loading mise version");
	try {
		const version = await rpc.request.getMiseVersion();
		state.miseVersion = version;
		state.miseLoaded = true;
		state.miseCurrentError = null;
		addLog(`Loaded mise version: ${version ?? "unknown"}.`);
		setBusy(false);
	} catch (error) {
		state.miseLoaded = true;
		state.miseCurrentError = (error as Error).message;
		addLog(`Failed to load mise version: ${(error as Error).message}`);
		setBusy(false, "Load failed");
	}
}

export async function checkLatestMiseRelease(): Promise<void> {
	setBusy(true, "Checking latest mise release");
	try {
		const latest = await rpc.request.getLatestMiseRelease();
		state.miseLatestVersion = latest;
		state.miseLatestLoaded = true;
		state.miseLatestError = null;
		state.miseLatestCheckedAt = new Date().toLocaleString("ko-KR", {
			hour12: false,
		});
		addLog(`Loaded latest mise release: ${latest ?? "unknown"}.`);
		setBusy(false);
	} catch (error) {
		state.miseLatestLoaded = true;
		state.miseLatestError = (error as Error).message;
		state.miseLatestCheckedAt = new Date().toLocaleString("ko-KR", {
			hour12: false,
		});
		addLog(`Failed to check latest mise release: ${(error as Error).message}`);
		setBusy(false, "Check failed");
	}
}

export function openMiseUpdateDialog(): void {
	const status = getMiseStatusSnapshot(state);
	if (!status.canUpdate) {
		addLog(`mise update blocked: ${status.buttonHint}`);
		return;
	}
	state.pendingMiseUpdateConfirm = true;
}

export function cancelMiseUpdateDialog(): void {
	state.pendingMiseUpdateConfirm = false;
}

export async function confirmMiseSelfUpdate(): Promise<void> {
	if (state.busy) {
		return;
	}
	state.pendingMiseUpdateConfirm = false;
	setBusy(true, "Running mise self-update");

	try {
		const result: MiseSelfUpdateResult = await rpc.request.selfUpdateMise();
		state.miseVersion = result.afterVersion;
		state.miseLoaded = true;
		state.miseCurrentError = null;
		state.miseNeedsReload = true;
		state.miseLastResult = [
			`Before: ${result.beforeVersion ?? "unknown"}`,
			`After: ${result.afterVersion ?? "unknown"}`,
			result.stdout ? `\nSTDOUT:\n${result.stdout}` : "",
			result.stderr ? `\nSTDERR:\n${result.stderr}` : "",
		]
			.filter((line) => line.length > 0)
			.join("\n");
		addLog(`mise self-update finished: ${result.beforeVersion ?? "unknown"} -> ${result.afterVersion ?? "unknown"}.`);
		setBusy(false, "Update complete", 100);
	} catch (error) {
		state.miseNeedsReload = false;
		state.miseLastResult = `ERROR:\n${(error as Error).message}`;
		addLog(`mise self-update failed: ${(error as Error).message}`);
		setBusy(false, "Update failed");
	}
}

export async function checkMiseInstallationStatus(): Promise<void> {
	try {
		const installed = await rpc.request.checkMiseInstalled();
		state.miseIsInstalled = installed;
		state.miseInstalledChecked = true;
		if (!installed) {
			addLog("mise is not installed on this system.");
		}
	} catch (error) {
		state.miseIsInstalled = false;
		state.miseInstalledChecked = true;
		addLog(`Failed to check mise installation: ${(error as Error).message}`);
	}
}

export async function startMiseInstall(method: "sh" | "brew"): Promise<void> {
	if (state.busy || state.miseInstalling) {
		return;
	}

	state.miseInstalling = true;
	state.miseInstallMethod = method;
	state.miseLastResult = "";
	setBusy(true, `Installing mise (${method === "sh" ? "curl" : "brew"})...`);

	try {
		const result = method === "sh"
			? await rpc.request.installMiseSh()
			: await rpc.request.installMiseBrew();

		state.miseLastResult = [
			result.success ? "Installation completed successfully!" : "Installation failed.",
			result.stdout ? `\nSTDOUT:\n${result.stdout}` : "",
			result.stderr ? `\nSTDERR:\n${result.stderr}` : "",
		].filter((line) => line.length > 0).join("\n");

		addLog(`mise ${method} install ${result.success ? "succeeded" : "failed"}.`);

		if (result.success) {
			addLog("mise installed. Verifying installation...");
			await new Promise((resolve) => setTimeout(resolve, 2000));
			await checkMiseInstallationStatus();

			if (state.miseIsInstalled) {
				addLog("mise installation verified. Loading version...");
				await reloadMiseVersion();
				await checkLatestMiseRelease();
				await reloadAndCheckTools();
			} else {
				addLog("mise installation completed but not yet detected in PATH. You may need to restart the app.");
			}
		}

		setBusy(false, result.success ? "Installed" : "Install failed");
	} catch (error) {
		state.miseLastResult = `ERROR:\n${(error as Error).message}`;
		addLog(`mise install failed: ${(error as Error).message}`);
		setBusy(false, "Install failed");
	} finally {
		state.miseInstalling = false;
		state.miseInstallMethod = null;
	}
}
