<script lang="ts">
	import { tick, onMount } from "svelte";
	import { state as appState } from "./core/state.svelte";
	import { handleNativeInputShortcutFallback } from "./core/inputShortcuts";
	import Sidebar from "./components/Sidebar.svelte";
	import StatusBar from "./components/StatusBar.svelte";
	import MiseTab from "./components/MiseTab.svelte";
	import UpdaterTab from "./components/UpdaterTab.svelte";
	import InstallsTab from "./components/InstallsTab.svelte";
	import LogsTab from "./components/LogsTab.svelte";
	import DeleteDialog from "./components/DeleteDialog.svelte";
	import PluginUrlDialog from "./components/PluginUrlDialog.svelte";
	import MiseUpdateDialog from "./components/MiseUpdateDialog.svelte";
	import MajorUpdateDialog from "./components/MajorUpdateDialog.svelte";
	import SettingsTab from "./components/SettingsTab.svelte";
	import { settings } from "./core/settings.svelte";
	import { checkAllUpdates } from "./features/updates";
	import UpdatesTab from "./components/UpdatesTab.svelte";
	import TrayApp from "./components/TrayApp.svelte";
	import { isTray, connectRuntime, runtimeSnapshot, publishRuntime, connection } from "./core/runtime.svelte";
	let runtimeReady = $state(false);
	onMount(() => {
		let disposed = false;
		let disconnect: (() => void) | undefined;
		void connectRuntime().then(cleanup => { if (disposed) cleanup(); else { disconnect = cleanup; runtimeReady = true; } }).catch(error => connection.error = String(error));
		return () => { disposed = true; disconnect?.(); };
	});
	$effect(() => {
		if (!isTray && runtimeReady) void publishRuntime(runtimeSnapshot()).catch(error => connection.error = String(error));
	});

	$effect(() => {
		const theme = settings.theme;
		const media = window.matchMedia("(prefers-color-scheme: dark)");
		const apply = () => { document.documentElement.dataset.theme = theme === "system" ? (media.matches ? "dark" : "light") : theme; };
		apply();
		media.addEventListener("change", apply);
		return () => media.removeEventListener("change", apply);
	});

	$effect(() => {
		const hours = settings.checkIntervalHours;
		if (isTray || !hours) return;
		const timer = setInterval(() => void checkAllUpdates(), hours * 3_600_000);
		return () => clearInterval(timer);
	});

	let content = $state<HTMLElement>();
	$effect(() => {
		const tab = appState.activeTab;
		void tick().then(() => {
			if (appState.activeTab !== tab) return;
			const heading = content?.querySelector('h1');
			heading?.setAttribute('tabindex', '-1');
			heading?.focus();
		});
	});
</script>

<svelte:window onkeydown={handleNativeInputShortcutFallback} />

{#if isTray}<TrayApp />{:else}
<div class="shell">
	<Sidebar />
	<main class="content" bind:this={content}>
		{#if appState.activeTab === "mise"}
			<MiseTab />
		{:else if appState.activeTab === "updater"}
			<UpdaterTab />
		{:else if appState.activeTab === "updates"}
			<UpdatesTab />
		{:else if appState.activeTab === "logs"}
			<LogsTab />
		{:else if appState.activeTab === "settings"}
			<SettingsTab />
		{:else}
			<InstallsTab />
		{/if}
	</main>
</div>
<StatusBar />
<DeleteDialog />
<PluginUrlDialog />
<MiseUpdateDialog />
<MajorUpdateDialog />
{/if}
