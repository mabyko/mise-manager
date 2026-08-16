import type { PluginDefinitionInfo } from "../../shared/contracts";
import { rpc } from "../core/rpc";
import { state, setBusy } from "../core/state.svelte";
import type { MainViewState } from "../core/types";
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

export type PluginInstallPlan =
	| { kind: "invalid"; log: string }
	| { kind: "skip"; log: string }
	| {
			kind: "install";
			plugin: string;
			gitUrl?: string;
			force: boolean;
			removeToolAlias: boolean;
	  };

// Pure decision core of the plugin URL dialog: what to send to mise, or why
// not. "invalid" keeps the dialog open; "skip" closes it without installing.
export function resolvePluginInstallPlan(input: {
	dialog: NonNullable<MainViewState["pendingPluginUrlDialog"]>;
	nameValue: string;
	urlValue: string;
	installedUserPluginInfos: PluginDefinitionInfo[];
	remotePluginInfos: PluginDefinitionInfo[];
}): PluginInstallPlan {
	const rawGitUrl = input.urlValue.trim();
	const gitUrl = normalizePluginInstallUrl(rawGitUrl);

	if (input.dialog.mode === "custom-install") {
		const pluginName = input.nameValue.trim();
		if (pluginName.length === 0) {
			return { kind: "invalid", log: "Custom plugin: plugin name required." };
		}
		if (!/^[A-Za-z0-9._-]+$/.test(pluginName)) {
			return {
				kind: "invalid",
				log: `${pluginName}: plugin name can only contain letters, numbers, dot, underscore, dash.`,
			};
		}
		if (gitUrl.length === 0) {
			return {
				kind: "invalid",
				log: `${pluginName}: Git URL is required for custom plugin install.`,
			};
		}
		return { kind: "install", plugin: pluginName, gitUrl, force: false, removeToolAlias: false };
	}

	if (input.dialog.mode === "edit" && rawGitUrl.length === 0) {
		return { kind: "invalid", log: `${input.dialog.pluginName}: URL is required for edit.` };
	}

	let nextGitUrl: string | undefined = gitUrl.length > 0 ? gitUrl : undefined;
	let removeToolAlias = false;

	if (input.dialog.mode === "edit") {
		const userInfo = findUserPluginInfo(
			input.dialog.pluginName,
			input.installedUserPluginInfos,
		);
		const nextIsDefault = isDefaultPluginUrl(
			input.dialog.pluginName,
			nextGitUrl,
			input.remotePluginInfos,
		);
		if (nextIsDefault) {
			nextGitUrl = undefined;
			removeToolAlias = userInfo?.source === "tool_alias";
		}
		if (!removeToolAlias && (userInfo?.url ?? "").trim() === rawGitUrl) {
			return {
				kind: "skip",
				log: `${input.dialog.pluginName}: URL unchanged; plugin update skipped.`,
			};
		}
	}

	return {
		kind: "install",
		plugin: input.dialog.pluginName,
		gitUrl: nextGitUrl,
		force: input.dialog.mode === "edit",
		removeToolAlias,
	};
}

export async function submitPluginUrlDialog(): Promise<void> {
	if (!state.pendingPluginUrlDialog || state.busy) {
		return;
	}

	const plan = resolvePluginInstallPlan({
		dialog: state.pendingPluginUrlDialog,
		nameValue: state.pendingPluginNameValue,
		urlValue: state.pendingPluginUrlValue,
		installedUserPluginInfos: state.installedUserPluginInfos,
		remotePluginInfos: state.remotePluginInfos,
	});

	if (plan.kind === "invalid") {
		addLog(plan.log);
		return;
	}

	closePluginUrlDialog();
	if (plan.kind === "skip") {
		addLog(plan.log);
		return;
	}
	await installPluginDefinition(plan.plugin, plan.gitUrl, plan.force, plan.removeToolAlias);
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
