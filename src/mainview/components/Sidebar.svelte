<script lang="ts">
	import appIcon from "../assets/app-icon.png";
	import { state } from "../core/state.svelte";
	import { getMiseStatusSnapshot, normalizeVersionToken } from "../core/miseStatus";
	import { reloadPluginDefinitions } from "../features/installs";
	import type { ActiveTab } from "../core/types";

	const status = $derived(getMiseStatusSnapshot(state));
	const currentVersion = $derived(normalizeVersionToken(state.miseVersion) ?? "확인 중");
	const icons = {
		updater: "M4 7h16v13H4z M9 7V4h6v3 M4 12h16 M10 12v3h4v-3",
		installs: "M12 4v16 M4 12h16",
		logs: "m4 7 5 5-5 5 M13 17h7",
	};

	function navigate(tab: ActiveTab) {
		state.activeTab = tab;
		if (tab === "installs" && !state.installsLoaded && !state.busy) {
			void reloadPluginDefinitions();
		}
	}
</script>

<aside class="sidebar">
	<div class="brand"><img class="brand-ico" src={appIcon} alt="" /><span>Mise Manager</span></div>
	<nav aria-label="주 메뉴">
		{#each [{ tab: "updater", label: "내 도구" }, { tab: "installs", label: "플러그인 관리" }, { tab: "logs", label: "작업 기록" }] as item (item.tab)}
			<button
				class:on={state.activeTab === item.tab}
				aria-current={state.activeTab === item.tab ? "page" : undefined}
				disabled={item.tab === "installs" && state.busy && !state.installsLoaded}
				onclick={() => navigate(item.tab as ActiveTab)}
			>
				<svg class="nav-icon" viewBox="0 0 24 24" aria-hidden="true"><path d={icons[item.tab as keyof typeof icons]} /></svg>
				<span>{item.label}</span>
				{#if item.tab === "updater" && state.toolsLoaded}<span class="cnt">{state.plugins.length}</span>{/if}
			</button>
		{/each}
	</nav>
	<div class="side-foot">
		<span class="side-status"><span class="dot {state.miseCurrentError || !state.miseIsInstalled ? 'err' : 'ok'}"></span>{!state.miseInstalledChecked ? "mise 확인 중" : state.miseIsInstalled ? "mise 연결됨" : "mise 설치 필요"}</span>
		<span class="mono">{currentVersion}</span>
		<button class="foot-item" onclick={() => navigate("mise")} aria-current={state.activeTab === "mise" ? "page" : undefined}>
			{status.canUpdate ? "새 버전 있음 · 확인 →" : "mise 관리 →"}
		</button>
	</div>
</aside>
