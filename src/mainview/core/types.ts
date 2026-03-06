import type {
	PluginDefinitionInfo,
	PluginStatus,
	PluginSummary,
} from "../../shared/contracts";

export type ActiveTab = "mise" | "updater" | "logs" | "installs";

export interface PluginRow extends PluginSummary {
	sameMajorLatest: string | null;
	releaseLatest: string | null;
	overallLatest: string | null;
	checkedVersions: number;
	status: PluginStatus;
	error?: string;
}

export interface MainViewState {
	activeTab: ActiveTab;
	miseVersion: string | null;
	miseLoaded: boolean;
	miseCurrentError: string | null;
	miseLatestVersion: string | null;
	miseLatestLoaded: boolean;
	miseLatestError: string | null;
	miseLatestCheckedAt: string | null;
	miseNeedsReload: boolean;
	miseLastResult: string;
	pendingMiseUpdateConfirm: boolean;
	plugins: PluginRow[];
	logs: string[];
	busy: boolean;
	progress: number;
	progressLabel: string;
	pendingDelete: { pluginName: string; version: string } | null;
	remotePluginNames: string[];
	installedPluginNames: string[];
	corePluginNames: string[];
	installedToolNames: string[];
	remotePluginInfos: PluginDefinitionInfo[];
	installedUserPluginInfos: PluginDefinitionInfo[];
	pluginSearchQuery: string;
	installsLoaded: boolean;
	pendingPluginUrlDialog:
		| { mode: "install" | "edit"; pluginName: string }
		| null;
	pendingPluginUrlValue: string;
}
