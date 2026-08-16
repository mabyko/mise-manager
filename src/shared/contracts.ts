export type PluginStatus =
	| "idle"
	| "checking"
	| "done"
	| "error"
	| "updating"
	| "deleting"
	| "skipped";

export interface PluginSummary {
	name: string;
	activeGlobalVersion: string | null;
	installedVersions: string[];
}

export interface PluginUpdateInfo {
	plugin: string;
	baseVersion: string;
	sameMajorLatest: string | null;
	releaseLatest: string | null;
	overallLatest: string | null;
	checkedVersions: number;
	error?: string;
}

export interface UpdateResult {
	plugin: string;
	targetVersion: string;
	stdout: string;
}

export interface PluginInstallResult {
	plugin: string;
	stdout: string;
}

export interface PluginDefinitionInfo {
	name: string;
	url: string | null;
	source?: "mise_user" | "tool_alias" | "remote" | "core";
}

export interface MiseSelfUpdateResult {
	beforeVersion: string | null;
	afterVersion: string | null;
	stdout: string;
	stderr: string;
}

export interface MiseInstallResult {
	success: boolean;
	stdout: string;
	stderr: string;
}

export interface AppRPC {
	bun: {
		requests: {
			getMiseVersion: {
				params: undefined;
				response: string | null;
			};
			getLatestMiseRelease: {
				params: undefined;
				response: string | null;
			};
			selfUpdateMise: {
				params: undefined;
				response: MiseSelfUpdateResult;
			};
			listInstalledPlugins: {
				params: undefined;
				response: PluginSummary[];
			};
			checkPluginUpdates: {
				params: {
					plugin: string;
					baseVersion: string;
					includeChannels: boolean;
				};
				response: PluginUpdateInfo;
			};
			useGlobalPlugin: {
				params: { plugin: string; targetVersion: string };
				response: UpdateResult;
			};
			installPlugin: {
				params: { plugin: string; targetVersion: string };
				response: UpdateResult;
			};
			deletePluginVersion: {
				params: { plugin: string; targetVersion: string };
				response: UpdateResult;
			};
			listInstalledPluginNames: {
				params: undefined;
				response: string[];
			};
			listInstalledUserPluginInfos: {
				params: undefined;
				response: PluginDefinitionInfo[];
			};
			listCorePluginNames: {
				params: undefined;
				response: string[];
			};
			listInstalledToolNames: {
				params: undefined;
				response: string[];
			};
			listRemotePluginNames: {
				params: undefined;
				response: string[];
			};
			listRemotePluginInfos: {
				params: undefined;
				response: PluginDefinitionInfo[];
			};
			installPluginDefinition: {
				params: {
					plugin: string;
					gitUrl?: string;
					force?: boolean;
					removeToolAlias?: boolean;
				};
				response: PluginInstallResult;
			};
			uninstallPluginDefinition: {
				params: { plugin: string };
				response: PluginInstallResult;
			};
			checkMiseInstalled: {
				params: undefined;
				response: boolean;
			};
			installMiseSh: {
				params: undefined;
				response: MiseInstallResult;
			};
			installMiseBrew: {
				params: undefined;
				response: MiseInstallResult;
			};
			getPlatform: {
				params: undefined;
				response: string;
			};
		};
		messages: Record<never, never>;
	};
	webview: {
		requests: Record<never, never>;
		messages: Record<never, never>;
	};
}
