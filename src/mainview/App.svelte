<script lang="ts">
	import { state } from "./core/state.svelte";
	import { reloadPlugins } from "./core/app";
	import { handleNativeInputShortcutFallback } from "./core/inputShortcuts";
	import {
		checkLatestMiseRelease,
		checkMiseInstallationStatus,
		loadPlatform,
		reloadMiseVersion,
	} from "./features/mise";
	import { checkUpdates } from "./features/updater";
	import { reloadPluginDefinitions } from "./features/installs";
	import HeaderContext from "./components/HeaderContext.svelte";
	import MiseTab from "./components/MiseTab.svelte";
	import UpdaterTab from "./components/UpdaterTab.svelte";
	import InstallsTab from "./components/InstallsTab.svelte";
	import LogsTab from "./components/LogsTab.svelte";
	import DeleteDialog from "./components/DeleteDialog.svelte";
	import PluginUrlDialog from "./components/PluginUrlDialog.svelte";
	import MiseUpdateDialog from "./components/MiseUpdateDialog.svelte";

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
		if (!state.updaterAutoChecked) {
			state.updaterAutoChecked = true;
			void (async () => {
				if (state.plugins.length === 0) {
					await reloadPlugins();
				}
				await checkUpdates();
			})();
		}
	}

	function openInstallsTab(): void {
		state.activeTab = "installs";
		if (!state.installsLoaded) {
			void reloadPluginDefinitions();
		}
	}
</script>

<svelte:window onkeydown={handleNativeInputShortcutFallback} />

<main>
	<div class="app-header">
		<nav class="tabs">
			<button class="tab" class:active={state.activeTab === "mise"} onclick={openMiseTab}>Mise Version</button>
			<button class="tab" class:active={state.activeTab === "installs"} onclick={openInstallsTab}>Plugin Installs</button>
			<button class="tab" class:active={state.activeTab === "updater"} onclick={openUpdaterTab}>Plugins Updater</button>
			<button class="tab" class:active={state.activeTab === "logs"} onclick={() => (state.activeTab = "logs")}>Logs</button>
		</nav>
		<HeaderContext />
		<section class="global-progress">
			<div class="progress-head">
				<strong>{state.progressLabel}</strong>
				{#if state.progress !== null}
					<span>{Math.round(state.progress)}%</span>
				{/if}
			</div>
			<div class="progress-track">
				{#if state.busy && state.progress === null}
					<div class="progress-fill indeterminate"></div>
				{:else}
					<div class="progress-fill" style:width="{Math.max(0, Math.min(100, state.progress ?? 0))}%"></div>
				{/if}
			</div>
			{#if state.busy && state.liveOutputLine}
				<div class="live-output">{state.liveOutputLine}</div>
			{/if}
		</section>
	</div>
	<section class="app-content">
		{#if state.activeTab === "mise"}
			<MiseTab />
		{:else if state.activeTab === "updater"}
			<UpdaterTab />
		{:else if state.activeTab === "logs"}
			<LogsTab />
		{:else}
			<InstallsTab />
		{/if}
	</section>
</main>
<DeleteDialog />
<PluginUrlDialog />
<MiseUpdateDialog />
