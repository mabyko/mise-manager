import type { PluginUpdateInfo } from "../../shared/contracts";
import { rpc } from "../core/rpc";
import { state, setBusy } from "../core/state";
import type { PluginRow } from "../core/types";
import { escapeHtml } from "../core/utils";
import { resolveBaseVersion, updatePluginInState } from "../core/helpers";
import { addLog } from "./logs";
import { refreshPlugin } from "../core/app";

function formatVersionBadge(value: string | null, current: string | null): string {
	if (!value) {
		return `<span class="badge empty">N/A</span>`;
	}
	if (value === current) {
		return `<span class="badge same">${escapeHtml(value)}</span>`;
	}
	return `<span class="badge newer">${escapeHtml(value)}</span>`;
}

function getTargetVersion(
	plugin: PluginRow,
	mode: "same" | "release" | "latest",
): string | null {
	return mode === "same"
		? plugin.sameMajorLatest
		: mode === "release"
			? plugin.releaseLatest
			: plugin.overallLatest;
}

function renderTargetCell(
	plugin: PluginRow,
	target: string | null,
	mode: "same" | "release" | "latest",
): string {
	if (!target) {
		return `
			<div class="target-cell">
				<span class="badge empty">N/A</span>
				<div class="version-meta">${mode === "latest" ? "No pre-release found" : "No version found"}</div>
			</div>
		`;
	}

	const isCurrent = target === plugin.activeGlobalVersion;
	const baseVersion = resolveBaseVersion(plugin);
	const alreadyInstalled = plugin.installedVersions.includes(target);
	const isBaseSame = target === baseVersion;
	const disableInstall = state.busy || alreadyInstalled || isBaseSame;
	const installAction = mode === "same" ? "install-same" : mode === "release" ? "install-release" : "install-latest";

	return `
		<div class="target-cell">
			<div class="target-top">
				${formatVersionBadge(target, plugin.activeGlobalVersion)}
				<span class="version-state ${isCurrent ? "state-current" : alreadyInstalled ? "state-installed" : "state-new"}">${isCurrent ? "Using Global" : alreadyInstalled ? "Installed" : "NEW"}</span>
			</div>
			<div class="cell-actions">
				<button class="mini-btn" style="flex: 1;" data-action="${installAction}" data-plugin="${escapeHtml(plugin.name)}" ${disableInstall ? "disabled" : ""}>Install</button>
			</div>
		</div>
	`;
}

function renderInstalledVersions(plugin: PluginRow): string {
	if (plugin.installedVersions.length === 0) {
		return `<div class="version-meta">No installed versions</div>`;
	}

	return plugin.installedVersions
		.map((version) => {
			const isActive = version === plugin.activeGlobalVersion;
			return `
				<div class="installed-item">
					<span class="badge ${isActive ? "same" : "newer"}">${escapeHtml(version)}</span>
					<div class="cell-actions">
						<button class="mini-btn" data-action="use-installed" data-plugin="${escapeHtml(plugin.name)}" data-version="${escapeHtml(version)}" ${state.busy || isActive ? "disabled" : ""}>Use Global</button>
						<button class="mini-btn danger" data-action="delete-installed" data-plugin="${escapeHtml(plugin.name)}" data-version="${escapeHtml(version)}" ${state.busy || isActive ? "disabled" : ""}>Delete</button>
					</div>
				</div>
			`;
		})
		.join("");
}

export function renderUpdaterTab(): string {
	const rows = state.plugins
		.map((plugin) => {
			const statusClass = plugin.status === "error" ? "status-error" : plugin.status;
			return `
				<tr>
					<td class="plugin">
						<div>${escapeHtml(plugin.name)}</div>
					</td>
					<td>${renderInstalledVersions(plugin)}</td>
					<td>${formatVersionBadge(plugin.activeGlobalVersion, plugin.activeGlobalVersion)}</td>
					<td>${renderTargetCell(plugin, plugin.sameMajorLatest, "same")}</td>
					<td>${renderTargetCell(plugin, plugin.releaseLatest, "release")}</td>
					<td>${renderTargetCell(plugin, plugin.overallLatest, "latest")}</td>
					<td><span class="status ${statusClass}">${escapeHtml(plugin.status)}</span></td>
				</tr>
			`;
		})
		.join("");

	return `
		<section class="panel">
			<section class="table-wrap">
				<table>
					<thead>
						<tr>
							<th>Plugin</th>
							<th>Installed Versions</th>
							<th>Active (Global)</th>
							<th>Same Major Latest</th>
							<th>Release Latest</th>
							<th>Pre-release Latest</th>
							<th>Status</th>
						</tr>
					</thead>
					<tbody>
						${rows || `<tr><td colspan="7" class="empty-row">설치된 플러그인을 찾지 못했습니다.</td></tr>`}
					</tbody>
				</table>
			</section>
		</section>
	`;
}

