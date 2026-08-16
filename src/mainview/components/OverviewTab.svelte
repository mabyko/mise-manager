<script lang="ts">
	import { onMount } from "svelte";

	import { state } from "../core/state.svelte";
	import { getMiseStatusSnapshot, normalizeVersionToken } from "../core/miseStatus";
	import { buildOverviewRows } from "../core/overview";
	import { openMiseUpdateDialog } from "../features/mise";
	import {
		checkUpdates,
		ensureUpdaterData,
		requestMajorUpdate,
		retryCheck,
		updateToVersion,
	} from "../features/updater";

	onMount(ensureUpdaterData);

	const status = $derived(getMiseStatusSnapshot(state));
	const current = $derived(normalizeVersionToken(state.miseVersion));
	const latest = $derived(normalizeVersionToken(state.miseLatestVersion));
	const rows = $derived(buildOverviewRows(state.plugins));
	const updatable = $derived(rows.filter((row) => row.primary || row.major).length);
	const errorCount = $derived(state.plugins.filter((p) => p.status === "error").length);
	const checkedCount = $derived(state.plugins.filter((p) => p.status === "done").length);
	// Logs carry a long localized timestamp prefix — the activity card shows just the message.
	const recentLines = $derived(
		state.logs.slice(0, 5).map((line) => line.replace(/^\[[^\]]*\]\s*/, "")),
	);
</script>

<div class="page-head">
	<h1>Overview</h1>
	<div class="page-actions">
		<button class="btn" onclick={() => void checkUpdates()} disabled={state.busy || state.plugins.length === 0}>Check Updates</button>
		<button class="btn primary" onclick={openMiseUpdateDialog} title={status.buttonHint} disabled={state.busy || !status.canUpdate}>Update Mise…</button>
	</div>
</div>

<div class="stat-grid">
	<div class="panel stat">
		<div class="k">Mise Runtime</div>
		<div class="v">{current ?? "–"}{#if status.key === "update_available"} <span class="pill up">→ {latest}</span>{/if}</div>
		<div class="h">{status.label} · {state.miseLatestCheckedAt ?? "최신 릴리스 미확인"}</div>
	</div>
	<div class="panel stat">
		<div class="k">Plugins</div>
		<div class="v">{state.plugins.length} <span class="v-sub">installed</span></div>
		<div class="h">{checkedCount} checked{errorCount > 0 ? ` · ${errorCount} error` : ""}</div>
	</div>
	<div class="panel stat">
		<div class="k">Updates Available</div>
		<div class="v accent">{updatable}</div>
		<div class="h">
			{#if state.busy}{state.progressLabel}{#if state.progress !== null} · {Math.round(state.progress)}%{/if}{:else}install 가능한 후보{/if}
		</div>
	</div>
</div>

<div class="cols2">
	<div class="panel">
		<div class="k" style="margin-bottom: 6px;">Available Updates</div>
		{#if rows.length === 0}
			<div class="empty-note">
				{state.plugins.length === 0 ? "플러그인을 불러오는 중이거나 설치된 플러그인이 없습니다." : "모든 플러그인이 최신입니다 ✓"}
			</div>
		{:else}
			<table class="ov-table">
				<tbody>
					{#each rows as row (row.plugin)}
						<tr>
							<td class="plugin"><span class="dot {row.error ? 'err' : 'ok'}"></span>{row.plugin}</td>
							{#if row.error}
								<td class="ov-error">{row.error}</td>
								<td class="ov-actions">
									<button class="mini-btn" disabled={state.busy} onclick={() => void retryCheck(row.plugin)}>Retry</button>
								</td>
							{:else}
								<td>{#if row.current}<span class="chip active">{row.current}</span>{/if}</td>
								<td class="ov-actions">
									{#if row.primary}
										<button
											class="upbtn"
											disabled={state.busy}
											title="{row.primary} 설치 후 전역(Use Global) 전환"
											onclick={() => void updateToVersion(row.plugin, row.primary!)}
										><span class="l">Update to {row.primary}</span><span class="s">{row.primary}</span></button>
									{/if}
									{#if row.major}
										<button
											class="ghostbtn"
											disabled={state.busy}
											title="Major 업데이트 — 확인 후 설치 + 전역 전환"
											onclick={() => requestMajorUpdate(row.plugin, row.major!)}
										><span class="l">Update to {row.major} (major)…</span><span class="s">{row.major} major…</span></button>
									{/if}
								</td>
							{/if}
						</tr>
					{/each}
				</tbody>
			</table>
			<div class="ov-caption">Update = 설치 후 전역(Use Global) 전환 · 이전 버전은 삭제되지 않아 언제든 되돌릴 수 있습니다</div>
		{/if}
	</div>
	<div class="panel">
		<div class="k" style="margin-bottom: 8px;">Recent Activity</div>
		{#if state.logs.length === 0}
			<div class="empty-note">로그가 없습니다.</div>
		{:else}
			<div class="activity">
				{#each recentLines as line, index (index)}
					<div class="act-line">{line}</div>
				{/each}
			</div>
		{/if}
		<button class="mini-btn" style="margin-top: 8px;" onclick={() => (state.activeTab = "logs")}>View all logs →</button>
	</div>
</div>
