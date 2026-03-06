import type { MainViewState } from "./types";

export const checkModeActiveOnly = true;

export const state: MainViewState = {
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
	pendingPluginUrlDialog: null,
	pendingPluginUrlValue: "",
};

export function setBusy(nextBusy: boolean, nextLabel = "Ready", nextProgress = 0): void {
	state.busy = nextBusy;
	state.progressLabel = nextLabel;
	state.progress = nextProgress;
}
