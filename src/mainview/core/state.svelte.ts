import type { MainViewState } from "./types";

export const state: MainViewState = $state({
	activeTab: "updater",
	selectedToolName: null,
	toolSearchQuery: "",
	toolUpdatesOnly: false,
	toolsLoaded: false,
	toolsError: null,
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
	plugins: [],
	logs: [],
	busy: false,
	progress: 0,
	progressLabel: "Ready",
	liveOutputLine: "",
	pendingDelete: null,
	pendingMajorUpdate: null,
	remotePluginNames: [],
	installedPluginNames: [],
	corePluginNames: [],
	installedToolNames: [],
	remotePluginInfos: [],
	installedUserPluginInfos: [],
	pluginSearchQuery: "",
	installsLoaded: false,
	pendingPluginUrlDialog: null,
	pendingPluginNameValue: "",
	pendingPluginUrlValue: "",
	miseInstalledChecked: false,
	miseIsInstalled: true,
	miseInstalling: false,
	miseInstallMethod: null,
	platform: "unknown",
});

let statusResetTimer: ReturnType<typeof setTimeout> | undefined;

export function setBusy(
	nextBusy: boolean,
	nextLabel = "Ready",
	nextProgress: number | null = null,
): void {
	if (statusResetTimer) {
		clearTimeout(statusResetTimer);
		statusResetTimer = undefined;
	}
	if (nextBusy) {
		state.liveOutputLine = "";
	}
	state.busy = nextBusy;
	state.progressLabel = nextLabel;
	state.progress = nextProgress;

	// Completion labels ("Check complete · 100%") shouldn't linger forever.
	if (!nextBusy && nextLabel !== "Ready") {
		statusResetTimer = setTimeout(() => {
			statusResetTimer = undefined;
			if (!state.busy) {
				state.progressLabel = "Ready";
				state.progress = 0;
			}
		}, 4000);
	}
}
