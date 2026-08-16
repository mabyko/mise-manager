import type { PluginUpdateInfo } from "../../shared/contracts";
import { rpc } from "../core/rpc";
import { state, setBusy } from "../core/state.svelte";
import type { PluginRow } from "../core/types";
import { resolveBaseVersion, updatePluginInState } from "../core/helpers";
import { addLog } from "./logs";
import { refreshPlugin, reloadPlugins } from "../core/app";

export function getTargetVersion(
	plugin: PluginRow,
	mode: "same" | "release" | "latest",
): string | null {
	return mode === "same"
		? plugin.sameMajorLatest
		: mode === "release"
			? plugin.releaseLatest
			: plugin.overallLatest;
}

async function checkPlugin(plugin: PluginRow): Promise<void> {
	const baseVersion = resolveBaseVersion(plugin);
	if (!baseVersion) {
		updatePluginInState(plugin.name, {
			status: "error",
			error: "no active/installed version to compare",
		});
		addLog(`${plugin.name}: no base version found.`);
		return;
	}

	updatePluginInState(plugin.name, { status: "checking" });

	try {
		const result: PluginUpdateInfo = await rpc.request.checkPluginUpdates({
			plugin: plugin.name,
			baseVersion,
			includeChannels: false,
		});
		updatePluginInState(plugin.name, {
			sameMajorLatest: result.sameMajorLatest,
			releaseLatest: result.releaseLatest,
			overallLatest: result.overallLatest,
			checkedVersions: result.checkedVersions,
			status: result.error ? "error" : "done",
			error: result.error,
		});
		if (result.error) {
			addLog(`${plugin.name}: ${result.error}`);
		} else {
			addLog(`${plugin.name}: checked ${result.checkedVersions} version(s), base=${baseVersion}.`);
		}
	} catch (error) {
		updatePluginInState(plugin.name, { status: "error", error: (error as Error).message });
		addLog(`${plugin.name}: ${(error as Error).message}`);
	}
}

export async function checkUpdates(): Promise<void> {
	if (state.busy || state.plugins.length === 0) {
		return;
	}

	setBusy(true, "Checking updates", 0);
	state.plugins = state.plugins.map((plugin) => ({ ...plugin, status: "idle", error: undefined }));

	let processed = 0;
	const total = state.plugins.length;
	const queue = [...state.plugins];
	const concurrency = Math.min(4, total);

	const workers = Array.from({ length: concurrency }, async () => {
		while (true) {
			const plugin = queue.shift();
			if (!plugin) {
				return;
			}
			setBusy(true, `Checking ${plugin.name}`, (processed / total) * 100);
			await checkPlugin(plugin);
			processed += 1;
			setBusy(true, `Checking ${plugin.name}`, (processed / total) * 100);
		}
	});
	await Promise.all(workers);

	setBusy(false, "Check complete", 100);
}

/** One-shot load + check when the Overview/Updater surface is first shown. */
export function ensureUpdaterData(): void {
	if (state.updaterAutoChecked) {
		return;
	}
	state.updaterAutoChecked = true;
	void (async () => {
		if (state.plugins.length === 0) {
			await reloadPlugins();
		}
		await checkUpdates();
	})();
}

export async function retryCheck(pluginName: string): Promise<void> {
	if (state.busy) {
		return;
	}
	const plugin = state.plugins.find((entry) => entry.name === pluginName);
	if (!plugin) {
		return;
	}
	setBusy(true, `Checking ${pluginName}`);
	await checkPlugin(plugin);
	setBusy(false, "Check complete");
}

/** Overview "Update to X": install then switch global. The old version stays installed. */
export async function updateToVersion(pluginName: string, targetVersion: string): Promise<void> {
	if (state.busy) {
		return;
	}
	setBusy(true, `Updating ${pluginName}@${targetVersion}`);
	updatePluginInState(pluginName, { status: "updating" });

	try {
		await rpc.request.installPlugin({ plugin: pluginName, targetVersion });
	} catch (error) {
		updatePluginInState(pluginName, { status: "error", error: (error as Error).message });
		addLog(`${pluginName}: install failed - ${(error as Error).message}`);
		setBusy(false);
		return;
	}

	try {
		await rpc.request.useGlobalPlugin({ plugin: pluginName, targetVersion });
		await refreshPlugin(pluginName);
		updatePluginInState(pluginName, { status: "done", error: undefined });
		addLog(`${pluginName}: updated to ${targetVersion} (installed + switched global).`);
	} catch (error) {
		await refreshPlugin(pluginName).catch(() => {});
		updatePluginInState(pluginName, { status: "error", error: (error as Error).message });
		addLog(`${pluginName}: installed ${targetVersion} but switching global failed - ${(error as Error).message}`);
	}
	setBusy(false);
}

