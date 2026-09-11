import { state, setBusy } from "../core/state.svelte";
import { checkLatestMiseRelease, reloadMiseVersion } from "./mise";
import { reloadAndCheckTools, checkUpdates } from "./updater";
import { checkPluginDefinitionUpdates } from "./installs";
import { addLog } from "./logs";

/** One entry point for startup, manual and scheduled checks. Checks never install. */
export async function checkAllUpdates(): Promise<void> {
	if (state.busy || state.updateCheckRunning || !state.miseIsInstalled) return;
	state.updateCheckRunning = true;
	try {
		await reloadMiseVersion();
		// Show local tools before waiting for network-dependent release checks.
		await reloadAndCheckTools(false);
		await checkLatestMiseRelease();
		if (!state.toolsError) await checkUpdates();
		await checkPluginDefinitionUpdates();
	} catch (error) {
		addLog(`Update check failed: ${(error as Error).message}`);
	} finally {
		state.updateCheckRunning = false;
		setBusy(false);
	}
}
