<script lang="ts">
	import { state } from "../core/state.svelte";
	import { resolveBaseVersion } from "../core/helpers";
	import { getTargetVersion, runTargetAction, useInstalledVersion } from "../features/updater";

	const modes = ["same", "release", "latest"] as const;
</script>

<section class="panel">
	<section class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>Plugin</th>
					<th>Installed Versions</th>
					<th>Active (Global)</th>
					<th>Same Major Latest</th>
					<th>Release Latest</th>
					<th>Pre-release Latest</th>
					<th>Status</th>
				</tr>
			</thead>
			<tbody>
				{#each state.plugins as plugin (plugin.name)}
					<tr>
						<td class="plugin">
							<div>{plugin.name}</div>
						</td>
						<td>
							{#if plugin.installedVersions.length === 0}
								<div class="version-meta">No installed versions</div>
							{:else}
								{#each plugin.installedVersions as version (version)}
									{@const isActive = version === plugin.activeGlobalVersion}
									<div class="installed-item">
										<span class="badge {isActive ? 'same' : 'newer'}">{version}</span>
										<div class="cell-actions">
											<button
												class="mini-btn"
												disabled={state.busy || isActive}
												onclick={() => void useInstalledVersion(plugin.name, version)}
											>Use Global</button>
											<button
												class="mini-btn danger"
												disabled={state.busy || isActive}
												onclick={() => (state.pendingDelete = { pluginName: plugin.name, version })}
											>Delete</button>
										</div>
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
						{#each modes as mode (mode)}
							{@const target = getTargetVersion(plugin, mode)}
							<td>
								{#if !target}
									<div class="target-cell">
										<span class="badge empty">N/A</span>
										<div class="version-meta">{mode === "latest" ? "No pre-release found" : "No version found"}</div>
									</div>
								{:else}
									{@const isCurrent = target === plugin.activeGlobalVersion}
									{@const alreadyInstalled = plugin.installedVersions.includes(target)}
									{@const isBaseSame = target === resolveBaseVersion(plugin)}
									<div class="target-cell">
										<div class="target-top">
											<span class="badge {isCurrent ? 'same' : 'newer'}">{target}</span>
											<span class="version-state {isCurrent ? 'state-current' : alreadyInstalled ? 'state-installed' : 'state-new'}">{isCurrent ? "Using Global" : alreadyInstalled ? "Installed" : "NEW"}</span>
										</div>
										<div class="cell-actions">
											<button
												class="mini-btn"
												style="flex: 1;"
												disabled={state.busy || alreadyInstalled || isBaseSame}
												onclick={() => void runTargetAction(plugin.name, mode, "install")}
											>Install</button>
										</div>
									</div>
								{/if}
							</td>
						{/each}
						<td><span class="status {plugin.status === 'error' ? 'status-error' : plugin.status}">{plugin.status}</span></td>
					</tr>
				{:else}
					<tr><td colspan="7" class="empty-row">설치된 플러그인을 찾지 못했습니다.</td></tr>
				{/each}
			</tbody>
		</table>
	</section>
</section>
