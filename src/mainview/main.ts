import { Electroview } from "electrobun/view";

import type {
	AppRPC,
	PluginStatus,
	PluginSummary,
	PluginUpdateInfo,
} from "../shared/contracts";
import { compareVersions } from "../shared/version";
import "./style.css";

interface PluginRow extends PluginSummary {
	sameMajorLatest: string | null;
	releaseLatest: string | null;
	overallLatest: string | null;
	checkedVersions: number;
	status: PluginStatus;
	error?: string;
}

const rpc = Electroview.defineRPC<AppRPC>({
	maxRequestTime: 1000 * 60 * 20,
	handlers: { requests: {} },
});
new Electroview({ rpc });
const app = document.getElementById("app");

if (!app) {
	throw new Error("app container not found");
}
const appRoot = app;

let activeTab: "updater" | "logs" | "extensions" = "updater";
let plugins: PluginRow[] = [];
let logs: string[] = [];
let busy = false;
let progress = 0;
let progressLabel = "Ready";
let pendingDelete: { pluginName: string; version: string } | null = null;
const checkModeActiveOnly = true;

function nowLabel(): string {
	return new Date().toLocaleString("ko-KR", { hour12: false });
}

function addLog(message: string): void {
	logs = [`[${nowLabel()}] ${message}`, ...logs].slice(0, 150);
}

function escapeHtml(value: string): string {
	return value
		.replaceAll("&", "&amp;")
		.replaceAll("<", "&lt;")
		.replaceAll(">", "&gt;")
		.replaceAll('"', "&quot;")
		.replaceAll("'", "&#39;");
}

function setBusy(nextBusy: boolean, nextLabel = "Ready", nextProgress = 0): void {
	busy = nextBusy;
	progressLabel = nextLabel;
	progress = nextProgress;
}

function sortVersionsDesc(versions: string[]): string[] {
	return [...versions].sort((a, b) => compareVersions(b, a));
}

function normalizeInstalled(plugin: PluginRow): PluginRow {
	const unique = [...new Set(plugin.installedVersions)];
	return {
		...plugin,
		installedVersions: sortVersionsDesc(unique),
	};
}

function updatePluginInState(pluginName: string, patch: Partial<PluginRow>): void {
	plugins = plugins.map((plugin) =>
		plugin.name === pluginName ? normalizeInstalled({ ...plugin, ...patch }) : plugin,
	);
}

async function refreshPlugin(pluginName: string): Promise<void> {
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

function resolveBaseVersion(plugin: PluginRow): string | null {
	if (checkModeActiveOnly) {
		return plugin.activeGlobalVersion ?? plugin.installedVersions.at(0) ?? null;
	}
	return plugin.installedVersions.at(0) ?? plugin.activeGlobalVersion;
}

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
	const disableInstall = busy || alreadyInstalled || isBaseSame;
	const installAction = mode === "same" ? "install-same" : mode === "release" ? "install-release" : "install-latest";
	const useAction = mode === "same" ? "use-same" : mode === "release" ? "use-release" : "use-latest";

	return `
		<div class="target-cell">
			<div class="target-top">
				${formatVersionBadge(target, plugin.activeGlobalVersion)}
				<span class="version-state ${isCurrent ? "state-current" : alreadyInstalled ? "state-installed" : "state-new"}">${isCurrent ? "Using Global" : alreadyInstalled ? "Installed" : "NEW"}</span>
			</div>
			<div class="cell-actions">
				<button class="mini-btn" data-action="${installAction}" data-plugin="${escapeHtml(plugin.name)}" ${disableInstall ? "disabled" : ""}>Install</button>
				<button class="mini-btn" data-action="${useAction}" data-plugin="${escapeHtml(plugin.name)}" ${busy || isCurrent ? "disabled" : ""}>Use Global</button>
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
						<button class="mini-btn" data-action="use-installed" data-plugin="${escapeHtml(plugin.name)}" data-version="${escapeHtml(version)}" ${busy || isActive ? "disabled" : ""}>Use Global</button>
						<button class="mini-btn danger" data-action="delete-installed" data-plugin="${escapeHtml(plugin.name)}" data-version="${escapeHtml(version)}" ${busy || isActive ? "disabled" : ""}>Delete</button>
					</div>
				</div>
			`;
		})
		.join("");
}

