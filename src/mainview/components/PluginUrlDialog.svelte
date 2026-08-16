<script lang="ts">
	import { state } from "../core/state.svelte";
	import { closePluginUrlDialog, submitPluginUrlDialog } from "../features/installs";

	const dialog = $derived(state.pendingPluginUrlDialog);
	const isEdit = $derived(dialog?.mode === "edit");
	const isCustomInstall = $derived(dialog?.mode === "custom-install");
	const title = $derived(
		isCustomInstall ? "Install Custom Plugin" : isEdit ? "Edit Plugin URL" : "Install Plugin",
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

	function focusOnMount(node: HTMLElement, enabled: boolean = true) {
		if (enabled) {
			node.focus();
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (!state.pendingPluginUrlDialog) {
			return;
		}
		if (event.key === "Escape") {
			closePluginUrlDialog();
		} else if (event.key === "Enter" && !state.busy) {
			event.preventDefault();
			void submitPluginUrlDialog();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if dialog}
	<div class="modal-overlay">
		<div class="modal-card">
			<h3>{title}</h3>
			<p>
				{#if !isCustomInstall}Plugin: <strong>{pluginName}</strong><br />{/if}
				{description}
			</p>
			{#if isCustomInstall}
				<input
					class="modal-input"
					placeholder="Plugin name"
					bind:value={state.pendingPluginNameValue}
					use:focusOnMount
				/>
			{/if}
			<input
				class="modal-input"
				placeholder={urlPlaceholder}
				bind:value={state.pendingPluginUrlValue}
				use:focusOnMount={!isCustomInstall}
			/>
			<div class="modal-actions">
				<button class="mini-btn" onclick={closePluginUrlDialog}>Cancel</button>
				<button class="mini-btn" disabled={state.busy} onclick={() => void submitPluginUrlDialog()}>
					{isEdit ? "Save URL" : "Install"}
				</button>
			</div>
		</div>
	</div>
{/if}
