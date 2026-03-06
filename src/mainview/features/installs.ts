import { rpc } from "../core/rpc";
import { state, setBusy } from "../core/state";
import { buildInstallCatalog } from "../core/helpers";
import {
	escapeHtml,
	findUserPluginInfo,
	isCustomUserPluginUrl,
} from "../core/utils";
import { addLog } from "./logs";

export function renderPluginUrlDialog(): string {
	if (!state.pendingPluginUrlDialog) {
		return "";
	}

	const isEdit = state.pendingPluginUrlDialog.mode === "edit";
	return `
		<div class="modal-overlay">
			<div class="modal-card">
				<h3>${isEdit ? "Edit Plugin URL" : "Install Plugin"}</h3>
				<p>
					Plugin: <strong>${escapeHtml(state.pendingPluginUrlDialog.pluginName)}</strong><br/>
					${isEdit ? "새 URL로 plugin definition을 재설치합니다(--force)." : "비워두면 기본 registry source로 설치합니다."}
				</p>
				<input
					class="modal-input"
					data-action="plugin-url-input"
					placeholder="https://github.com/owner/repo.git (optional)"
					value="${escapeHtml(state.pendingPluginUrlValue)}"
				/>
				<div class="modal-actions">
					<button class="mini-btn" data-action="cancel-plugin-url">Cancel</button>
					<button class="mini-btn" data-action="submit-plugin-url" ${state.busy ? "disabled" : ""}>
						${isEdit ? "Save URL" : "Install"}
					</button>
				</div>
			</div>
		</div>
	`;
}

export function renderInstallsTab(): string {
	const query = state.pluginSearchQuery.trim().toLowerCase();
	const catalog = buildInstallCatalog();
	const filtered = catalog.filter((plugin) =>
		query ? plugin.toLowerCase().includes(query) : true,
	);

	const renderStateBadges = (
		userPluginInstalled: boolean,
		corePlugin: boolean,
		toolInstalled: boolean,
	): string => `
		<div class="state-badges">
			${userPluginInstalled ? `<span class="badge plugin-user" title="User plugin: mise plugins install 로 추가된 plugin definition">Plugin (User)</span>` : ""}
			${corePlugin ? `<span class="badge plugin-core" title="Core plugin: mise 내장 plugin definition">Plugin (Core)</span>` : ""}
			${toolInstalled ? `<span class="badge tool-installed" title="Tool installed: mise ls --installed 기준으로 실제 버전이 설치됨">Tool Installed</span>` : ""}
		</div>
	`;

	const installedRows = filtered
		.map((plugin) => {
			const userPluginInstalled = state.installedPluginNames.includes(plugin);
			const corePlugin = state.corePluginNames.includes(plugin);
			const toolInstalled = state.installedToolNames.includes(plugin);
			const userInfo = findUserPluginInfo(plugin, state.installedUserPluginInfos);
			const isCustomUserUrl = userPluginInstalled
				? isCustomUserPluginUrl(
					plugin,
					state.installedUserPluginInfos,
					state.remotePluginInfos,
				)
				: false;
			if (!userPluginInstalled && !corePlugin && !toolInstalled) {
				return "";
			}
			const stateBadge = renderStateBadges(
				userPluginInstalled,
				corePlugin,
				toolInstalled,
			);
			const userUrlBlock =
				userPluginInstalled && userInfo?.url
					? `<div class="plugin-url ${isCustomUserUrl ? "custom" : "default"}" title="${escapeHtml(userInfo.url)}">
						<span class="url-label">${isCustomUserUrl ? "Custom URL" : "Default URL"}</span>
						<span class="url-value">${escapeHtml(userInfo.url)}</span>
					</div>`
					: userPluginInstalled
						? `<div class="plugin-url unknown"><span class="url-label">URL</span><span class="url-value">N/A</span></div>`
						: "";
			return `
				<tr>
					<td class="plugin">${escapeHtml(plugin)}</td>
					<td>${stateBadge}${userUrlBlock}</td>
					<td class="actions">
						<button data-action="edit-plugin-def" data-plugin="${escapeHtml(plugin)}" ${state.busy || corePlugin || !userPluginInstalled ? "disabled" : ""}>Edit Plugin</button>
						<button
							data-action="uninstall-plugin-def"
							data-plugin="${escapeHtml(plugin)}"
							title="${corePlugin ? "Core plugin은 제거할 수 없습니다." : "User plugin definition 제거"}"
							${state.busy || !userPluginInstalled ? "disabled" : ""}
						>Remove Plugin</button>
					</td>
				</tr>
			`;
		})
		.filter((row) => row.length > 0)
		.slice(0, 200)
		.join("");

	const notInstalledRows = filtered
		.map((plugin) => {
			const userPluginInstalled = state.installedPluginNames.includes(plugin);
			const corePlugin = state.corePluginNames.includes(plugin);
			const toolInstalled = state.installedToolNames.includes(plugin);
			if (userPluginInstalled || corePlugin || toolInstalled) {
				return "";
			}
			return `
				<tr>
					<td class="plugin">${escapeHtml(plugin)}</td>
					<td><span class="badge empty">Not Installed</span></td>
					<td class="actions">
						<button data-action="install-plugin-def" data-plugin="${escapeHtml(plugin)}" ${state.busy ? "disabled" : ""}>Install Plugin</button>
					</td>
				</tr>
			`;
		})
		.filter((row) => row.length > 0)
		.slice(0, 200)
		.join("");

	return `
		<section class="panel">
			<h2>Installed</h2>
			<section class="table-wrap">
				<table>
					<thead>
						<tr>
							<th>Plugin</th>
							<th>State</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						${installedRows || `<tr><td colspan="3" class="empty-row">설치된 항목이 없습니다.</td></tr>`}
					</tbody>
				</table>
			</section>
			<h2 style="margin-top: 14px;">Not Installed</h2>
			<section class="table-wrap">
				<table>
					<thead>
						<tr>
							<th>Plugin</th>
							<th>State</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						${notInstalledRows || `<tr><td colspan="3" class="empty-row">검색 결과가 없습니다.</td></tr>`}
					</tbody>
				</table>
			</section>
		</section>
	`;
}

