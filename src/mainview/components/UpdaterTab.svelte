<script lang="ts">
	import { state } from "../core/state.svelte";
	import { reloadPlugins } from "../core/app";
	import { resolveBaseVersion } from "../core/helpers";
	import type { PluginRow } from "../core/types";
	import { checkUpdates, runTargetAction, useInstalledVersion } from "../features/updater";

	type CandidateKind = "same major" | "release" | "pre-release";
	interface Candidate {
		version: string;
		kind: CandidateKind;
		mode: "same" | "release" | "latest";
	}

	// One candidate line per distinct actionable version — versions equal to the
	// active global are noise (they'd only render a disabled Install) and are skipped.
	function candidatesFor(plugin: PluginRow): Candidate[] {
		const active = plugin.activeGlobalVersion;
		const seen = new Set<string>();
		const out: Candidate[] = [];
		const push = (version: string | null, kind: CandidateKind, mode: Candidate["mode"]) => {
			if (!version || version === active || seen.has(version)) {
				return;
			}
			seen.add(version);
			out.push({ version, kind, mode });
		};
		push(plugin.sameMajorLatest, "same major", "same");
		push(plugin.releaseLatest, "release", "release");
		push(plugin.overallLatest, "pre-release", "latest");
		return out;
	}
</script>

<div class="page-head">
	<h1>Plugins Updater</h1>
	<div class="page-actions">
		<button class="btn" onclick={() => void reloadPlugins()} disabled={state.busy}>Reload Plugins</button>
		<button class="btn primary" onclick={() => void checkUpdates()} disabled={state.busy || state.plugins.length === 0}>Check Updates</button>
	</div>
</div>

<section class="panel">
	<section class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>Plugin</th>
					<th>Installed Versions</th>
					<th>Active (Global)</th>
					<th>Updates</th>
				</tr>
			</thead>
			<tbody>
				{#each state.plugins as plugin (plugin.name)}
					{@const candidates = candidatesFor(plugin)}
					<tr>
						<td class="plugin">
							<div>{plugin.name}</div>
							{#if plugin.status !== "done" && plugin.status !== "idle"}
								<div class="row-status"><span class="status {plugin.status === 'error' ? 'status-error' : plugin.status}">{plugin.status}</span></div>
							{/if}
							{#if plugin.error}
								<div class="version-meta row-error">{plugin.error}</div>
							{/if}
						</td>
						<td>
							{#if plugin.installedVersions.length === 0}
								<div class="version-meta">No installed versions</div>
							{:else}
								{#each plugin.installedVersions as version (version)}
									{@const isActive = version === plugin.activeGlobalVersion}
									<div class="installed-item">
										<span class="badge {isActive ? 'same' : 'newer'}">{version}</span>
										{#if !isActive}
											<div class="cell-actions">
												<button
													class="mini-btn"
													disabled={state.busy}
													onclick={() => void useInstalledVersion(plugin.name, version)}
												>Use Global</button>
												<button
													class="mini-btn danger"
													disabled={state.busy}
													onclick={() => (state.pendingDelete = { pluginName: plugin.name, version })}
												>Delete</button>
											</div>
										{/if}
									</div>
								{/each}
							{/if}
						</td>
						<td>
							{#if plugin.activeGlobalVersion}
								<span class="badge same">{plugin.activeGlobalVersion}</span>
							{:else}
								<span class="badge empty">N/A</span>
							{/if}
						</td>
						<td>
							{#if candidates.length === 0}
								<span class="version-meta">{plugin.status === "done" ? "Up to date ✓" : "—"}</span>
							{:else}
								{#each candidates as candidate (candidate.version)}
									<div class="cand">
										<span class="badge newer">{candidate.version}</span>
										<span class="cand-tag">{candidate.kind}</span>
										{#if plugin.installedVersions.includes(candidate.version)}
											<span class="version-state state-installed">Installed</span>
										{:else}
											<button
												class="mini-btn"
												disabled={state.busy}
												onclick={() => void runTargetAction(plugin.name, candidate.mode, "install")}
											>Install</button>
										{/if}
									</div>
								{/each}
							{/if}
						</td>
					</tr>
				{:else}
					<tr><td colspan="4" class="empty-row">설치된 플러그인을 찾지 못했습니다.</td></tr>
				{/each}
			</tbody>
		</table>
	</section>
</section>
