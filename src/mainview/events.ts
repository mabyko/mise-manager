import { state } from "./core/state";
import { reloadPlugins } from "./core/app";
import {
	installPluginDefinition,
	openEditPluginDialog,
	openInstallPluginDialog,
	reloadPluginDefinitions,
	submitPluginUrlDialog,
	uninstallPluginDefinition,
} from "./features/installs";
import { clearLogs } from "./features/logs";
import {
	cancelMiseUpdateDialog,
	checkLatestMiseRelease,
	checkMiseInstallationStatus,
	confirmMiseSelfUpdate,
	loadPlatform,
	openMiseUpdateDialog,
	reloadMiseVersion,
	startMiseInstall,
} from "./features/mise";
import {
	checkUpdates,
	confirmDeleteInstalledVersion,
	runTargetAction,
	useInstalledVersion,
} from "./features/updater";

type ButtonActionHandler = (target: HTMLButtonElement) => void;

export function registerEvents(appRoot: HTMLElement, render: () => void): void {
	const tabActions: Record<string, ButtonActionHandler> = {
		"tab-mise": () => {
			state.activeTab = "mise";
			void (async () => {
				if (state.platform === "unknown") {
					await loadPlatform(render);
				}
				if (!state.miseInstalledChecked) {
					await checkMiseInstallationStatus(render);
					if (state.miseIsInstalled && (!state.miseLoaded || !state.miseLatestLoaded)) {
						await reloadMiseVersion(render);
						await checkLatestMiseRelease(render);
					}
				} else if (state.miseIsInstalled && (!state.miseLoaded || !state.miseLatestLoaded)) {
					await reloadMiseVersion(render);
					await checkLatestMiseRelease(render);
				}
			})();
			render();
		},
		"tab-updater": () => {
			state.activeTab = "updater";
			if (!state.updaterAutoChecked) {
				state.updaterAutoChecked = true;
				void (async () => {
					if (state.plugins.length === 0) {
						await reloadPlugins(render);
					}
					await checkUpdates(render);
				})();
			}
			render();
		},
		"tab-installs": () => {
			state.activeTab = "installs";
			if (!state.installsLoaded) {
				void reloadPluginDefinitions(render);
			}
			render();
		},
		"tab-logs": () => {
			state.activeTab = "logs";
			render();
		},
	};

	const globalActions: Record<string, ButtonActionHandler> = {
		"reload-mise": () => {
			void reloadMiseVersion(render);
		},
		"check-latest-mise": () => {
			void checkLatestMiseRelease(render);
		},
		"open-mise-update": () => {
			openMiseUpdateDialog(render);
		},
		"cancel-mise-update": () => {
			cancelMiseUpdateDialog(render);
		},
		"confirm-mise-update": () => {
			void confirmMiseSelfUpdate(render);
		},
		"install-mise-sh": () => {
			void startMiseInstall("sh", render);
		},
		"install-mise-brew": () => {
			void startMiseInstall("brew", render);
		},
		reload: () => {
			void reloadPlugins(render);
		},
		"reload-installs": () => {
			void reloadPluginDefinitions(render);
		},
		"check-updates": () => {
			void checkUpdates(render);
		},
		"cancel-delete": () => {
			state.pendingDelete = null;
			render();
		},
		"confirm-delete": () => {
			void confirmDeleteInstalledVersion(render);
		},
		"cancel-plugin-url": () => {
			state.pendingPluginUrlDialog = null;
			state.pendingPluginUrlValue = "";
			render();
		},
		"submit-plugin-url": () => {
			void submitPluginUrlDialog(render);
		},
		"clear-logs": () => {
			clearLogs();
			render();
		},
	};

	const pluginActions: Record<string, (plugin: string) => void> = {
		"install-same": (plugin) => {
			void runTargetAction(plugin, "same", "install", render);
		},
		"install-release": (plugin) => {
			void runTargetAction(plugin, "release", "install", render);
		},
		"install-latest": (plugin) => {
			void runTargetAction(plugin, "latest", "install", render);
		},
		"install-plugin-def": (plugin) => {
			openInstallPluginDialog(plugin, render);
		},
		"edit-plugin-def": (plugin) => {
			openEditPluginDialog(plugin, render);
		},
		"uninstall-plugin-def": (plugin) => {
			void uninstallPluginDefinition(plugin, render);
		},
	};

	const versionActions: Record<string, (plugin: string, version: string) => void> = {
		"use-installed": (plugin, version) => {
			void useInstalledVersion(plugin, version, render);
		},
		"delete-installed": (plugin, version) => {
			state.pendingDelete = { pluginName: plugin, version };
			render();
		},
	};

	appRoot.addEventListener("click", (event) => {
		const raw = event.target as HTMLElement;
		const target = raw.closest("button[data-action]") as HTMLButtonElement | null;
		if (!target) {
			return;
		}

		const action = target.dataset.action;
		if (!action) {
			return;
		}

		const tabHandler = tabActions[action];
		if (tabHandler) {
			tabHandler(target);
			return;
		}
		const globalHandler = globalActions[action];
		if (globalHandler) {
			globalHandler(target);
			return;
		}

		const plugin = target.dataset.plugin;
		if (!plugin) {
			return;
		}

		const pluginHandler = pluginActions[action];
		if (pluginHandler) {
			pluginHandler(plugin);
			return;
		}

		const version = target.dataset.version;
		if (!version) {
			return;
		}
		const versionHandler = versionActions[action];
		if (versionHandler) {
			versionHandler(plugin, version);
		}
	});

	appRoot.addEventListener("input", (event) => {
		const target = event.target as HTMLElement;
		if (!(target instanceof HTMLInputElement)) {
			return;
		}
		if (target.dataset.action !== "plugin-search") {
			if (target.dataset.action === "plugin-url-input") {
				state.pendingPluginUrlValue = target.value;
			}
			return;
		}
		const selectionStart = target.selectionStart ?? state.pluginSearchQuery.length;
		const selectionEnd = target.selectionEnd ?? selectionStart;
		state.pluginSearchQuery = target.value;
		render();
		const nextSearch = appRoot.querySelector(
			'input[data-action="plugin-search"]',
		) as HTMLInputElement | null;
		if (nextSearch) {
			nextSearch.focus();
			nextSearch.setSelectionRange(selectionStart, selectionEnd);
		}
	});
}
