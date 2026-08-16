<script lang="ts">
	import { state } from "../core/state.svelte";
	import { cancelMiseUpdateDialog, confirmMiseSelfUpdate } from "../features/mise";
</script>

{#if state.pendingMiseUpdateConfirm}
	<div class="modal-overlay">
		<div class="modal-card">
			<h3>Update Mise</h3>
			<p>
				<code>mise self-update -y</code>를 실행합니다.<br />
				설치 방식에 따라 실패할 수 있으며 실행 후 재시작이 필요할 수 있습니다.
			</p>
			<div class="modal-actions">
				<button class="mini-btn" onclick={cancelMiseUpdateDialog}>Cancel</button>
				<button class="mini-btn" disabled={state.busy} onclick={() => void confirmMiseSelfUpdate()}>Run Update</button>
			</div>
		</div>
	</div>
{/if}
