<script lang="ts">
	import { state } from "../core/state.svelte";
	import { getMiseStatusSnapshot } from "../core/miseStatus";
	import { reloadPlugins } from "../core/app";
	import {
		checkLatestMiseRelease,
		openMiseUpdateDialog,
		reloadMiseVersion,
	} from "../features/mise";
	import { checkUpdates } from "../features/updater";
	import { openCustomPluginDialog, reloadPluginDefinitions } from "../features/installs";
	import { clearLogs } from "../features/logs";

	const status = $derived(getMiseStatusSnapshot(state));
</script>

{#if state.activeTab === "mise"}
	<div class="header-context">
		<div>
			<h1>Mise Version</h1>
			<p>현재 설치 버전과 GitHub 최신 릴리스를 확인하고 mise 자체 업데이트를 실행합니다.</p>
		</div>
		<div class="header-actions">
			<button onclick={() => void reloadMiseVersion()} disabled={state.busy}>Reload Current</button>
			<button onclick={() => void checkLatestMiseRelease()} disabled={state.busy}>Check Latest</button>
			<button
				onclick={openMiseUpdateDialog}
				title={status.buttonHint}
				disabled={state.busy || !status.canUpdate}
			>Update Mise</button>
		</div>
		<div class="header-meta">Status: {status.label} / {status.description}</div>
	</div>
{:else if state.activeTab === "installs"}
	<div class="header-context">
		<div>
			<h1>Plugin Installs</h1>
			<p>plugin 정의를 검색하고 설치/제거합니다.</p>
		</div>
		<div class="header-actions">
			<input
				class="search-input"
				placeholder="Search plugin name..."
				bind:value={state.pluginSearchQuery}
				disabled={state.busy}
			/>
			<button onclick={openCustomPluginDialog} disabled={state.busy}>Install Custom Plugin</button>
			<button
				class="icon-btn"
				title="Reload Plugins"
				aria-label="Reload Plugins"
				onclick={() => void reloadPluginDefinitions()}
				disabled={state.busy}
			>↻</button>
		</div>
		<div class="header-meta">Remote Plugin Definitions: {state.remotePluginNames.length} / Core Plugins: {state.corePluginNames.length} / User Plugins: {state.installedPluginNames.length} / Installed Tools: {state.installedToolNames.length}</div>
	</div>
{:else if state.activeTab === "updater"}
	<div class="header-context">
		<div>
			<h1>Mise Plugins Updater</h1>
			<p>Active(Global), Installed 버전, 업데이트 후보를 한 화면에서 관리합니다.</p>
		</div>
		<div class="header-actions">
			<button onclick={() => void reloadPlugins()} disabled={state.busy}>Reload Plugins</button>
			<button onclick={() => void checkUpdates()} disabled={state.busy || state.plugins.length === 0}>Check Updates</button>
		</div>
		<div class="header-meta">검사 기준: 현재 전역(Active Global) 버전 / Pre-release Latest는 조건 충족 시에만 표시</div>
	</div>
{:else}
	<div class="header-context">
		<div>
			<h1>Logs</h1>
			<p>최근 작업 내역과 오류 메시지를 확인합니다.</p>
		</div>
		<div class="header-actions">
			<button onclick={clearLogs} disabled={state.busy}>Clear Logs</button>
		</div>
	</div>
{/if}
