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
		checkPluginDefinitionUpdates,
		updatePluginDefinition,
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
<section class="panel">
	<div class="row wrap"><div><h2>플러그인 업데이트</h2><p>플러그인의 설치 스크립트와 버전 정보를 갱신합니다. 도구 버전은 별도로 설치합니다.</p></div><button class="btn" disabled={state.busy || !state.miseIsInstalled} onclick={() => void checkPluginDefinitionUpdates()}>플러그인 업데이트 확인</button></div>
	<p class="subtle">{state.pluginUpdatesCheckedAt ? `마지막 확인 ${state.pluginUpdatesCheckedAt}` : "아직 확인하지 않았습니다."}</p>
	{#if state.pluginUpdatesError}<div class="inline-error" role="status">확인 실패: {state.pluginUpdatesError}<p>mise를 최신 버전으로 업데이트한 뒤 다시 확인하세요. 네트워크 오류는 연결 상태를 확인해 주세요.</p></div>
	{:else if state.pluginUpdatesCheckedAt && !state.outdatedPluginNames.length}<p>mise가 보고한 외부 플러그인 업데이트가 없습니다.</p>{/if}
	{#each state.outdatedPluginNames as plugin (plugin)}
		<div class="installed-version"><strong>{plugin}</strong><button class="btn primary" disabled={state.busy || !!state.pluginUpdatesError} onclick={() => void updatePluginDefinition(plugin)}>{plugin} 업데이트</button></div>
	{/each}
	{#if state.pluginUpdateResult}<p role="status">{state.pluginUpdateResult}</p>{/if}
	<p class="subtle">내장 플러그인은 mise와 함께 업데이트됩니다. 로컬 연결·압축 파일로 설치한 플러그인은 Git 업데이트 대상에서 제외될 수 있습니다.</p>
</section>
{#if state.installsError}<div class="panel inline-error" role="status">플러그인 목록을 불러오지 못했습니다. {state.installsError}<button class="btn" disabled={state.busy} onclick={() => void reloadPluginDefinitions()}>다시 시도</button></div>{/if}
<div class="page-meta">설치 가능한 플러그인 {state.remotePluginNames.length}개 · 내장 {state.corePluginNames.length}개 · 외부 {state.installedPluginNames.length}개</div>

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
								{#if row.userPluginInstalled}<span class="badge plugin-user">외부 플러그인</span>{/if}
								{#if row.corePlugin}<span class="badge plugin-core">mise 내장</span>{/if}
								{#if row.toolInstalled}<span class="badge tool-installed">도구 설치됨</span>{/if}
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
	<h2 style="margin-top: 14px;">설치 가능한 플러그인</h2>
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
