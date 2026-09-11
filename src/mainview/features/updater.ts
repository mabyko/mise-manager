import { rpc } from "../core/rpc";
import { state, setBusy } from "../core/state.svelte";
import type { PluginRow } from "../core/types";
import {
	normalizeInstalled,
	resolveBaseVersion,
	toPluginRow,
	updatePluginInState,
} from "../core/helpers";
import { addLog } from "./logs";
import { getInstalledSeries } from "../core/toolStatus";
import { getMajor } from "../../shared/version";
import { settings } from "../core/settings.svelte";

// ---- tool list -------------------------------------------------------------

/** Reloads the tool list from mise. Resolves false (with toolsError set) when mise could not be read. */
async function loadPlugins(): Promise<boolean> {
	setBusy(true, "Loading plugins");
	state.toolsCheckedAt = null;
	state.toolsError = null;
	try {
		const installed = await rpc.request.listInstalledPlugins();
		state.plugins = installed.map(toPluginRow).map(normalizeInstalled);
		addLog(`Loaded ${state.plugins.length} plugin(s).`);
		setBusy(false);
		return true;
	} catch (error) {
		state.toolsError = (error as Error).message;
		addLog(`Failed to load plugins: ${state.toolsError}`);
		setBusy(false, "Load failed");
		return false;
	} finally {
		state.toolsLoaded = true;
	}
}

/**
 * Re-reads one row's versions from mise. Returns the fresh row, or undefined
 * when mise no longer lists the tool (the row is dropped from the table).
 */
async function refreshPlugin(pluginName: string): Promise<PluginRow | undefined> {
	const found = (await rpc.request.listInstalledPlugins()).find((entry) => entry.name === pluginName);
	if (!found) {
		state.plugins = state.plugins.filter((plugin) => plugin.name !== pluginName);
		addLog(`${pluginName}: no longer listed by mise; removed from the list.`);
		return undefined;
	}
	updatePluginInState(pluginName, {
		activeGlobalVersion: found.activeGlobalVersion,
		installedVersions: found.installedVersions,
	});
	return state.plugins.find((entry) => entry.name === pluginName);
}

const baseMoved = (before: PluginRow, after: PluginRow) =>
	resolveBaseVersion(before) !== resolveBaseVersion(after);

const noCandidates = {
	latestByMajor: {},
	sameMajorLatest: null,
	releaseLatest: null,
	overallLatest: null,
	checkedVersions: 0,
} satisfies Partial<PluginRow>;

// ---- update checks ---------------------------------------------------------

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
		const result = await rpc.request.checkPluginUpdates({
			plugin: plugin.name,
			baseVersion,
			includeChannels: false,
		});
		updatePluginInState(plugin.name, {
			latestByMajor: result.latestByMajor ?? {},
			sameMajorLatest: result.sameMajorLatest,
			releaseLatest: result.releaseLatest,
			overallLatest: result.overallLatest,
			checkedVersions: result.checkedVersions,
			status: result.error ? "error" : "done",
			error: result.error,
		});
		addLog(
			result.error
				? `${plugin.name}: ${result.error}`
				: `${plugin.name}: checked ${result.checkedVersions} version(s), base=${baseVersion}.`,
		);
	} catch (error) {
		updatePluginInState(plugin.name, { status: "error", error: (error as Error).message });
		addLog(`${plugin.name}: ${(error as Error).message}`);
	}
}

export async function checkUpdates(): Promise<void> {
	if (state.busy || !state.plugins.length) return;

	setBusy(true, "Checking updates", 0);
	state.plugins = state.plugins.map((plugin) => ({ ...plugin, status: "idle", error: undefined }));

	const queue = [...state.plugins];
	const total = queue.length;
	let processed = 0;
	await Promise.all(
		Array.from({ length: Math.min(4, total) }, async () => {
			for (let plugin = queue.shift(); plugin; plugin = queue.shift()) {
				setBusy(true, `Checking ${plugin.name}`, (processed / total) * 100);
				await checkPlugin(plugin);
				processed += 1;
				setBusy(true, `Checking ${plugin.name}`, (processed / total) * 100);
			}
		}),
	);

	state.toolsCheckedAt = new Date().toLocaleString("ko-KR", { hour12: false });
	setBusy(false, "Check complete", 100);
}

/** Full refresh: reload the tool list, then check every tool. Safe to await from app start-up. */
export async function reloadAndCheckTools(check = true): Promise<void> {
	if (state.busy) return;
	if (await loadPlugins() && check) await checkUpdates();
}

/** Row-level retry: reconcile the row's versions from mise first (an earlier refresh may have failed), then check it. */
export async function retryCheck(pluginName: string): Promise<void> {
	if (state.busy || !state.plugins.some((entry) => entry.name === pluginName)) return;
	setBusy(true, `Checking ${pluginName}`);
	updatePluginInState(pluginName, { status: "checking" });
	try {
		const row = await refreshPlugin(pluginName);
		if (row) await checkPlugin(row);
	} catch (error) {
		const message = `refresh failed - ${(error as Error).message}`;
		updatePluginInState(pluginName, { status: "error", error: message });
		addLog(`${pluginName}: ${message}`);
	} finally {
		setBusy(false, "Check complete");
	}
}

// ---- version actions -------------------------------------------------------

/**
 * Candidates (sameMajorLatest etc.) are only meaningful for the base version
 * they were checked against. After a successful mutation a row that was
 * verified before and whose base did not move is done as it is; anything else
 * (global switched 22.x -> 20.x, or the previous check had failed) is checked
 * again so a cached 22.15 is never offered as a same-major update for 20.x.
 */
