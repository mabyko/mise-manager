import { rpc } from "../core/rpc";
import { state, setBusy } from "../core/state.svelte";
import {
	findUserPluginInfo,
	isDefaultPluginUrl,
	normalizePluginInstallUrl,
} from "../core/utils";
import { addLog } from "./logs";

export async function reloadPluginDefinitions(): Promise<void> {
	setBusy(true, "Loading plugin definitions", 10);
	try {
		const [userPluginInfos, corePlugins, installedTools, remoteInfos] = await Promise.all([
			rpc.request.listInstalledUserPluginInfos(),
			rpc.request.listCorePluginNames(),
			rpc.request.listInstalledToolNames(),
			rpc.request.listRemotePluginInfos(),
		]);
		state.installedUserPluginInfos = userPluginInfos;
		state.installedPluginNames = userPluginInfos.map((entry) => entry.name);
		state.corePluginNames = corePlugins;
		state.installedToolNames = installedTools;
		state.remotePluginInfos = remoteInfos;
		state.remotePluginNames = [...new Set(remoteInfos.map((entry) => entry.name))].sort((a, b) =>
			a.localeCompare(b),
		);
		state.installsLoaded = true;
		addLog(`Loaded install sources: remotePlugins=${state.remotePluginNames.length}, userPlugins=${state.installedPluginNames.length}, corePlugins=${state.corePluginNames.length}, installedTools=${state.installedToolNames.length}.`);
		setBusy(false, "Ready", 0);
	} catch (error) {
		addLog(`Failed to load plugin definitions: ${(error as Error).message}`);
		setBusy(false, "Load failed", 0);
	}
}

export async function installPluginDefinition(
	plugin: string,
	gitUrl?: string,
	force = false,
	removeToolAlias = false,
): Promise<void> {
	if (state.busy) {
		return;
	}
	setBusy(true, `${force ? "Updating" : "Installing"} plugin ${plugin}`, 40);
	try {
		const result = await rpc.request.installPluginDefinition({
			plugin,
			gitUrl,
			force,
			...(removeToolAlias ? { removeToolAlias: true } : {}),
		});
		await reloadPluginDefinitions();
		const urlText = gitUrl && gitUrl.trim().length > 0 ? ` (${gitUrl.trim()})` : "";
		addLog(`${plugin}: plugin ${force ? "updated" : "installed"}${urlText}.`);
		if (
			result.stdout.includes("Updated tool_alias") ||
			result.stdout.includes("Removed tool_alias")
		) {
			addLog(`${plugin}: ${result.stdout.split("\n").at(-1) ?? ""}`);
		}
	} catch (error) {
		const actionLabel = force ? "Update" : "Install";
		addLog(`${plugin}: plugin ${force ? "update" : "install"} failed - ${(error as Error).message}`);
		setBusy(false, `${actionLabel} failed: ${plugin}`, 0);
	}
}

export function openInstallPluginDialog(plugin: string): void {
	state.pendingPluginUrlDialog = { mode: "install", pluginName: plugin };
	state.pendingPluginNameValue = "";
	state.pendingPluginUrlValue = "";
}

export function openCustomPluginDialog(): void {
	state.pendingPluginUrlDialog = { mode: "custom-install" };
	state.pendingPluginNameValue = "";
	state.pendingPluginUrlValue = "";
}

export function openEditPluginDialog(plugin: string): void {
	const userInfo = findUserPluginInfo(plugin, state.installedUserPluginInfos);
	if (!userInfo) {
		addLog(`${plugin}: cannot edit URL because user plugin is not installed.`);
		return;
	}
	state.pendingPluginUrlDialog = { mode: "edit", pluginName: plugin };
	state.pendingPluginNameValue = "";
	state.pendingPluginUrlValue = userInfo.url ?? "";
}

export function closePluginUrlDialog(): void {
	state.pendingPluginUrlDialog = null;
	state.pendingPluginNameValue = "";
	state.pendingPluginUrlValue = "";
}

export async function submitPluginUrlDialog(): Promise<void> {
	if (!state.pendingPluginUrlDialog || state.busy) {
		return;
	}

	const dialog = state.pendingPluginUrlDialog;
	const rawGitUrl = state.pendingPluginUrlValue.trim();
	const gitUrl = normalizePluginInstallUrl(rawGitUrl);

	if (dialog.mode === "custom-install") {
		const pluginName = state.pendingPluginNameValue.trim();
		if (pluginName.length === 0) {
			addLog("Custom plugin: plugin name required.");
			return;
		}
		if (!/^[A-Za-z0-9._-]+$/.test(pluginName)) {
			addLog(`${pluginName}: plugin name can only contain letters, numbers, dot, underscore, dash.`);
			return;
		}
		if (gitUrl.length === 0) {
			addLog(`${pluginName}: Git URL is required for custom plugin install.`);
			return;
		}
		closePluginUrlDialog();
		await installPluginDefinition(pluginName, gitUrl);
		return;
	}

	if (dialog.mode === "edit" && rawGitUrl.length === 0) {
		addLog(`${dialog.pluginName}: URL is required for edit.`);
		return;
	}

	let nextGitUrl: string | undefined = gitUrl.length > 0 ? gitUrl : undefined;
	let removeToolAlias = false;

	if (dialog.mode === "edit") {
		const userInfo = findUserPluginInfo(
			dialog.pluginName,
			state.installedUserPluginInfos,
		);
		const nextIsDefault = isDefaultPluginUrl(
			dialog.pluginName,
			nextGitUrl,
			state.remotePluginInfos,
		);
		if (nextIsDefault) {
			nextGitUrl = undefined;
			removeToolAlias = userInfo?.source === "tool_alias";
		}
		if (!removeToolAlias && (userInfo?.url ?? "").trim() === rawGitUrl) {
			closePluginUrlDialog();
			addLog(`${dialog.pluginName}: URL unchanged; plugin update skipped.`);
			return;
		}
	}

	closePluginUrlDialog();
	await installPluginDefinition(
		dialog.pluginName,
		nextGitUrl,
		dialog.mode === "edit",
		removeToolAlias,
	);
}

export async function uninstallPluginDefinition(plugin: string): Promise<void> {
	if (state.busy) {
		return;
	}
	setBusy(true, `Removing plugin ${plugin}`, 40);
	try {
		await rpc.request.uninstallPluginDefinition({ plugin });
		await reloadPluginDefinitions();
		addLog(`${plugin}: plugin removed.`);
	} catch (error) {
		addLog(`${plugin}: plugin remove failed - ${(error as Error).message}`);
		setBusy(false, "Ready", 0);
	}
}
