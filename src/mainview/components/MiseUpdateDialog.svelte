<script lang="ts">
	import { state } from "../core/state.svelte";
	import { modal } from "../core/dialog";
	import { normalizeVersionToken } from "../core/miseStatus";
	import { cancelMiseUpdateDialog, confirmMiseSelfUpdate } from "../features/mise";
</script>

{#if state.pendingMiseUpdateConfirm}
	<dialog class="modal-card" use:modal oncancel={cancelMiseUpdateDialog} aria-labelledby="mise-dialog-title">
		<span class="eyebrow">mise 자체 업데이트</span>
		<h2 id="mise-dialog-title">mise를 업데이트할까요?</h2>
		<p class="dialog-version mono">{normalizeVersionToken(state.miseVersion) ?? "현재 버전"} → {normalizeVersionToken(state.miseLatestVersion) ?? "최신 버전"}</p>
		<p>mise 실행 파일을 업데이트합니다. 설치된 도구와 전역 버전 설정은 변경하지 않습니다. 설치 방식에 따라 실패할 수 있으며, 적용 후 앱 재시작이 필요할 수 있습니다.</p>
		<div class="modal-actions"><button class="btn" onclick={cancelMiseUpdateDialog}>취소</button><button class="btn primary" disabled={state.busy} onclick={() => void confirmMiseSelfUpdate()}>mise 업데이트</button></div>
	</dialog>
{/if}
