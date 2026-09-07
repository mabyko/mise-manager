import { state, setBusy } from "./state.svelte";
import { rpc } from "./rpc";
import { toPluginRow, normalizeInstalled, updatePluginInState } from "./helpers";
import { addLog } from "../features/logs";

export async function refreshPlugin(pluginName: string): Promise<void> {
	const latest = await rpc.request.listInstalledPlugins();
	const found = latest.find((entry) => entry.name === pluginName);
	if (!found) {
		return;
	}
	updatePluginInState(pluginName, {
		activeGlobalVersion: found.activeGlobalVersion,
		installedVersions: found.installedVersions,
	});
}

export async function reloadPlugins(): Promise<void> {
	setBusy(true, "Loading plugins");
	state.toolsError = null;
	try {
		const installed = await rpc.request.listInstalledPlugins();
		state.plugins = installed.map(toPluginRow).map(normalizeInstalled);
		addLog(`Loaded ${state.plugins.length} plugin(s).`);
		setBusy(false);
	} catch (error) {
		state.toolsError = (error as Error).message;
		addLog(`Failed to load plugins: ${(error as Error).message}`);
		setBusy(false, "Load failed");
	} finally {
		state.toolsLoaded = true;
	}
}
