<script lang="ts">

	import { state } from "../core/state.svelte";
	import { getToolUpdate, getToolStatus, getInstalledSeries } from "../core/toolStatus";
	import type { PluginRow } from "../core/types";
	import { isPreReleaseVersion } from "../../shared/version";
	import { reloadAndCheckTools, retryCheck, requestMajorUpdate, installVersion, updateInstalledSeries, seriesUpdateSwitchesGlobal, useInstalledVersion } from "../features/updater";
	import { checkAllUpdates } from "../features/updates";
	import { settings } from "../core/settings.svelte";
	import { getUpdateSummary } from "../core/updateSummary";
	const summary = $derived(getUpdateSummary(state));

	const selected = $derived(state.plugins.find(p => p.name === state.selectedToolName) ?? state.plugins[0] ?? null);
	const update = $derived(selected ? getToolUpdate(selected) : null);

	function candidatesFor(plugin: PluginRow) {
		return [...new Set([plugin.sameMajorLatest, plugin.releaseLatest, settings.showPrereleases ? plugin.overallLatest : null])]
			.filter((version): version is string => !!version && version !== plugin.activeGlobalVersion);
	}

</script>

<div class="page-head">
	<div><h1 tabindex="-1">{selected?.name ?? "내 도구"}</h1><p class="page-subtitle">설치된 버전 관리</p></div>
	<div class="page-actions"><button class="btn" onclick={() => void checkAllUpdates()} disabled={state.busy || state.updateCheckRunning || !state.miseIsInstalled}>{state.updateCheckRunning ? "전체 확인 중…" : "업데이트 확인"}</button></div>
