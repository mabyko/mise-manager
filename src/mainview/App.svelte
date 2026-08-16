<script lang="ts">
	import { state } from "./core/state.svelte";
	import { handleNativeInputShortcutFallback } from "./core/inputShortcuts";
	import Sidebar from "./components/Sidebar.svelte";
	import StatusBar from "./components/StatusBar.svelte";
	import OverviewTab from "./components/OverviewTab.svelte";
	import MiseTab from "./components/MiseTab.svelte";
	import UpdaterTab from "./components/UpdaterTab.svelte";
	import InstallsTab from "./components/InstallsTab.svelte";
	import LogsTab from "./components/LogsTab.svelte";
	import DeleteDialog from "./components/DeleteDialog.svelte";
	import PluginUrlDialog from "./components/PluginUrlDialog.svelte";
	import MiseUpdateDialog from "./components/MiseUpdateDialog.svelte";
	import MajorUpdateDialog from "./components/MajorUpdateDialog.svelte";
</script>

<svelte:window onkeydown={handleNativeInputShortcutFallback} />

<div class="shell">
	<Sidebar />
	<main class="content">
		{#if state.activeTab === "overview"}
			<OverviewTab />
		{:else if state.activeTab === "mise"}
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
