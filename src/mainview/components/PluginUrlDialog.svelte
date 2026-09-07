<script lang="ts">
	import { modal } from "../core/dialog";
	import { state } from "../core/state.svelte";
	import { closePluginUrlDialog, submitPluginUrlDialog } from "../features/installs";

	const dialog = $derived(state.pendingPluginUrlDialog);
	const isEdit = $derived(dialog?.mode === "edit");
	const isCustomInstall = $derived(dialog?.mode === "custom-install");
	const title = $derived(
		isCustomInstall ? "사용자 플러그인 추가" : isEdit ? "플러그인 URL 수정" : "플러그인 추가",
	);
	const description = $derived(
		isCustomInstall
			? "목록에 없는 plugin definition을 이름과 Git URL로 설치합니다."
			: isEdit
				? "새 URL로 plugin definition을 재설치합니다(--force)."
				: "비워두면 기본 registry source로 설치합니다.",
	);
	const pluginName = $derived(
		dialog && "pluginName" in dialog ? dialog.pluginName : state.pendingPluginNameValue,
	);
	const urlPlaceholder = $derived(
		isCustomInstall
			? "https://github.com/owner/repo.git"
			: "https://github.com/owner/repo.git (optional)",
	);
</script>


{#if dialog}
	<dialog class="modal-card" use:modal oncancel={closePluginUrlDialog} aria-labelledby="plugin-dialog-title">
		<form onsubmit={(event) => { event.preventDefault(); if (!state.busy) void submitPluginUrlDialog(); }}>
			<h2 id="plugin-dialog-title">{title}</h2>
			<p>
				{#if !isCustomInstall}Plugin: <strong>{pluginName}</strong><br />{/if}
				{description}
			</p>
			{#if isCustomInstall}
				<label class="modal-field">플러그인 이름<input
					class="modal-input"
					placeholder="Plugin name"
					bind:value={state.pendingPluginNameValue}
				/></label>
			{/if}
			<label class="modal-field">Git URL<input
				class="modal-input"
				placeholder={urlPlaceholder}
				bind:value={state.pendingPluginUrlValue}
			/></label>
			<div class="modal-actions">
				<button type="button" class="mini-btn" onclick={closePluginUrlDialog}>취소</button>
				<button type="submit" class="mini-btn primary" disabled={state.busy}>
					{isEdit ? "URL 저장" : "설치"}
				</button>
			</div>
		</form>
	</dialog>
{/if}