</div>
{#if summary.items.length || summary.attention}
	<button class="update-notice" onclick={() => state.activeTab = "updates"}><span class="dot" class:ok={!summary.errors.length} class:err={!!summary.errors.length}></span><span>{summary.items.length ? `업데이트 ${summary.items.length}개를 확인했어요` : state.updateCheckRunning ? "업데이트를 확인하고 있어요" : "아직 확인하지 못한 항목이 있어요"}</span><span>모아 보기 →</span></button>
{/if}
{#if state.toolsError}<div class="inline-error" role="status">도구 목록을 불러오지 못했습니다. {state.toolsError} <button class="text-btn" onclick={() => void reloadAndCheckTools()} disabled={state.busy || state.updateCheckRunning}>다시 시도</button></div>{/if}
	<section class="tool-detail" aria-label="선택한 도구 상세">
		{#if selected}
			<div class="detail-head"><span class="tool-glyph" aria-hidden="true">{selected.name.slice(0, 2)}</span><h2>{selected.name}</h2><span class="pill" class:error-pill={selected.status === "error"}>{getToolStatus(selected)}</span></div>
			<div class="current-version"><span class="eyebrow">현재 전역 버전</span><div><strong class="mono">{selected.activeGlobalVersion ?? "미선택"}</strong>{#if selected.activeGlobalVersion}<span class="pill">사용 중</span>{/if}</div></div>
			{#if selected.status === "error"}
				<div class="inline-error" role="status"><strong>도구 정보를 확인하지 못했습니다.</strong><p>{selected.error}</p><button class="btn" onclick={() => void retryCheck(selected.name)} disabled={state.busy || state.updateCheckRunning}>다시 확인</button></div>
			{:else if selected.status === "checking" || selected.status === "updating" || selected.status === "deleting"}
				<div class="detail-note" role="status"><span class="spinner" aria-hidden="true"></span> {getToolStatus(selected)} · 작업 결과가 자동으로 반영됩니다.</div>
			{:else if getToolStatus(selected) === "최신 안정 버전"}<div class="detail-note"><h3>현재 확인된 안정 버전 업데이트가 없습니다.</h3></div>
			{:else if getToolStatus(selected) === "채널 버전"}<div class="detail-note"><h3>채널 버전을 사용 중입니다.</h3><p>숫자 버전과 직접 비교할 수 없습니다. 아래 후보를 확인해 주세요.</p></div>
			{:else if selected.status !== "done"}<div class="detail-note"><p>{getToolStatus(selected)} · 업데이트 확인으로 버전 정보를 조회하세요.</p></div>{/if}

			<h3 class="section-label">버전 계열</h3>
			<p class="subtle">설치된 계열마다 새 버전을 확인합니다. 이전 버전은 그대로 남습니다.</p>
			<div class="series-list">
				{#each getInstalledSeries(selected) as series (series.major)}
					<div class="series-card">
						<strong class="mono">{series.major}.x</strong>
						<div class="series-info"><div class="series-versions mono"><span>{series.current}</span>{#if series.update}<span aria-hidden="true">→</span><strong>{series.update}</strong>{/if}</div><small>{series.update ? seriesUpdateSwitchesGlobal(selected, series.update) ? "설치 후 전역 기본값 전환" : "설치만 · 전역 기본값 유지" : series.latest ? "확인된 업데이트 없음" : getToolStatus(selected)}</small></div>
						{#if series.update}<button class="btn" disabled={state.busy || state.updateCheckRunning} onclick={() => void updateInstalledSeries(selected.name, series.update!)}>{seriesUpdateSwitchesGlobal(selected, series.update) ? "설치·전역 전환" : "설치"}</button>{/if}
					</div>
				{:else}<p class="subtle">숫자 버전이 없어 major 계열을 비교할 수 없습니다.</p>{/each}
			</div>

			<h3 class="section-label">설치된 버전 <span class="subtle">· {selected.installedVersions.length}</span></h3>
			{#each selected.installedVersions as version (version)}
				<div class="installed-version"><span class="mono">{version}</span>
					{#if version === selected.activeGlobalVersion}<span class="pill">사용 중 · 삭제 불가</span>
					{:else}<div class="version-actions"><button class="mini-btn" disabled={state.busy || state.updateCheckRunning} onclick={() => void useInstalledVersion(selected.name, version)}>전역으로 사용</button><button class="mini-btn danger" disabled={state.busy || state.updateCheckRunning} aria-label="{selected.name} {version} 삭제" onclick={() => (state.pendingDelete = { pluginName: selected.name, version })}>삭제…</button></div>{/if}
				</div>
			{:else}<p class="subtle">설치된 버전이 없습니다.</p>{/each}

			{#if update?.major}
				<div class="major-notice"><div><span class="pill up">새 major</span> <strong class="mono">{update.major}</strong><p>호환성 확인이 필요한 별도 업데이트입니다.</p></div><div class="version-actions"><button class="btn" disabled={state.busy || state.updateCheckRunning} onclick={() => requestMajorUpdate(selected.name, update!.major!)}>변경 검토…</button>{#if !selected.installedVersions.includes(update.major)}<button class="text-btn" disabled={state.busy || state.updateCheckRunning} onclick={() => void installVersion(selected.name, update!.major!)}>설치만</button>{/if}</div></div>
			{/if}
			<details class="other-versions"><summary>{settings.showPrereleases ? "다른 버전 및 프리릴리스" : "다른 버전"}</summary>
				<p class="subtle">설치는 전역 버전을 바꾸지 않습니다. 설치 후 목록에서 전역 버전을 선택할 수 있습니다.</p>
				{#each candidatesFor(selected) as version (version)}
					<div class="installed-version"><div><strong class="mono">{version}</strong><span class="subtle candidate-kind">{isPreReleaseVersion(version) ? "프리릴리스" : "릴리스 후보"}</span></div>
						{#if selected.installedVersions.includes(version)}<span class="pill">설치됨</span>{:else}<button class="mini-btn" disabled={state.busy || state.updateCheckRunning || selected.status !== "done"} onclick={() => void installVersion(selected.name, version)}>설치</button>{/if}
					</div>
				{:else}<p class="subtle">확인된 다른 후보가 없습니다.</p>{/each}
			</details>
		{:else}
			<div class="empty-detail"><h2>{state.toolsLoaded ? "설치된 도구가 없습니다." : "도구를 불러오는 중입니다."}</h2><p>{state.toolsLoaded ? "mise로 도구를 설치하면 여기에 표시됩니다." : "설치된 도구를 확인하고 있습니다."}</p><button class="btn" disabled={state.busy || state.updateCheckRunning} onclick={() => void reloadAndCheckTools()}>목록 새로고침</button></div>
		{/if}
	</section>
