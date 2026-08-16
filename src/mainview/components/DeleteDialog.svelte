<script lang="ts">
	import { state } from "../core/state.svelte";
	import { confirmDeleteInstalledVersion } from "../features/updater";

	// Escape closes; Enter deliberately does nothing on a destructive confirm.
	function handleKeydown(event: KeyboardEvent) {
		if (state.pendingDelete && event.key === "Escape") {
			state.pendingDelete = null;
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if state.pendingDelete}
	<div class="modal-overlay">
		<div class="modal-card">
			<h3>Delete Installed Version</h3>
			<p>
				{state.pendingDelete.pluginName}@{state.pendingDelete.version} 를 삭제할까요?
				이 작업은 되돌릴 수 없습니다.
			</p>
			<div class="modal-actions">
				<button class="mini-btn" onclick={() => (state.pendingDelete = null)}>Cancel</button>
				<button class="mini-btn danger" onclick={() => void confirmDeleteInstalledVersion()}>Delete</button>
			</div>
		</div>
	</div>
{/if}