function renderUpdaterTab(): string {
	const rows = plugins
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
			<header class="panel-header">
				<div>
					<h1>Mise Plugins Updater</h1>
					<p>Active(Global), Installed 버전, 업데이트 후보를 한 화면에서 관리합니다.</p>
				</div>
				<div class="header-actions">
					<button data-action="reload" ${busy ? "disabled" : ""}>Reload Plugins</button>
					<button data-action="check-updates" ${busy || plugins.length === 0 ? "disabled" : ""}>Check Updates</button>
				</div>
			</header>

			<section class="options-row">
				<span>검사 기준: 현재 전역(Active Global) 버전</span>
				<span>Pre-release Latest: 프리릴리즈가 있을 때만 표시</span>
			</section>

			<section class="progress-card">
				<div class="progress-head">
					<strong>${escapeHtml(progressLabel)}</strong>
					<span>${Math.round(progress)}%</span>
				</div>
				<div class="progress-track"><div class="progress-fill" style="width:${Math.max(0, Math.min(100, progress))}%"></div></div>
			</section>

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

function renderLogsTab(): string {
	return `
		<section class="panel">
			<header class="panel-header">
				<div>
					<h1>Logs</h1>
					<p>최근 작업 내역과 오류 메시지를 확인합니다.</p>
				</div>
				<div class="header-actions">
					<button data-action="clear-logs" ${busy ? "disabled" : ""}>Clear Logs</button>
				</div>
			</header>
			<section class="log-card">
				<pre>${escapeHtml(logs.join("\n") || "로그가 없습니다.")}</pre>
			</section>
		</section>
	`;
}

function renderDeleteDialog(): string {
	if (!pendingDelete) {
		return "";
	}

	return `
		<div class="modal-overlay">
			<div class="modal-card">
				<h3>Delete Installed Version</h3>
				<p>
					${escapeHtml(pendingDelete.pluginName)}@${escapeHtml(pendingDelete.version)} 를 삭제할까요?
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

function renderExtensionsTab(): string {
	return `
		<section class="panel placeholder">
			<h1>Plugins Installs</h1>
			<p>차기 단계에서 plugin 검색/설치/제거 기능을 추가할 예정입니다.</p>
		</section>
	`;
}

function render(): void {
	appRoot.innerHTML = `
		<main>
			<nav class="tabs">
				<button class="tab ${activeTab === "extensions" ? "active" : ""}" data-action="tab-extensions">Plugins Installs</button>
				<button class="tab ${activeTab === "updater" ? "active" : ""}" data-action="tab-updater">Plugins Updater</button>
				<button class="tab ${activeTab === "logs" ? "active" : ""}" data-action="tab-logs">Logs</button>
			</nav>
			${activeTab === "updater" ? renderUpdaterTab() : activeTab === "logs" ? renderLogsTab() : renderExtensionsTab()}
		</main>
		${renderDeleteDialog()}
	`;
}

function toPluginRow(summary: PluginSummary): PluginRow {
	return {
		...summary,
		sameMajorLatest: null,
		releaseLatest: null,
		overallLatest: null,
		checkedVersions: 0,
		status: "idle",
	};
}

async function reloadPlugins(): Promise<void> {
	setBusy(true, "Loading plugins", 5);
	render();
	try {
		const installed = await rpc.request.listInstalledPlugins();
		plugins = installed.map(toPluginRow).map(normalizeInstalled);
		addLog(`Loaded ${plugins.length} plugin(s).`);
		setBusy(false, "Ready", 0);
	} catch (error) {
		addLog(`Failed to load plugins: ${(error as Error).message}`);
		setBusy(false, "Load failed", 0);
	} finally {
		render();
	}
}

async function checkUpdates(): Promise<void> {
	if (busy || plugins.length === 0) {
		return;
	}

	setBusy(true, "Checking updates", 0);
	plugins = plugins.map((plugin) => ({ ...plugin, status: "idle", error: undefined }));
	render();

	let processed = 0;
	for (const plugin of plugins) {
		const baseVersion = resolveBaseVersion(plugin);
		if (!baseVersion) {
			updatePluginInState(plugin.name, {
				status: "error",
				error: "no active/installed version to compare",
			});
			processed += 1;
			addLog(`${plugin.name}: no base version found.`);
			setBusy(true, `Checking ${plugin.name}`, (processed / plugins.length) * 100);
			render();
			continue;
		}

		updatePluginInState(plugin.name, { status: "checking" });
		setBusy(true, `Checking ${plugin.name}`, (processed / plugins.length) * 100);
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

		processed += 1;
		setBusy(true, `Checking ${plugin.name}`, (processed / plugins.length) * 100);
		render();
	}

	setBusy(false, "Check complete", 100);
	render();
}

async function runTargetAction(
	pluginName: string,
	mode: "same" | "release" | "latest",
	actionType: "install" | "use",
): Promise<void> {
	if (busy) {
		return;
	}
	const plugin = plugins.find((entry) => entry.name === pluginName);
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

async function useInstalledVersion(pluginName: string, version: string): Promise<void> {
	if (busy) {
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

async function deleteInstalledVersion(pluginName: string, version: string): Promise<void> {
	if (busy) {
		return;
	}
	const plugin = plugins.find((entry) => entry.name === pluginName);
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

async function confirmDeleteInstalledVersion(): Promise<void> {
	if (!pendingDelete || busy) {
		return;
	}

	const { pluginName, version } = pendingDelete;
	pendingDelete = null;
	render();
	await deleteInstalledVersion(pluginName, version);
}

appRoot.addEventListener("click", (event) => {
	const target = event.target as HTMLElement;
	if (!(target instanceof HTMLButtonElement)) {
		return;
	}

	const action = target.dataset.action;
	if (!action) {
		return;
	}

	if (action === "tab-updater") {
		activeTab = "updater";
		render();
		return;
	}
	if (action === "tab-extensions") {
		activeTab = "extensions";
		render();
		return;
	}
	if (action === "tab-logs") {
		activeTab = "logs";
		render();
		return;
	}
	if (action === "reload") {
		void reloadPlugins();
		return;
	}
	if (action === "check-updates") {
		void checkUpdates();
		return;
	}
	if (action === "cancel-delete") {
		pendingDelete = null;
		render();
		return;
	}
	if (action === "confirm-delete") {
		void confirmDeleteInstalledVersion();
		return;
	}
	if (action === "clear-logs") {
		logs = [];
		render();
		return;
	}

	const plugin = target.dataset.plugin;
	if (!plugin) {
		return;
	}

	if (action === "install-same") {
		void runTargetAction(plugin, "same", "install");
		return;
	}
	if (action === "install-release") {
		void runTargetAction(plugin, "release", "install");
		return;
	}
	if (action === "install-latest") {
		void runTargetAction(plugin, "latest", "install");
		return;
	}
	if (action === "use-same") {
		void runTargetAction(plugin, "same", "use");
		return;
	}
	if (action === "use-release") {
		void runTargetAction(plugin, "release", "use");
		return;
	}
	if (action === "use-latest") {
		void runTargetAction(plugin, "latest", "use");
		return;
	}

	const version = target.dataset.version;
	if (!version) {
		return;
	}
	if (action === "use-installed") {
		void useInstalledVersion(plugin, version);
		return;
	}
	if (action === "delete-installed") {
		pendingDelete = { pluginName: plugin, version };
		render();
	}
});

render();
void reloadPlugins();
