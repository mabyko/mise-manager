import type {
	PluginDefinitionInfo,
	PluginStatus,
	PluginSummary,
} from "../../shared/contracts";

export type ActiveTab = "overview" | "mise" | "updater" | "logs" | "installs";

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
	updaterAutoChecked: boolean;
	plugins: PluginRow[];
	logs: string[];
	busy: boolean;
	/** Real percentage when one exists (e.g. N/M plugin checks); null = indeterminate. */
	progress: number | null;
	progressLabel: string;
	/** Latest subprocess output line streamed from the backend while busy. */
	liveOutputLine: string;
	pendingDelete: { pluginName: string; version: string } | null;
	/** Major update awaiting confirmation (Overview action). */
	pendingMajorUpdate: { pluginName: string; fromVersion: string | null; targetVersion: string } | null;
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
		| { mode: "custom-install" }
		| null;
	pendingPluginNameValue: string;
	pendingPluginUrlValue: string;
	miseInstalledChecked: boolean;
	miseIsInstalled: boolean;
	miseInstalling: boolean;
	miseInstallMethod: "sh" | "brew" | null;
	platform: string;
}
