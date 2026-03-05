import type { ElectrobunRPCSchema } from "electrobun/view";

export type PluginStatus =
	| "idle"
	| "checking"
	| "done"
	| "error"
	| "updating"
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

export interface AppRPC extends ElectrobunRPCSchema {
	bun: {
		requests: {
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
		};
		messages: Record<never, never>;
	};
	webview: {
		requests: Record<never, never>;
		messages: Record<never, never>;
	};
}
