<script lang="ts">
	import { state } from "../core/state.svelte";
	import { dispatch, connection } from "../core/runtime.svelte";
	import { seriesUpdateSwitchesGlobal } from "../features/updater";
	import type { UpdateItem } from "../core/updateSummary";
	let { items }: { items: UpdateItem[] } = $props();
</script>

<div class="update-list">
	{#each items as item (item.id)}
		{@const tool = state.plugins.find(p => p.name === item.name)}
		{@const switches = item.kind === "series" && tool && seriesUpdateSwitchesGlobal(tool, item.to)}
		<div class="update-row">
			<span class="tool-glyph mark-{item.name}" aria-hidden="true">{item.name.slice(0, 2)}</span>
			<div class="update-info"><strong>{item.label}</strong><span class="mono">{item.from} <span aria-hidden="true">→</span> <b>{item.to}</b></span><small>{item.kind === "series" ? switches ? "설치 후 전역 전환" : "설치만 · 전역 유지" : item.kind === "major" ? "호환성 확인 필요 · 앱에서 검토" : item.kind === "mise" ? "앱에서 확인 후 업데이트" : "플러그인 소스 갱신"}</small></div>
			<button class="mini-btn" aria-label={`${item.label} ${item.to} ${item.kind === "series" ? "설치" : item.kind === "plugin" ? "업데이트" : "검토"}`} disabled={!connection.ready || connection.sending || state.busy || state.updateCheckRunning} onclick={() => void dispatch({ type: "apply", id: item.id })}>{item.kind === "series" ? switches ? "설치·전환" : "설치" : item.kind === "plugin" ? "업데이트" : "검토…"}</button>
		</div>
	{/each}
</div>