async function settlePlugin(before: PluginRow, row: PluginRow): Promise<void> {
	if (before.status === "done" && !baseMoved(before, row)) {
		updatePluginInState(row.name, { status: "done", error: undefined });
	} else {
		await checkPlugin(row);
	}
}

/**
 * One mise mutation on a tool: busy span, row status, then the row is re-read
 * from mise whether or not the command succeeded, so whatever mise actually did
 * (e.g. installed but not switched) is what the table shows. Failures land on
 * the row and in the log; callers need no error handling of their own.
 */
async function runToolAction(
	pluginName: string,
	status: "updating" | "deleting",
	label: string,
	action: () => Promise<unknown>,
	okLog: string,
	failLog: string | (() => string),
): Promise<void> {
	const before = state.plugins.find((entry) => entry.name === pluginName);
	if (state.busy || state.updateCheckRunning || !before) return;
	setBusy(true, label);
	updatePluginInState(pluginName, { status });
	try {
		try {
			await action();
		} catch (error) {
			// Best effort re-read; the command error is what matters. A base that
			// moved anyway (partially applied command) must not keep stale candidates.
			const row = await refreshPlugin(pluginName).catch(() => undefined);
			if (row && baseMoved(before, row)) updatePluginInState(pluginName, noCandidates);
			updatePluginInState(pluginName, { status: "error", error: (error as Error).message });
			const reason = typeof failLog === "function" ? failLog() : failLog;
			addLog(`${pluginName}: ${reason} - ${(error as Error).message}`);
			return;
		}
		addLog(`${pluginName}: ${okLog}`);
		try {
			const row = await refreshPlugin(pluginName);
			if (row) await settlePlugin(before, row);
		} catch (error) {
			// The command itself succeeded; only the re-read failed. Say so instead of blaming the command.
			const message = `refresh failed after success - ${(error as Error).message}`;
			updatePluginInState(pluginName, { status: "error", error: message });
			addLog(`${pluginName}: ${message}`);
		}
	} finally {
		setBusy(false);
	}
}

export function installVersion(pluginName: string, version: string): Promise<void> {
	return runToolAction(
		pluginName,
		"updating",
		`Installing ${pluginName}@${version}`,
		() => rpc.request.installPlugin({ plugin: pluginName, targetVersion: version }),
		`installed ${version}.`,
		"install failed",
	);
}

export function seriesUpdateSwitchesGlobal(plugin: PluginRow, version: string): boolean {
	return settings.switchGlobalAfterUpdate && plugin.activeGlobalVersion !== null
		&& getMajor(plugin.activeGlobalVersion) === getMajor(version);
}

export async function updateInstalledSeries(pluginName: string, version: string): Promise<void> {
	const plugin = state.plugins.find(entry => entry.name === pluginName);
	if (state.busy || !plugin || !getInstalledSeries(plugin).some(series => series.update === version)) return;
	if (seriesUpdateSwitchesGlobal(plugin, version)) await updateToVersion(pluginName, version);
	else await installVersion(pluginName, version);
}

export function useInstalledVersion(pluginName: string, version: string): Promise<void> {
	return runToolAction(
		pluginName,
		"updating",
		`Using ${pluginName}@${version}`,
		() => rpc.request.useGlobalPlugin({ plugin: pluginName, targetVersion: version }),
		`switched global version to ${version}.`,
		"use failed",
	);
}

/** "Update to X": install then switch global. The old version stays installed. */
export async function updateToVersion(pluginName: string, targetVersion: string): Promise<void> {
	const spec = { plugin: pluginName, targetVersion };
	let failLog = "install failed";
	await runToolAction(
		pluginName,
		"updating",
		`Updating ${pluginName}@${targetVersion}`,
		async () => {
			await rpc.request.installPlugin(spec);
			failLog = `installed ${targetVersion} but switching global failed`;
			await rpc.request.useGlobalPlugin(spec);
		},
		`updated to ${targetVersion} (installed + switched global).`,
		() => failLog,
	);
}

export async function deleteInstalledVersion(pluginName: string, version: string): Promise<void> {
	const plugin = state.plugins.find((entry) => entry.name === pluginName);
	if (state.busy) return;
	if (!plugin || plugin.activeGlobalVersion === version) {
		addLog(`${pluginName}: cannot delete active global version ${version}.`);
		return;
	}
	await runToolAction(
		pluginName,
		"deleting",
		`Deleting ${pluginName}@${version}`,
		() => rpc.request.deletePluginVersion({ plugin: pluginName, targetVersion: version }),
		`deleted ${version}.`,
		"delete failed",
	);
}

// ---- confirm dialogs -------------------------------------------------------

export function requestMajorUpdate(pluginName: string, targetVersion: string): void {
	const plugin = state.plugins.find((entry) => entry.name === pluginName);
	state.pendingMajorUpdate = {
		pluginName,
		fromVersion: plugin?.activeGlobalVersion ?? null,
		targetVersion,
	};
}

export async function confirmMajorUpdate(): Promise<void> {
	if (!state.pendingMajorUpdate || state.busy) return;
	const { pluginName, targetVersion } = state.pendingMajorUpdate;
	state.pendingMajorUpdate = null;
	await updateToVersion(pluginName, targetVersion);
}

export async function confirmDeleteInstalledVersion(): Promise<void> {
	if (!state.pendingDelete || state.busy) return;
	const { pluginName, version } = state.pendingDelete;
	state.pendingDelete = null;
	await deleteInstalledVersion(pluginName, version);
}
