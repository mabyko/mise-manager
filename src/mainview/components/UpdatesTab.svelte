<script lang="ts">
	import { state } from "../core/state.svelte";
	import { getUpdateSummary } from "../core/updateSummary";
	import { dispatch } from "../core/runtime.svelte";
	import UpdateList from "./UpdateList.svelte";
	const summary = $derived(getUpdateSummary(state));
</script>

<div class="page-head"><div><h1>업데이트 <span class="subtle">{summary.items.length}</span></h1><p class="page-subtitle">도구 · mise · 플러그인</p></div><div class="page-actions"><button class="btn" disabled={state.busy || state.updateCheckRunning || !state.miseIsInstalled} onclick={() => void dispatch({ type: "check" })}>{state.updateCheckRunning ? "전체 확인 중…" : "업데이트 확인"}</button></div></div>
<section class="updates-content" aria-label="전체 업데이트">
	{#if summary.errors.length}<div class="inline-error" role="status">일부 항목을 확인하지 못했습니다.<ul>{#each summary.errors as error}<li>{error}</li>{/each}</ul></div>
	{:else if summary.attention}<p class="detail-note" role="status">{state.updateCheckRunning ? "최신 버전을 확인하고 있습니다." : "미확인 항목이 있습니다. 업데이트 확인을 눌러 주세요."}</p>{/if}
	<UpdateList items={summary.items} />
	{#if !summary.items.length && !summary.attention && !state.busy}<div class="empty-detail"><h2>확인된 업데이트가 없습니다.</h2><p>설치된 모든 버전 계열을 확인했습니다.</p></div>{/if}
	{#if summary.items.length}<p class="subtle">각 계열의 새 버전을 따로 설치할 수 있습니다. 전역 전환 여부는 항목에 표시됩니다.</p>{/if}
	{#if state.pluginUpdateResult}<p role="status">{state.pluginUpdateResult}</p>{/if}
</section>