export async function reloadPluginDefinitions(render: () => void): Promise<void> {
	setBusy(true, "Loading plugin definitions", 10);
	render();
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
	} finally {
		render();
	}
}

export async function installPluginDefinition(
	plugin: string,
	render: () => void,
	gitUrl?: string,
	force = false,
): Promise<void> {
	if (state.busy) {
		return;
	}
	setBusy(true, `${force ? "Updating" : "Installing"} plugin ${plugin}`, 40);
	render();
	try {
		await rpc.request.installPluginDefinition({ plugin, gitUrl, force });
		await reloadPluginDefinitions(render);
		const urlText = gitUrl && gitUrl.trim().length > 0 ? ` (${gitUrl.trim()})` : "";
		addLog(`${plugin}: plugin ${force ? "updated" : "installed"}${urlText}.`);
	} catch (error) {
		addLog(`${plugin}: plugin ${force ? "update" : "install"} failed - ${(error as Error).message}`);
		setBusy(false, "Ready", 0);
		render();
	}
}

export function openInstallPluginDialog(plugin: string, render: () => void): void {
	state.pendingPluginUrlDialog = { mode: "install", pluginName: plugin };
	state.pendingPluginUrlValue = "";
	render();
}

export function openEditPluginDialog(plugin: string, render: () => void): void {
	const userInfo = findUserPluginInfo(plugin, state.installedUserPluginInfos);
	if (!userInfo) {
		addLog(`${plugin}: cannot edit URL because user plugin is not installed.`);
		render();
		return;
	}
	state.pendingPluginUrlDialog = { mode: "edit", pluginName: plugin };
	state.pendingPluginUrlValue = userInfo.url ?? "";
	render();
}

export async function submitPluginUrlDialog(render: () => void): Promise<void> {
	if (!state.pendingPluginUrlDialog || state.busy) {
		return;
	}

	const dialog = state.pendingPluginUrlDialog;
	const gitUrl = state.pendingPluginUrlValue.trim();
	if (dialog.mode === "edit" && gitUrl.length === 0) {
		addLog(`${dialog.pluginName}: URL is required for edit.`);
		return;
	}
	state.pendingPluginUrlDialog = null;
	state.pendingPluginUrlValue = "";
	render();
	await installPluginDefinition(
		dialog.pluginName,
		render,
		gitUrl.length > 0 ? gitUrl : undefined,
		dialog.mode === "edit",
	);
}

export async function uninstallPluginDefinition(
	plugin: string,
	render: () => void,
): Promise<void> {
	if (state.busy) {
		return;
	}
	setBusy(true, `Removing plugin ${plugin}`, 40);
	render();
	try {
		await rpc.request.uninstallPluginDefinition({ plugin });
		await reloadPluginDefinitions(render);
		addLog(`${plugin}: plugin removed.`);
	} catch (error) {
		addLog(`${plugin}: plugin remove failed - ${(error as Error).message}`);
		setBusy(false, "Ready", 0);
		render();
	}
}
