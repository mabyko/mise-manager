<script lang="ts">
	import { state } from "../core/state.svelte";
	import { buildInstallCatalog } from "../core/helpers";
	import { findUserPluginInfo, isCustomUserPluginUrl } from "../core/utils";
	import {
		openCustomPluginDialog,
		openEditPluginDialog,
		openInstallPluginDialog,
		uninstallPluginDefinition,
	} from "../features/installs";

	const filtered = $derived.by(() => {
		const query = state.pluginSearchQuery.trim().toLowerCase();
		return buildInstallCatalog().filter((plugin) =>
			query ? plugin.toLowerCase().includes(query) : true,
		);
	});

	const ROW_LIMIT = 200;

	const installedAll = $derived.by(() =>
		filtered
			.map((plugin) => {
				const userPluginInstalled = state.installedPluginNames.includes(plugin);
				const corePlugin = state.corePluginNames.includes(plugin);
				const toolInstalled = state.installedToolNames.includes(plugin);
				const userInfo = findUserPluginInfo(plugin, state.installedUserPluginInfos);
				const isCustomUserUrl = userPluginInstalled
					? isCustomUserPluginUrl(plugin, state.installedUserPluginInfos, state.remotePluginInfos)
					: false;
				return { plugin, userPluginInstalled, corePlugin, toolInstalled, userInfo, isCustomUserUrl };
			})
			.filter((row) => row.userPluginInstalled || row.corePlugin || row.toolInstalled),
	);
	const installedRows = $derived(installedAll.slice(0, ROW_LIMIT));
	const installedHidden = $derived(installedAll.length - installedRows.length);

	const notInstalledAll = $derived.by(() =>
		filtered.filter(
			(plugin) =>
				!state.installedPluginNames.includes(plugin) &&
				!state.corePluginNames.includes(plugin) &&
				!state.installedToolNames.includes(plugin),
		),
	);
	const notInstalledRows = $derived(notInstalledAll.slice(0, ROW_LIMIT));
	const notInstalledHidden = $derived(notInstalledAll.length - notInstalledRows.length);
</script>

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
				{#each installedRows as row (row.plugin)}
					<tr>
						<td class="plugin">{row.plugin}</td>
						<td>
							<div class="state-badges">
								{#if row.userPluginInstalled}<span class="badge plugin-user" title="User plugin: mise plugins install 로 추가된 plugin definition">Plugin (User)</span>{/if}
								{#if row.corePlugin}<span class="badge plugin-core" title="Core plugin: mise 내장 plugin definition">Plugin (Core)</span>{/if}
								{#if row.toolInstalled}<span class="badge tool-installed" title="Tool installed: mise ls --installed 기준으로 실제 버전이 설치됨">Tool Installed</span>{/if}
							</div>
							{#if row.userPluginInstalled && row.userInfo?.url}
								<div class="plugin-url {row.isCustomUserUrl ? 'custom' : 'default'}" title={row.userInfo.url}>
									<span class="url-label">{row.isCustomUserUrl ? "Custom URL" : "Default URL"}</span>
									<span class="url-value">{row.userInfo.url}</span>
								</div>
							{:else if row.userPluginInstalled}
								<div class="plugin-url unknown"><span class="url-label">URL</span><span class="url-value">N/A</span></div>
							{/if}
						</td>
						<td class="actions">
							<div class="row-actions">
								<button
									disabled={state.busy || row.corePlugin || !row.userPluginInstalled}
									onclick={() => openEditPluginDialog(row.plugin)}
								>Edit Plugin</button>
								<button
									title={row.corePlugin ? "Core plugin은 제거할 수 없습니다." : "User plugin definition 제거"}
									disabled={state.busy || !row.userPluginInstalled}
									onclick={() => void uninstallPluginDefinition(row.plugin)}
								>Remove Plugin</button>
							</div>
						</td>
					</tr>
				{:else}
					<tr><td colspan="3" class="empty-row">설치된 항목이 없습니다.</td></tr>
				{/each}
				{#if installedHidden > 0}
					<tr><td colspan="3" class="empty-row">+{installedHidden}개 더 있음 — 검색으로 좁혀보세요.</td></tr>
				{/if}
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
				{#each notInstalledRows as plugin (plugin)}
					<tr>
						<td class="plugin">{plugin}</td>
						<td><span class="badge empty">Not Installed</span></td>
						<td class="actions">
							<div class="row-actions">
								<button disabled={state.busy} onclick={() => openInstallPluginDialog(plugin)}>Install Plugin</button>
							</div>
						</td>
					</tr>
				{:else}
					<tr><td colspan="3" class="empty-row">검색 결과가 없습니다. <button class="mini-btn" disabled={state.busy} onclick={openCustomPluginDialog}>Install Custom Plugin</button></td></tr>
				{/each}
				{#if notInstalledHidden > 0}
					<tr><td colspan="3" class="empty-row">+{notInstalledHidden}개 더 있음 — 검색으로 좁혀보세요.</td></tr>
				{/if}
			</tbody>
		</table>
	</section>
</section>
