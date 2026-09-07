<script lang="ts">
	import { tick } from "svelte";
	import { state } from "../core/state.svelte";
	import { buildOverviewRows, getToolStatus } from "../core/overview";
	import type { PluginRow } from "../core/types";
	import { isPreReleaseVersion } from "../../shared/version";
	import { checkUpdates, reloadAndCheckTools, retryCheck, requestMajorUpdate, runTargetAction, updateToVersion, useInstalledVersion } from "../features/updater";

	const updates = $derived(buildOverviewRows(state.plugins).filter(row => row.primary || row.major));
	const filtered = $derived(state.plugins.filter(plugin =>
		plugin.name.toLowerCase().includes(state.toolSearchQuery.trim().toLowerCase()) &&
		(!state.toolUpdatesOnly || updates.some(row => row.plugin === plugin.name)),
	));
	const selected = $derived(filtered.find(p => p.name === state.selectedToolName) ?? filtered[0] ?? null);
	const update = $derived(selected ? updates.find(row => row.plugin === selected.name) : undefined);
	let searchInput: HTMLInputElement;

	function candidatesFor(plugin: PluginRow) {
		const seen = new Set<string>();
		return ([
			{ version: plugin.sameMajorLatest, mode: "same" as const },
			{ version: plugin.releaseLatest, mode: "release" as const },
			{ version: plugin.overallLatest, mode: "latest" as const },
		]).filter((candidate): candidate is { version: string; mode: "same" | "release" | "latest" } => {
			if (!candidate.version || candidate.version === plugin.activeGlobalVersion || seen.has(candidate.version)) return false;
			seen.add(candidate.version);
			return true;
		});
	}

	async function clearSearch() {
		state.toolSearchQuery = "";
		state.toolUpdatesOnly = false;
		await tick();
		searchInput.focus();
	}
</script>

<div class="page-head">
	<div><h1 tabindex="-1">내 도구</h1><p class="page-subtitle">설치된 도구 {state.plugins.length}개 · 버전 선택과 업데이트</p></div>
	<div class="page-actions">
		<button class="btn" onclick={() => void reloadAndCheckTools()} disabled={state.busy || !state.miseIsInstalled}>목록 새로고침</button>
		<button class="btn" onclick={() => void checkUpdates()} disabled={state.busy || !state.plugins.length}>업데이트 확인</button>
	</div>
</div>
<div class="tools-context">
	<details class="scope-help"><summary>적용 범위: 전역</summary><p>전역 버전은 이 컴퓨터의 기본값입니다. 프로젝트별 mise 설정이 있으면 그 설정이 우선합니다.</p></details>
	<label><input type="checkbox" bind:checked={state.toolUpdatesOnly} /> 업데이트 가능만 보기 · {updates.length}</label>
