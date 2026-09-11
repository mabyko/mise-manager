import { state } from "./state.svelte";
import type { PluginRow } from "./types";
import type { PluginSummary } from "../../shared/contracts";
import { sortVersionsDesc } from "./utils";

export function buildInstallCatalog(): string[] {
	return [
		...new Set([
			...state.remotePluginNames,
			...state.installedPluginNames,
			...state.corePluginNames,
			...state.installedToolNames,
		]),
	].sort((a, b) => a.localeCompare(b));
}

export function normalizeInstalled(plugin: PluginRow): PluginRow {
	const unique = [...new Set(plugin.installedVersions)];
	return {
		...plugin,
		installedVersions: sortVersionsDesc(unique),
	};
}

export function updatePluginInState(pluginName: string, patch: Partial<PluginRow>): void {
	state.plugins = state.plugins.map((plugin) =>
		plugin.name === pluginName ? normalizeInstalled({ ...plugin, ...patch }) : plugin,
	);
}

export function resolveBaseVersion(plugin: PluginRow): string | null {
	return plugin.activeGlobalVersion ?? plugin.installedVersions.at(0) ?? null;
}

export function toPluginRow(summary: PluginSummary): PluginRow {
	return {
		...summary,
		latestByMajor: {},
		sameMajorLatest: null,
		releaseLatest: null,
		overallLatest: null,
		checkedVersions: 0,
		status: "idle",
	};
}
