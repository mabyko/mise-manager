import { describe, expect, test } from "bun:test";
import type { MainViewState } from "./types";
import { syncDialogInputState } from "./inputState";

function makeState(): MainViewState {
	return {
		activeTab: "installs",
		miseVersion: null,
		miseLoaded: false,
		miseCurrentError: null,
		miseLatestVersion: null,
		miseLatestLoaded: false,
		miseLatestError: null,
		miseLatestCheckedAt: null,
		miseNeedsReload: false,
		miseLastResult: "",
		pendingMiseUpdateConfirm: false,
		updaterAutoChecked: false,
		plugins: [],
		logs: [],
		busy: false,
		progress: 0,
		progressLabel: "Ready",
		pendingDelete: null,
		remotePluginNames: [],
		installedPluginNames: [],
		corePluginNames: [],
		installedToolNames: [],
		remotePluginInfos: [],
		installedUserPluginInfos: [],
		pluginSearchQuery: "",
		installsLoaded: false,
		pendingPluginUrlDialog: { mode: "custom-install" },
		pendingPluginNameValue: "",
		pendingPluginUrlValue: "",
		miseInstalledChecked: false,
		miseIsInstalled: true,
		miseInstalling: false,
		miseInstallMethod: null,
		platform: "test",
	};
}

describe("syncDialogInputState", () => {
	test("syncs current dialog input DOM values into state", () => {
		const state = makeState();
		const root = {
			querySelector: (selector: string) => {
				if (selector === 'input[data-action="plugin-name-input"]') {
					return { value: "zoxide" };
				}
				if (selector === 'input[data-action="plugin-url-input"]') {
					return { value: "nyrst/asdf-zoxide.git" };
				}
				return null;
			},
		} as unknown as HTMLElement;

		syncDialogInputState(root, state);

		expect(state.pendingPluginNameValue).toBe("zoxide");
		expect(state.pendingPluginUrlValue).toBe("nyrst/asdf-zoxide.git");
	});
});