export function renderDeleteDialog(): string {
	if (!state.pendingDelete) {
		return "";
	}

	return `
		<div class="modal-overlay">
			<div class="modal-card">
				<h3>Delete Installed Version</h3>
				<p>
					${escapeHtml(state.pendingDelete.pluginName)}@${escapeHtml(state.pendingDelete.version)} 를 삭제할까요?
					이 작업은 되돌릴 수 없습니다.
				</p>
				<div class="modal-actions">
					<button class="mini-btn" data-action="cancel-delete">Cancel</button>
					<button class="mini-btn danger" data-action="confirm-delete">Delete</button>
				</div>
			</div>
		</div>
	`;
}

export async function checkUpdates(render: () => void): Promise<void> {
	if (state.busy || state.plugins.length === 0) {
		return;
	}

	setBusy(true, "Checking updates", 0);
	state.plugins = state.plugins.map((plugin) => ({ ...plugin, status: "idle", error: undefined }));
	render();

	let processed = 0;
	const total = state.plugins.length;
	const queue = [...state.plugins];
	const concurrency = Math.min(4, total);

	const processOne = async (plugin: PluginRow): Promise<void> => {
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
		setBusy(true, `Checking ${plugin.name}`, (processed / total) * 100);
		render();

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
	};

	const workers = Array.from({ length: concurrency }, async () => {
		while (true) {
			const plugin = queue.shift();
			if (!plugin) {
				return;
			}
			await processOne(plugin);
			processed += 1;
			setBusy(true, `Checking ${plugin.name}`, (processed / total) * 100);
			render();
		}
	});
	await Promise.all(workers);

	setBusy(false, "Check complete", 100);
	render();
}

export async function runTargetAction(
	pluginName: string,
	mode: "same" | "release" | "latest",
	actionType: "install" | "use",
	render: () => void,
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
		render();
		return;
	}

	setBusy(true, `${actionType === "install" ? "Installing" : "Using"} ${pluginName}@${target}`, 30);
	updatePluginInState(pluginName, { status: "updating" });
	render();

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

	setBusy(false, "Ready", 0);
	render();
}

export async function useInstalledVersion(
	pluginName: string,
	version: string,
	render: () => void,
): Promise<void> {
	if (state.busy) {
		return;
	}
	setBusy(true, `Using ${pluginName}@${version}`, 40);
	updatePluginInState(pluginName, { status: "updating" });
	render();
	try {
		await rpc.request.useGlobalPlugin({ plugin: pluginName, targetVersion: version });
		await refreshPlugin(pluginName);
		updatePluginInState(pluginName, { status: "done", error: undefined });
		addLog(`${pluginName}: switched global version to ${version}.`);
	} catch (error) {
		updatePluginInState(pluginName, { status: "error", error: (error as Error).message });
		addLog(`${pluginName}: use failed - ${(error as Error).message}`);
	}
	setBusy(false, "Ready", 0);
	render();
}

export async function deleteInstalledVersion(
	pluginName: string,
	version: string,
	render: () => void,
): Promise<void> {
	if (state.busy) {
		return;
	}
	const plugin = state.plugins.find((entry) => entry.name === pluginName);
	if (!plugin || plugin.activeGlobalVersion === version) {
		addLog(`${pluginName}: cannot delete active global version ${version}.`);
		render();
		return;
	}

	setBusy(true, `Deleting ${pluginName}@${version}`, 40);
	updatePluginInState(pluginName, { status: "updating" });
	render();
	try {
		await rpc.request.deletePluginVersion({ plugin: pluginName, targetVersion: version });
		await refreshPlugin(pluginName);
		updatePluginInState(pluginName, { status: "done", error: undefined });
		addLog(`${pluginName}: deleted ${version}.`);
	} catch (error) {
		updatePluginInState(pluginName, { status: "error", error: (error as Error).message });
		addLog(`${pluginName}: delete failed - ${(error as Error).message}`);
	}
	setBusy(false, "Ready", 0);
	render();
}

export async function confirmDeleteInstalledVersion(render: () => void): Promise<void> {
	if (!state.pendingDelete || state.busy) {
		return;
	}

	const { pluginName, version } = state.pendingDelete;
	state.pendingDelete = null;
	render();
	await deleteInstalledVersion(pluginName, version, render);
}
