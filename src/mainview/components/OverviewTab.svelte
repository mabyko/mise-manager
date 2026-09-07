<script lang="ts">
	import appIcon from "../assets/app-icon.png";
	import { state } from "../core/state.svelte";
	import { getMiseStatusSnapshot, normalizeVersionToken } from "../core/miseStatus";
	import { buildOverviewRows, getToolStatus } from "../core/overview";
	import { checkLatestMiseRelease, reloadMiseVersion, openMiseUpdateDialog } from "../features/mise";
	import { checkUpdates, reloadAndCheckTools } from "../features/updater";

	const status = $derived(getMiseStatusSnapshot(state));
	const current = $derived(normalizeVersionToken(state.miseVersion));
	const latest = $derived(normalizeVersionToken(state.miseLatestVersion));
	const rows = $derived(buildOverviewRows(state.plugins));
	const updateRows = $derived(rows.filter(row => row.primary || row.major));
	const errors = $derived(state.plugins.filter(p => p.status === "error"));
	const currentCount = $derived(state.plugins.filter(p => getToolStatus(p) === "최신 안정 버전").length);
	const unverifiedCount = $derived(state.plugins.length - updateRows.length - currentCount - errors.length);
	const recentLines = $derived(state.logs.slice(0, 3).map(line => line.replace(/^\[[^\]]*\]\s*/, "")));
	const miseLabels = {
		loading: "확인 중", check_failed: "확인 실패", not_checked: "비교 불가", updating: "업데이트 중",
		updated_needs_reload: "업데이트 완료", update_available: "새 버전", up_to_date: "최신 상태", ahead_or_custom: "최신 이상 / 커스텀",
	};

	function openTool(name: string) {
		state.selectedToolName = name;
		state.toolSearchQuery = "";
		state.toolUpdatesOnly = false;
		state.activeTab = "updater";
	}

	async function checkEnvironment() {
		if (state.busy) return;
		await reloadMiseVersion();
		await checkLatestMiseRelease();
		if (!state.toolsLoaded || state.toolsError || !state.plugins.length) await reloadAndCheckTools();
		else await checkUpdates();
	}
</script>

<div class="page-head">
	<div><h1 tabindex="-1">요약</h1><p class="page-subtitle">개발 환경의 상태와 필요한 작업을 한눈에</p></div>
	<div class="page-actions"><button class="btn primary" onclick={() => void checkEnvironment()} disabled={state.busy || !state.miseIsInstalled}>업데이트 확인</button></div>
</div>

