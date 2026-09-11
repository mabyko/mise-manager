<script lang="ts">
	import appIcon from "../assets/app-icon.png";
	import { state } from "../core/state.svelte";
	import { getUpdateSummary } from "../core/updateSummary";
	import { getToolStatus, hasToolUpdates } from "../core/toolStatus";
	import { dispatch } from "../core/runtime.svelte";
	const summary = $derived(getUpdateSummary(state));
	const tools = $derived(state.plugins.filter(p => p.name.toLowerCase().includes(state.toolSearchQuery.trim().toLowerCase())));
	const selected = $derived(state.selectedToolName ?? state.plugins[0]?.name);
</script>

<aside class="sidebar">
	<div class="brand"><img class="brand-ico" src={appIcon} alt="" /><span>Mise Manager</span></div>
	<label class="sr-only" for="tool-search">도구 검색</label>
	<input id="tool-search" class="search-input" placeholder="도구 검색" bind:value={state.toolSearchQuery} />
	<nav aria-label="업데이트">
		<button class:on={state.activeTab === "updates"} aria-current={state.activeTab === "updates" ? "page" : undefined} onclick={() => state.activeTab = "updates"}><span aria-hidden="true">↓</span><span>업데이트</span><b class="cnt">{state.busy || state.updateCheckRunning ? "…" : summary.items.length || (summary.attention ? "!" : "0")}</b></button>
	</nav>
	<h2 class="rail-label">설치된 도구 <span>{state.plugins.length}</span></h2>
	<nav class="tool-list" aria-label="설치된 도구">
		{#each tools as tool (tool.name)}
			<button aria-label={`${tool.name} ${tool.activeGlobalVersion ?? "전역 미선택"} · ${getToolStatus(tool)}`} class="tool-item" class:on={state.activeTab === "updater" && selected === tool.name} aria-current={state.activeTab === "updater" && selected === tool.name ? "page" : undefined} onclick={() => { state.selectedToolName = tool.name; state.activeTab = "updater"; }}>
				<span>{tool.name}</span><span class="rail-version mono">{tool.activeGlobalVersion ?? "미선택"}</span>
				{#if hasToolUpdates(tool)}<span class="dot update-dot" aria-label="업데이트 있음"></span>
				{:else if getToolStatus(tool) !== "최신 안정 버전"}<span class="rail-state" class:error-text={tool.status === "error"}>{getToolStatus(tool)}</span>{/if}
			</button>
		{:else}<p class="subtle rail-empty">{state.toolSearchQuery ? "검색 결과가 없습니다." : state.toolsLoaded ? "설치된 도구 없음" : "불러오는 중…"}</p>{/each}
	</nav>
	<h2 class="rail-label">관리</h2>
	<nav aria-label="관리">
		{#each [{ tab: "mise", label: "mise", hint: "버전 관리자" }, { tab: "installs", label: "플러그인 관리", hint: "" }, { tab: "logs", label: "작업 기록", hint: "" }] as item}
			<button class:foot-item={item.tab === "mise"} class:on={state.activeTab === item.tab} aria-current={state.activeTab === item.tab ? "page" : undefined} disabled={item.tab === "installs" && !state.installsLoaded && (state.busy || state.updateCheckRunning)} onclick={() => void dispatch({ type: "open", tab: item.tab as "mise" | "installs" | "logs" })}><span>{item.label}</span><span class="rail-version">{item.hint}</span></button>
		{/each}
	</nav>
	<nav class="rail-bottom" aria-label="앱 설정"><button class:on={state.activeTab === "settings"} aria-current={state.activeTab === "settings" ? "page" : undefined} onclick={() => state.activeTab = "settings"}><span aria-hidden="true">⚙</span> 설정</button></nav>
</aside>
