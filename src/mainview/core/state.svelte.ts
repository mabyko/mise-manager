import type { MainViewState } from "./types";

export const checkModeActiveOnly = true;

export const state: MainViewState = $state({
	activeTab: "mise",
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
	liveOutputLine: "",
	pendingDelete: null,
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

export function setBusy(
	nextBusy: boolean,
	nextLabel = "Ready",
	nextProgress: number | null = null,
): void {
	if (nextBusy) {
		state.liveOutputLine = "";
	}
	state.busy = nextBusy;
	state.progressLabel = nextLabel;
	state.progress = nextProgress;
}
