<script lang="ts">
	import appIcon from "../assets/app-icon.png";
	import { state as appState } from "../core/state.svelte";
	import { connection, dispatch, hideTray, quitApp } from "../core/runtime.svelte";
	import { getUpdateSummary } from "../core/updateSummary";
	import { getInstalledSeries, getToolStatus } from "../core/toolStatus";
	import UpdateList from "./UpdateList.svelte";
	let onlyUpdates = $state(false);
	const summary = $derived(getUpdateSummary(appState));
	const disabled = $derived(!connection.ready || connection.sending || appState.busy || appState.updateCheckRunning);
</script>

<svelte:window onkeydown={event => { if (event.key === "Escape") void hideTray(); }} />
<div class="tray-shell">
	<header class="tray-header"><div class="brand"><img class="brand-ico" src={appIcon} alt="" />Mise Manager</div><button class="text-btn" aria-label="설정 열기" onclick={() => void dispatch({ type: "open", tab: "settings" })}>⚙</button></header>
	<nav class="tray-tabs" aria-label="빠른 관리"><button class:chosen={!onlyUpdates} aria-pressed={!onlyUpdates} onclick={() => onlyUpdates = false}>내 도구</button><button class:chosen={onlyUpdates} aria-pressed={onlyUpdates} onclick={() => onlyUpdates = true}>업데이트 <b>{appState.busy || appState.updateCheckRunning ? "…" : summary.items.length}</b></button><button class="text-btn tray-refresh" disabled={disabled || !appState.miseIsInstalled} onclick={() => void dispatch({ type: "check" })} aria-label="전체 업데이트 확인">↻</button></nav>
	<main class="tray-content">
		{#if !connection.ready}<div class="empty-detail"><h2>앱에 연결하는 중…</h2><p>앱 창이 열리면 도구 목록이 표시됩니다.</p></div>
		{:else}
			{#if summary.attention}<button class="tray-attention" onclick={() => void dispatch({ type: "open", tab: "updates" })}>{appState.busy || appState.updateCheckRunning ? appState.progressLabel : summary.errors.length ? "일부 확인 실패 · 앱에서 확인 →" : "미확인 항목 있음 · 앱에서 확인 →"}</button>{/if}
			{#if onlyUpdates}<UpdateList items={summary.items} />
				{#if !summary.items.length}<p class="tray-empty">{summary.attention ? "아직 확인된 업데이트가 없습니다." : "확인된 업데이트가 없습니다."}</p>{/if}
			{:else}
				{#each appState.plugins as tool (tool.name)}
					{@const updates = summary.items.filter(item => item.name === tool.name && (item.kind === "series" || item.kind === "major"))}
					{#if updates.length}<UpdateList items={updates} />{/if}
					{#each getInstalledSeries(tool).filter(series => !updates.some(item => item.to === series.update)) as series (series.major)}
						<div class="update-row"><span class="tool-glyph mark-{tool.name}" aria-hidden="true">{tool.name.slice(0, 2)}</span><div class="update-info"><strong>{tool.name} {series.major}.x</strong><span class="mono">{series.current}</span></div><span class="subtle">{series.latest ? "설치됨" : getToolStatus(tool)}</span></div>
					{/each}
					<details class="tray-versions"><summary>{tool.name} 버전 관리 <span class="mono">전역 {tool.activeGlobalVersion ?? "미선택"}</span></summary>
						{#each tool.installedVersions as version}<div class="installed-version"><span class="mono">{version}</span>{#if tool.activeGlobalVersion === version}<span class="subtle">사용 중</span>{:else}<button class="mini-btn" disabled={disabled} onclick={() => void dispatch({ type: "use", name: tool.name, version })}>전역으로 사용</button>{/if}</div>{/each}
						<button class="text-btn" onclick={() => void dispatch({ type: "open", tab: "updater", name: tool.name })}>앱에서 자세히 보기 →</button>
					</details>
				{:else}<p class="tray-empty">{appState.toolsLoaded ? "설치된 도구가 없습니다." : "도구를 불러오는 중…"}</p>{/each}
				<h2 class="rail-label">mise · 플러그인</h2><UpdateList items={summary.items.filter(item => item.kind === "mise" || item.kind === "plugin")} />
				{#if !summary.items.some(item => item.kind === "mise")}<button class="tray-mise" onclick={() => void dispatch({ type: "open", tab: "mise" })}><strong>mise</strong><span class="mono">{appState.miseVersion ?? "미확인"}</span><span>관리 →</span></button>{/if}
			{/if}
			{#if appState.pluginUpdateResult}<p class="tray-result" role="status">{appState.pluginUpdateResult}</p>{/if}
		{/if}
	</main>
	<footer class="tray-footer"><div role="status">{#if appState.busy || appState.updateCheckRunning}<span class="spinner" aria-hidden="true"></span>{/if}<span>{appState.busy || appState.updateCheckRunning ? appState.progressLabel : connection.error || (appState.toolsCheckedAt ? `${appState.toolsCheckedAt} 도구 확인` : "업데이트 확인 전")}</span></div><div class="tray-actions"><button class="text-btn" onclick={() => void quitApp()}>종료</button><button class="text-btn" onclick={() => void dispatch({ type: "open", tab: "updates" })}>앱 열기 ↗</button></div></footer>
</div>
