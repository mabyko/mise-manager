<script lang="ts">
	import { state } from "../core/state.svelte";
	import { confirmMajorUpdate } from "../features/updater";

	// Escape closes; Enter deliberately does nothing on a consequential confirm.
	function handleKeydown(event: KeyboardEvent) {
		if (state.pendingMajorUpdate && event.key === "Escape") {
			state.pendingMajorUpdate = null;
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if state.pendingMajorUpdate}
	<div class="modal-overlay">
		<div class="modal-card">
			<h3>{state.pendingMajorUpdate.pluginName} {state.pendingMajorUpdate.targetVersion} (Major) 로 전환</h3>
			<p>
				<b>{state.pendingMajorUpdate.fromVersion ?? "현재 버전"} → {state.pendingMajorUpdate.targetVersion}</b> 은 major 업데이트입니다.<br />
				설치 후 전역(Use Global) 버전이 즉시 전환되며, <code>.mise.toml</code>이 없는
				모든 셸/프로젝트에 적용됩니다.<br />
				기존 버전은 그대로 유지되므로 Plugins Updater에서 언제든 되돌릴 수 있습니다.
			</p>
			<div class="modal-actions">
				<button class="mini-btn" onclick={() => (state.pendingMajorUpdate = null)}>Cancel</button>
				<button class="mini-btn primary" disabled={state.busy} onclick={() => void confirmMajorUpdate()}>Install &amp; Use Global</button>
			</div>
		</div>
	</div>
{/if}
