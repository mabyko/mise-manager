<script lang="ts">
	import { openUrl } from "@tauri-apps/plugin-opener";

	import { state } from "../core/state.svelte";
	import { getMiseStatusSnapshot } from "../core/miseStatus";
	import {
		checkLatestMiseRelease,
		openMiseUpdateDialog,
		reloadMiseVersion,
		startMiseInstall,
	} from "../features/mise";

	const MISE_OFFICIAL_URL = "https://mise.jdx.dev/getting-started.html";
	const visitOfficialSite = () => void openUrl(MISE_OFFICIAL_URL);

	const status = $derived(getMiseStatusSnapshot(state));
	const current = $derived(
		state.miseCurrentError
			? `Error: ${state.miseCurrentError}`
			: state.miseLoaded
				? (state.miseVersion ?? "Unknown")
				: "Not loaded",
	);
	const latest = $derived(
		state.miseLatestError
			? `Error: ${state.miseLatestError}`
			: state.miseLatestLoaded
				? (state.miseLatestVersion ?? "Unknown")
				: "Not checked",
	);
	const checkedAt = $derived(state.miseLatestCheckedAt ?? "Not checked");
	const isWindows = $derived(state.platform === "win32");
	const isMac = $derived(state.platform === "darwin");
</script>

<div class="page-head">
	<div><h1>mise 관리</h1><p class="page-subtitle">mise 자체 버전과 설치 상태, 실행 기록</p></div>
	<div class="page-actions">
		<button class="btn" onclick={() => void reloadMiseVersion()} disabled={state.busy}>현재 버전 확인</button>
		<button class="btn" onclick={() => void checkLatestMiseRelease()} disabled={state.busy}>최신 버전 확인</button>
		<button class="btn primary" onclick={openMiseUpdateDialog} title={status.buttonHint} disabled={state.busy || !status.canUpdate}>mise 업데이트…</button>
	</div>
</div>

{#snippet card(title: string, value: string, hint: string)}
	<div class="mise-summary-card">
		<div class="mise-summary-title">{title}</div>
		<div class="mise-summary-value">{value}</div>
		{#if hint}<div class="mise-summary-hint">{hint}</div>{/if}
	</div>
{/snippet}

{#if state.miseInstalledChecked && !state.miseIsInstalled}
	<section class="panel">
		<div class="panel-header">
			<div>
				<h2>mise를 찾지 못했습니다</h2>
				<p>
					mise가 설치되어 있지 않습니다.{#if isWindows}<br />Windows에서는 공식 사이트에서 설치 방법을 확인하세요.{:else if isMac}<br />아래 방법 중 하나로 설치할 수 있습니다.{/if}
				</p>
			</div>
		</div>
		{#if isWindows}
			<div style="margin-top: 16px;">
				<button class="primary-btn" onclick={visitOfficialSite}>공식 설치 안내</button>
			</div>
		{:else if state.miseInstalling}
			<div class="log-card" style="margin-top: 12px;">
				<strong>Installing mise...</strong>
				{#if state.miseLastResult}<pre>{state.miseLastResult}</pre>{/if}
			</div>
		{:else if isMac}
			<div style="margin-top: 16px; display: flex; gap: 8px; flex-wrap: wrap;">
				<button class="primary-btn" onclick={() => void startMiseInstall("sh")}>
					Quick Install (sh)
				</button>
				<button class="primary-btn" onclick={() => void startMiseInstall("brew")}>
					Homebrew Install
				</button>
				<button class="mini-btn" onclick={visitOfficialSite}>공식 설치 안내</button>
			</div>
			<div class="log-card" style="margin-top: 12px;">
				<strong>Quick Install (sh):</strong> <code>curl https://mise.run | sh</code><br />
				<strong>Homebrew:</strong> <code>brew install mise</code>
			</div>
		{:else}
			<div style="margin-top: 16px;">
				<button class="primary-btn" onclick={visitOfficialSite}>공식 설치 안내</button>
			</div>
		{/if}
	</section>
{/if}

<section class="panel">
	<div class="panel-header">
		<div>
			<h2>버전 상태</h2>
			<p>
				현재 설치된 mise 버전과 GitHub 최신 릴리스를 비교합니다.
				업데이트는 <code>mise self-update -y</code>로 실행됩니다.
			</p>
		</div>
	</div>
	<div class="mise-summary-grid">
		{@render card("현재 버전", current, "local: mise --version")}
		{@render card("최신 릴리스", latest, "GitHub latest release")}
		{@render card("상태", status.label, checkedAt)}
	</div>
	<div class="mise-status-note" style="margin-top: 12px;">
		<strong>상태 안내:</strong> {status.description}
	</div>
	{#if state.miseNeedsReload}
		<div class="log-card" style="margin-top: 12px;"><strong>업데이트가 적용되었습니다.</strong> 앱을 재시작하거나 화면을 다시 로드해 새 환경을 반영하세요.</div>
	{/if}
	{#if state.miseLastResult}
		<div class="log-card" style="margin-top: 12px;"><pre>{state.miseLastResult}</pre></div>
	{/if}
</section>
