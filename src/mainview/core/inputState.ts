import type { MainViewState } from "./types";

function readInputValue(root: HTMLElement, action: string): string | null {
	const input = root.querySelector(`input[data-action="${action}"]`);
	if (!input || !("value" in input) || typeof input.value !== "string") {
		return null;
	}
	return input.value;
}

export function syncDialogInputState(
	root: HTMLElement,
	state: MainViewState,
): void {
	const pluginName = readInputValue(root, "plugin-name-input");
	if (pluginName !== null) {
		state.pendingPluginNameValue = pluginName;
	}

	const pluginUrl = readInputValue(root, "plugin-url-input");
	if (pluginUrl !== null) {
		state.pendingPluginUrlValue = pluginUrl;
	}
}