<section class="overview-intro">
	<h2>{#if !state.miseIsInstalled}먼저 mise를 설치해 주세요.{:else if !state.toolsLoaded}개발 도구를 불러오고 있어요.{:else if state.toolsError}도구 목록을 불러오지 못했어요.{:else if state.busy}개발 환경을 확인하고 있어요.{:else if updateRows.length}도구 {updateRows.length}개를 업데이트할 수 있어요.{:else if errors.length || unverifiedCount}확인이 필요한 도구가 있어요.{:else if !state.plugins.length}설치된 도구가 없어요.{:else}설치된 도구가 최신 상태예요.{/if}</h2>
	<p>{state.toolsError ?? (errors.length ? `${errors.length}개 도구를 확인하지 못했습니다. 상세 화면에서 다시 확인할 수 있습니다.` : "변경 내용을 확인한 뒤, 필요한 도구부터 업데이트하세요.")}</p>
	{#if state.toolsCheckedAt}<span class="checked-at">마지막 도구 확인 · {state.toolsCheckedAt}</span>{/if}
</section>
<div class="overview-counts" aria-label="도구 상태 요약">
	<span><strong>{state.plugins.length}</strong> 설치된 도구</span>
	<span><strong>{updateRows.length}</strong> 도구 업데이트</span>
	<span><strong>{currentCount}</strong> 최신 안정 버전</span>
	{#if errors.length}<span class="error-text"><strong>{errors.length}</strong> 확인 실패</span>{/if}
	{#if unverifiedCount}<span><strong>{unverifiedCount}</strong> 확인 필요</span>{/if}
</div>

<div class="overview-grid">
	<section class="overview-panel">
		<div class="panel-heading"><div><h2>도구 업데이트</h2><p>변경 내용을 확인하고 도구별로 관리하세요.</p></div><button class="text-btn" onclick={() => (state.activeTab = "updater")}>내 도구 →</button></div>
		{#each rows as row (row.plugin)}
			<button class="overview-tool" onclick={() => openTool(row.plugin)}>
				<span class="tool-glyph" aria-hidden="true">{row.plugin.slice(0, 2)}</span>
				<span class="overview-tool-info"><strong>{row.plugin}</strong>
					{#if row.error}<span class="error-text">확인 실패 · 상세에서 다시 확인</span>
					{:else}<span class="mono version-flow-small">{row.current ?? "미선택"} → {row.primary ?? row.major}</span><span class="subtle">{row.primary ? "같은 major" : "새 major · 호환성 확인 필요"}{row.primary && row.major ? ` · 새 major ${row.major}도 있음` : ""}</span>{/if}
				</span><span class="go-detail">상세 보기 →</span>
			</button>
		{:else}
			<div class="empty-note">
				{#if state.toolsError}<p>{state.toolsError}</p><button class="btn" onclick={() => void reloadAndCheckTools()} disabled={state.busy}>다시 불러오기</button>
				{:else if !state.toolsLoaded || state.busy}도구 정보를 확인하고 있습니다.
				{:else if !state.plugins.length}설치된 도구가 없습니다. <button class="text-btn" onclick={() => (state.activeTab = "updater")}>도구 목록 확인 →</button>
				{:else if unverifiedCount}채널 버전 또는 비교 정보가 없는 도구는 내 도구에서 확인하세요.
				{:else}현재 확인된 안정 버전 업데이트가 없습니다.{/if}
			</div>
		{/each}
		<div class="panel-bottom">업데이트 시 이전 버전은 보관됩니다. 프리릴리스는 내 도구에서 별도로 확인하세요.</div>
	</section>

	<section class="mise-card" aria-label="mise 자체 업데이트">
		<div class="row"><span class="eyebrow">mise 관리</span><span class="pill" class:up={status.canUpdate} class:error-pill={status.key === "check_failed"}>{!state.miseIsInstalled ? "설치 필요" : miseLabels[status.key]}</span></div>
		<div class="mise-brand"><img src={appIcon} alt="" /><h2>mise</h2></div>
		<p>도구 관리 프로그램 자체의 업데이트입니다.</p>
		<div class="mise-versions"><div><span>현재</span><strong class="mono">{current ?? "미확인"}</strong></div>{#if latest && latest !== current}<span aria-hidden="true">→</span><div><span>최신 릴리스</span><strong class="mono">{latest}</strong></div>{/if}</div>
		{#if !state.miseIsInstalled}
			<p>mise를 찾지 못했습니다. 설치 방법을 확인해 주세요.</p>
		{:else if state.miseNeedsReload}
			<p>업데이트를 적용했습니다. 새 환경을 반영하려면 앱을 다시 시작하세요.</p>
		{:else if state.miseCurrentError || state.miseLatestError}
			<p class="error-text">{state.miseCurrentError ?? state.miseLatestError}</p>
		{:else if state.miseLastResult.startsWith("ERROR:")}
			<p class="error-text">업데이트에 실패했습니다. 상세 기록을 확인한 뒤 다시 시도하세요.</p>
		{:else}<p>도구의 전역 버전은 그대로 유지됩니다.</p>{/if}
		{#if status.canUpdate && state.miseIsInstalled}<button class="btn mise-update" onclick={openMiseUpdateDialog} disabled={state.busy}>mise 업데이트…</button>{/if}
		<button class="text-btn" onclick={() => (state.activeTab = "mise")}>{!state.miseIsInstalled ? "설치 안내 →" : "버전 및 실행 기록 →"}</button>
	</section>
</div>

<section class="recent-panel">
	<div class="row"><h2>최근 작업</h2><button class="text-btn" onclick={() => (state.activeTab = "logs")}>기록 보기 →</button></div>
	{#each recentLines as line, index (index)}<p class="activity-line">{line}</p>{:else}<p>아직 작업 기록이 없습니다.</p>{/each}
</section>
