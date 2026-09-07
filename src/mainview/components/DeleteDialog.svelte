<script lang="ts">
	import { state } from "../core/state.svelte";
	import { modal } from "../core/dialog";
	import { confirmDeleteInstalledVersion } from "../features/updater";
</script>

{#if state.pendingDelete}
	<dialog class="modal-card" use:modal oncancel={() => (state.pendingDelete = null)} aria-labelledby="delete-dialog-title">
		<h2 id="delete-dialog-title">설치된 버전을 삭제할까요?</h2>
		<p class="dialog-version mono">{state.pendingDelete.pluginName}@{state.pendingDelete.version}</p>
		<p>이 버전을 로컬에서 제거합니다. 프로젝트에서 사용 중인지 확인해 주세요. 다시 사용하려면 재설치해야 합니다.</p>
		<div class="modal-actions"><button class="btn" onclick={() => (state.pendingDelete = null)}>취소</button><button class="btn danger" disabled={state.busy} onclick={() => void confirmDeleteInstalledVersion()}>삭제</button></div>
	</dialog>
{/if}
