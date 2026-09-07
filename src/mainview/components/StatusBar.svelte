<script lang="ts">
	import { state } from "../core/state.svelte";
	const preview = typeof window !== "undefined" && !("__TAURI_INTERNALS__" in window);
</script>

<div class="statusbar">
	{#if state.busy}<span class="spinner" aria-hidden="true"></span>{:else}<span class="dot ok" aria-hidden="true"></span>{/if}
	<span class="sb-label" role="status">{state.progressLabel === "Ready" ? "준비됨" : state.progressLabel}</span>
	{#if state.busy && state.liveOutputLine}<span class="sb-live" title={state.liveOutputLine}>{state.liveOutputLine}</span>{/if}
	{#if state.busy && state.progress !== null}<progress max="100" value={state.progress} aria-label="작업 진행률"></progress><span>{Math.round(state.progress)}%</span>{/if}
	{#if preview}<span class="preview-label">미리보기 · 샘플 데이터</span>{/if}
	<button class="text-btn status-log" onclick={() => (state.activeTab = "logs")}>작업 기록 →</button>
</div>
