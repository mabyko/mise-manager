<script lang="ts">
	import appIcon from "../assets/app-icon.png";
	import { state, setBusy } from "../core/state.svelte";
	import { getMiseStatusSnapshot, normalizeVersionToken } from "../core/miseStatus";
	import {
		checkLatestMiseRelease,
		checkMiseInstallationStatus,
		loadPlatform,
		reloadMiseVersion,
	} from "../features/mise";
	import { ensureUpdaterData } from "../features/updater";
	import { reloadPluginDefinitions } from "../features/installs";

	const status = $derived(getMiseStatusSnapshot(state));
	const currentVersion = $derived(normalizeVersionToken(state.miseVersion) ?? "–");
	const latestVersion = $derived(normalizeVersionToken(state.miseLatestVersion));
	const hasUpdate = $derived(status.key === "update_available");

	function openOverview(): void {
		state.activeTab = "overview";
		ensureUpdaterData();
	}

	function openMiseTab(): void {
		state.activeTab = "mise";
		void (async () => {
			if (state.platform === "unknown") {
				await loadPlatform();
			}
			if (!state.miseInstalledChecked) {
				await checkMiseInstallationStatus();
			}
			if (state.miseIsInstalled && (!state.miseLoaded || !state.miseLatestLoaded)) {
				await reloadMiseVersion();
				await checkLatestMiseRelease();
			}
		})();
	}

	function openUpdaterTab(): void {
		state.activeTab = "updater";
		ensureUpdaterData();
	}

	function openInstallsTab(): void {
		state.activeTab = "installs";
		if (!state.installsLoaded) {
			void reloadPluginDefinitions();
		}
	}

	function notifySettingsPending(): void {
		if (!state.busy) {
			setBusy(false, "설정 화면은 준비 중입니다 ⚙");
		}
	}
</script>

<aside class="sidebar">
	<div class="brand"><img class="brand-ico" src={appIcon} alt="" /><span class="lbl">Mise Manager</span></div>
	<nav>
		<button class:on={state.activeTab === "overview"} onclick={openOverview}>
			<span class="ico">⌂</span><span class="lbl">Overview</span>
		</button>
		<button class:on={state.activeTab === "mise"} onclick={openMiseTab}>
			<span class="ico">◉</span><span class="lbl">Mise Version</span>
			{#if hasUpdate}<span class="cnt">!</span>{/if}
		</button>
		<button class:on={state.activeTab === "updater"} onclick={openUpdaterTab}>
			<span class="ico">⇅</span><span class="lbl">Plugins Updater</span>
			{#if state.plugins.length > 0}<span class="cnt">{state.plugins.length}</span>{/if}
		</button>
		<button class:on={state.activeTab === "installs"} onclick={openInstallsTab}>
			<span class="ico">＋</span><span class="lbl">Plugin Installs</span>
		</button>
		<button class:on={state.activeTab === "logs"} onclick={() => (state.activeTab = "logs")}>
			<span class="ico">≡</span><span class="lbl">Logs</span>
			{#if state.logs.length > 0}<span class="cnt">{state.logs.length}</span>{/if}
		</button>
	</nav>
	<div class="side-foot">
		<button
			class="foot-item"
			title="Settings — 준비 중"
			aria-label="Settings"
			onclick={notifySettingsPending}
		>
			<span class="ico">⚙</span>
			<span class="lbl">mise <span class="v">{currentVersion}</span></span>
			{#if hasUpdate}
				<span class="foot-dot" title="mise {currentVersion} → {latestVersion} Update Available"></span>
			{/if}
		</button>
	</div>
</aside>
