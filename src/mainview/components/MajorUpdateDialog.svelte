<script lang="ts">
	import { state } from "../core/state.svelte";
	import { modal } from "../core/dialog";
	import { confirmMajorUpdate } from "../features/updater";
</script>

{#if state.pendingMajorUpdate}
	<dialog class="modal-card" use:modal oncancel={() => (state.pendingMajorUpdate = null)} aria-labelledby="major-dialog-title">
		<span class="eyebrow">새 major · 호환성 확인 필요</span>
		<h2 id="major-dialog-title">{state.pendingMajorUpdate.pluginName}의 새 major로 전환할까요?</h2>
		<p class="dialog-version mono">{state.pendingMajorUpdate.fromVersion ?? "전역 미선택"} → {state.pendingMajorUpdate.targetVersion}</p>
		<p>설치 후 전역 버전을 전환합니다. 프로젝트가 새 major를 지원하는지 확인하세요. 프로젝트별 mise 설정이 있으면 그 설정이 우선합니다.</p>
		<p>기존 버전은 보관됩니다. 내 도구에서 이전 버전을 다시 선택할 수 있습니다.</p>
		<div class="modal-actions"><button class="btn" onclick={() => (state.pendingMajorUpdate = null)}>취소</button><button class="btn primary" disabled={state.busy} onclick={() => void confirmMajorUpdate()}>설치 후 전역 전환</button></div>
	</dialog>
{/if}
