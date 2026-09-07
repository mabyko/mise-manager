<script lang="ts">
	import { state } from "../core/state.svelte";
	import { buildInstallCatalog } from "../core/helpers";
	import { findUserPluginInfo, isCustomUserPluginUrl } from "../core/utils";
	import {
		openCustomPluginDialog,
		openEditPluginDialog,
		openInstallPluginDialog,
		reloadPluginDefinitions,
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
		filtered
			.filter(
				(plugin) =>
					!state.installedPluginNames.includes(plugin) &&
					!state.corePluginNames.includes(plugin) &&
					!state.installedToolNames.includes(plugin),
			)
			.map((plugin) => ({
				plugin,
				url: state.remotePluginInfos.find((entry) => entry.name === plugin)?.url ?? null,
			})),
	);
	const notInstalledRows = $derived(notInstalledAll.slice(0, ROW_LIMIT));
	const notInstalledHidden = $derived(notInstalledAll.length - notInstalledRows.length);
</script>

<div class="page-head">
	<div><h1>플러그인 관리</h1><p class="page-subtitle">도구를 설치하는 데 사용하는 플러그인 정의를 관리합니다</p></div>
	<div class="page-actions">
		<input
			class="search-input"
			placeholder="플러그인 이름으로 검색"
			aria-label="플러그인 검색"
			bind:value={state.pluginSearchQuery}
		/>
		<button class="btn" onclick={openCustomPluginDialog} disabled={state.busy}>사용자 플러그인 추가</button>
		<button
			class="btn icon-btn"
			title="목록 새로고침"
			aria-label="목록 새로고침"
			onclick={() => void reloadPluginDefinitions()}
			disabled={state.busy}
		>↻</button>
	</div>
</div>
<div class="page-meta">Remote Plugin Definitions: {state.remotePluginNames.length} / Core Plugins: {state.corePluginNames.length} / User Plugins: {state.installedPluginNames.length} / Installed Tools: {state.installedToolNames.length}</div>

<section class="panel">
	<h2>사용 가능한 플러그인</h2>
	<section class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>플러그인</th>
					<th>상태</th>
					<th class="th-actions">관리</th>
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
							{#if row.userPluginInstalled}
								<div class="row-actions">
									<button
										disabled={state.busy || row.corePlugin}
										onclick={() => openEditPluginDialog(row.plugin)}
									>URL 수정</button>
									<button
										title="User plugin definition 제거"
										disabled={state.busy}
										onclick={() => void uninstallPluginDefinition(row.plugin)}
									>플러그인 제거</button>
								</div>
							{:else}
								<span class="version-meta">{row.corePlugin ? "Core — 제거 불가" : "Tool only"}</span>
							{/if}
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
					<th>플러그인</th>
					<th>Source</th>
					<th class="th-actions">관리</th>
				</tr>
			</thead>
			<tbody>
				{#each notInstalledRows as row (row.plugin)}
					<tr>
						<td class="plugin">{row.plugin}</td>
						<td>
							{#if row.url}
								<span class="version-meta src-url" title={row.url}>{row.url}</span>
							{:else}
								<span class="version-meta">registry</span>
							{/if}
						</td>
						<td class="actions">
							<div class="row-actions">
								<button disabled={state.busy} onclick={() => openInstallPluginDialog(row.plugin)}>플러그인 설치</button>
							</div>
						</td>
					</tr>
				{:else}
					<tr><td colspan="3" class="empty-row">검색 결과가 없습니다. <button class="mini-btn" disabled={state.busy} onclick={openCustomPluginDialog}>사용자 플러그인 추가</button></td></tr>
				{/each}
				{#if notInstalledHidden > 0}
					<tr><td colspan="3" class="empty-row">+{notInstalledHidden}개 더 있음 — 검색으로 좁혀보세요.</td></tr>
				{/if}
			</tbody>
		</table>
	</section>
</section>
