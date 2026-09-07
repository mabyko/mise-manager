<script lang="ts">
	import { tick } from "svelte";
	import { state } from "./core/state.svelte";
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

	let content: HTMLElement;
	$effect(() => {
		const tab = state.activeTab;
		void tick().then(() => {
			if (state.activeTab !== tab) return;
			const heading = content?.querySelector('h1');
			heading?.setAttribute('tabindex', '-1');
			heading?.focus();
		});
	});
</script>

<svelte:window onkeydown={handleNativeInputShortcutFallback} />

<div class="shell">
	<Sidebar />
	<main class="content" bind:this={content}>
		{#if state.activeTab === "mise"}
			<MiseTab />
		{:else if state.activeTab === "updater"}
			<UpdaterTab />
		{:else if state.activeTab === "logs"}
			<LogsTab />
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