</div>
{#if state.toolsError}<div class="inline-error" role="status">도구 목록을 불러오지 못했습니다. {state.toolsError} <button class="text-btn" onclick={() => void reloadAndCheckTools()} disabled={state.busy}>다시 시도</button></div>{/if}
<div class="tools-split">
	<section class="tool-list" aria-label="설치된 도구">
		<label class="eyebrow" for="tool-search">도구 찾기</label>
		<input id="tool-search" class="search-input" placeholder="이름으로 검색" bind:this={searchInput} bind:value={state.toolSearchQuery} />
		<p class="list-count" role="status">{filtered.length}개 도구{state.toolUpdatesOnly ? " · 업데이트 가능" : ""}</p>
		<div class="tool-list-items">
			{#each filtered as plugin (plugin.name)}
				<button class="tool-item" class:selected={selected?.name === plugin.name} aria-pressed={selected?.name === plugin.name} onclick={() => (state.selectedToolName = plugin.name)}>
					<span class="tool-glyph" aria-hidden="true">{plugin.name.slice(0, 2)}</span>
					<span class="tool-item-info"><strong>{plugin.name}</strong><span class="mono">{plugin.activeGlobalVersion ?? "전역 미선택"}</span></span>
					<span class="tool-meta" class:error-text={plugin.status === "error"}>{getToolStatus(plugin)}</span>
				</button>
			{/each}
		</div>
	</section>
	<section class="tool-detail" aria-label="선택한 도구 상세">
		{#if selected}
			<div class="detail-head"><span class="tool-glyph" aria-hidden="true">{selected.name.slice(0, 2)}</span><h2>{selected.name}</h2><span class="pill" class:error-pill={selected.status === "error"}>{getToolStatus(selected)}</span></div>
			<div class="current-version"><span class="eyebrow">현재 전역 버전</span><div><strong class="mono">{selected.activeGlobalVersion ?? "미선택"}</strong>{#if selected.activeGlobalVersion}<span class="pill">사용 중</span>{/if}</div></div>
			{#if selected.status === "error"}
				<div class="inline-error" role="status"><strong>도구 정보를 확인하지 못했습니다.</strong><p>{selected.error}</p><button class="btn" onclick={() => void retryCheck(selected.name)} disabled={state.busy}>다시 확인</button></div>
			{:else if selected.status === "checking" || selected.status === "updating" || selected.status === "deleting"}
				<div class="detail-note" role="status"><span class="spinner" aria-hidden="true"></span> {getToolStatus(selected)} · 작업 결과가 자동으로 반영됩니다.</div>
			{:else if update?.primary}
				<div class="update-preview"><div class="row"><h3>업데이트 미리보기</h3><span class="pill">같은 major</span></div>
					<div class="version-flow mono"><span>{selected.activeGlobalVersion ?? "전역 미선택"}</span><span aria-hidden="true">→</span><strong>{update.primary}</strong></div>
					<p>같은 major 안에서 업데이트합니다. 프로젝트 호환성을 확인하세요.</p>
					<div class="update-impact"><span>설치 후 전역 전환</span><span>기존 설치 버전 보관</span></div>
					<div class="row wrap"><button class="btn primary" disabled={state.busy} onclick={() => void updateToVersion(selected.name, update!.primary!)}>{update.primary}으로 업데이트</button>
						{#if !selected.installedVersions.includes(update.primary)}<button class="text-btn" disabled={state.busy} onclick={() => void runTargetAction(selected.name, "same", "install")}>설치만</button>{/if}
					</div>
				</div>
			{:else if getToolStatus(selected) === "최신 안정 버전"}<div class="detail-note"><h3>현재 확인된 안정 버전 업데이트가 없습니다.</h3><p>다른 버전과 프리릴리스는 아래에서 확인할 수 있습니다.</p></div>
			{:else if getToolStatus(selected) === "채널 버전"}<div class="detail-note"><h3>채널 버전을 사용 중입니다.</h3><p>숫자 버전과 직접 비교할 수 없습니다. 아래 후보를 확인해 주세요.</p></div>
			{:else if !update?.major}<div class="detail-note"><p>{getToolStatus(selected)} · 업데이트 확인으로 버전 정보를 조회하세요.</p></div>{/if}

			<h3 class="section-label">설치된 버전 <span class="subtle">· {selected.installedVersions.length}</span></h3>
			{#each selected.installedVersions as version (version)}
				<div class="installed-version"><span class="mono">{version}</span>
					{#if version === selected.activeGlobalVersion}<span class="pill">사용 중 · 삭제 불가</span>
					{:else}<div class="version-actions"><button class="mini-btn" disabled={state.busy} onclick={() => void useInstalledVersion(selected.name, version)}>전역으로 사용</button><button class="mini-btn danger" disabled={state.busy} aria-label="{selected.name} {version} 삭제" onclick={() => (state.pendingDelete = { pluginName: selected.name, version })}>삭제…</button></div>{/if}
				</div>
			{:else}<p class="subtle">설치된 버전이 없습니다.</p>{/each}

			{#if update?.major}
				<div class="major-notice"><div><span class="pill up">새 major</span> <strong class="mono">{update.major}</strong><p>호환성 확인이 필요한 별도 업데이트입니다.</p></div><div class="version-actions"><button class="btn" disabled={state.busy} onclick={() => requestMajorUpdate(selected.name, update!.major!)}>변경 검토…</button>{#if !selected.installedVersions.includes(update.major)}<button class="text-btn" disabled={state.busy} onclick={() => void runTargetAction(selected.name, "release", "install")}>설치만</button>{/if}</div></div>
			{/if}
			<details class="other-versions"><summary>다른 버전 및 프리릴리스</summary>
				<p class="subtle">설치는 전역 버전을 바꾸지 않습니다. 설치 후 목록에서 전역 버전을 선택할 수 있습니다.</p>
				{#each candidatesFor(selected) as candidate (candidate.version)}
					<div class="installed-version"><div><strong class="mono">{candidate.version}</strong><span class="subtle candidate-kind">{isPreReleaseVersion(candidate.version) ? "프리릴리스" : "릴리스 후보"}</span></div>
						{#if selected.installedVersions.includes(candidate.version)}<span class="pill">설치됨</span>{:else}<button class="mini-btn" disabled={state.busy || selected.status !== "done"} onclick={() => void runTargetAction(selected.name, candidate.mode, "install")}>설치</button>{/if}
					</div>
				{:else}<p class="subtle">확인된 다른 후보가 없습니다.</p>{/each}
			</details>
		{:else}
			<div class="empty-detail">
				<h2>{!state.toolsLoaded ? "도구를 불러오는 중입니다." : !state.plugins.length ? "설치된 도구가 없습니다." : "조건에 맞는 도구가 없어요."}</h2>
				<p>{state.plugins.length ? "다른 이름으로 검색하거나 업데이트 필터를 해제하세요." : "mise로 도구를 설치한 뒤 목록을 새로고침하세요."}</p>
				{#if state.toolSearchQuery || state.toolUpdatesOnly}<button class="btn" onclick={() => void clearSearch()}>검색·필터 초기화</button>{:else}<button class="btn" disabled={state.busy || !state.miseIsInstalled} onclick={() => void reloadAndCheckTools()}>목록 새로고침</button>{/if}
			</div>
		{/if}
	</section>
</div>