export function requestMajorUpdate(pluginName: string, targetVersion: string): void {
	const plugin = state.plugins.find((entry) => entry.name === pluginName);
	state.pendingMajorUpdate = {
		pluginName,
		fromVersion: plugin?.activeGlobalVersion ?? null,
		targetVersion,
	};
}

export async function confirmMajorUpdate(): Promise<void> {
	if (!state.pendingMajorUpdate || state.busy) {
		return;
	}
	const { pluginName, targetVersion } = state.pendingMajorUpdate;
	state.pendingMajorUpdate = null;
	await updateToVersion(pluginName, targetVersion);
}

export async function runTargetAction(
	pluginName: string,
	mode: "same" | "release" | "latest",
	actionType: "install" | "use",
): Promise<void> {
	if (state.busy) {
		return;
	}
	const plugin = state.plugins.find((entry) => entry.name === pluginName);
	if (!plugin) {
		return;
	}

	const target = getTargetVersion(plugin, mode);
	if (!target) {
		addLog(`${pluginName}: target not found for ${mode}.`);
		return;
	}

	setBusy(true, `${actionType === "install" ? "Installing" : "Using"} ${pluginName}@${target}`);
	updatePluginInState(pluginName, { status: "updating" });

	try {
		if (actionType === "install") {
			await rpc.request.installPlugin({ plugin: pluginName, targetVersion: target });
			await refreshPlugin(pluginName);
			updatePluginInState(pluginName, { status: "done", error: undefined });
			addLog(`${pluginName}: installed ${target}.`);
		} else {
			await rpc.request.useGlobalPlugin({ plugin: pluginName, targetVersion: target });
			await refreshPlugin(pluginName);
			updatePluginInState(pluginName, { status: "done", error: undefined });
			addLog(`${pluginName}: now using global ${target}.`);
		}
	} catch (error) {
		updatePluginInState(pluginName, { status: "error", error: (error as Error).message });
		addLog(`${pluginName}: action failed - ${(error as Error).message}`);
	}

	setBusy(false);
}

export async function useInstalledVersion(
	pluginName: string,
	version: string,
): Promise<void> {
	if (state.busy) {
		return;
	}
	setBusy(true, `Using ${pluginName}@${version}`);
	updatePluginInState(pluginName, { status: "updating" });
	try {
		await rpc.request.useGlobalPlugin({ plugin: pluginName, targetVersion: version });
		await refreshPlugin(pluginName);
		updatePluginInState(pluginName, { status: "done", error: undefined });
		addLog(`${pluginName}: switched global version to ${version}.`);
	} catch (error) {
		updatePluginInState(pluginName, { status: "error", error: (error as Error).message });
		addLog(`${pluginName}: use failed - ${(error as Error).message}`);
	}
	setBusy(false);
}

export async function deleteInstalledVersion(
	pluginName: string,
	version: string,
): Promise<void> {
	if (state.busy) {
		return;
	}
	const plugin = state.plugins.find((entry) => entry.name === pluginName);
	if (!plugin || plugin.activeGlobalVersion === version) {
		addLog(`${pluginName}: cannot delete active global version ${version}.`);
		return;
	}

	updatePluginInState(pluginName, { status: "deleting" });
	try {
		await rpc.request.deletePluginVersion({ plugin: pluginName, targetVersion: version });
		await refreshPlugin(pluginName);
		updatePluginInState(pluginName, { status: "done", error: undefined });
		addLog(`${pluginName}: deleted ${version}.`);
	} catch (error) {
		updatePluginInState(pluginName, { status: "error", error: (error as Error).message });
		addLog(`${pluginName}: delete failed - ${(error as Error).message}`);
	}
	setBusy(false);
}

export async function confirmDeleteInstalledVersion(): Promise<void> {
	if (!state.pendingDelete || state.busy) {
		return;
	}

	const { pluginName, version } = state.pendingDelete;
	state.pendingDelete = null;
	await deleteInstalledVersion(pluginName, version);
}
