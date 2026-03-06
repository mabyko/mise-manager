import {
	listCorePluginNames,
	listInstalledPluginNames,
	listInstalledPlugins,
	listInstalledToolNames,
	listInstalledUserPluginInfos,
	listRemotePluginInfos,
	listRemotePluginNames,
} from "../services/pluginCatalog";
import {
	checkPluginUpdates,
	deletePluginVersion,
	getLatestMiseRelease,
	getMiseVersion,
	installPlugin,
	installPluginDefinition,
	selfUpdateMise,
	uninstallPluginDefinition,
	useGlobalPlugin,
} from "../services/pluginActions";

export const requestHandlers = {
	getMiseVersion,
	getLatestMiseRelease,
	selfUpdateMise,
	listInstalledPlugins,
	checkPluginUpdates,
	useGlobalPlugin,
	installPlugin,
	deletePluginVersion,
	listInstalledPluginNames,
	listInstalledUserPluginInfos,
	listCorePluginNames,
	listInstalledToolNames,
	listRemotePluginNames,
	listRemotePluginInfos,
	installPluginDefinition,
	uninstallPluginDefinition,
};
