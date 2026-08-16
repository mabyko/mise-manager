<script lang="ts">
	import { state } from "../core/state.svelte";
</script>

<div class="statusbar">
	{#if state.busy}<div class="spinner"></div>{/if}
	<span class="sb-label">{state.progressLabel}</span>
	{#if state.busy && state.liveOutputLine}
		<span class="sb-live">· {state.liveOutputLine}</span>
	{/if}
	{#if state.progress !== null}
		<span class="sb-pct">{Math.round(state.progress)}%</span>
	{/if}
</div>
