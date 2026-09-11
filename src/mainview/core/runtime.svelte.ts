import { emitTo, listen } from "@tauri-apps/api/event";
import { invoke } from "@tauri-apps/api/core";
import { state as appState } from "./state.svelte";
import { settings } from "./settings.svelte";
import { getUpdateSummary } from "./updateSummary";
import { checkAllUpdates } from "../features/updates";
import { requestMajorUpdate, updateInstalledSeries, useInstalledVersion } from "../features/updater";
import { updatePluginDefinition, reloadPluginDefinitions } from "../features/installs";
import { openMiseUpdateDialog } from "../features/mise";
import type { ActiveTab } from "./types";

export const isTray = new URLSearchParams(location.search).get("surface") === "tray";
const native = "__TAURI_INTERNALS__" in window;
export const connection = $state({ ready: !isTray, sending: false, error: "" });
export type RuntimeAction =
	| { type: "check" }
	| { type: "apply"; id: string }
	| { type: "use"; name: string; version: string }
	| { type: "open"; tab: ActiveTab; name?: string };

// Navigation, dialogs and the remote catalog belong only to the main window.
const sharedKeys = ["plugins", "busy", "progress", "progressLabel", "liveOutputLine", "toolsLoaded", "toolsError", "toolsCheckedAt", "updateCheckRunning",
	"outdatedPluginNames", "pluginUpdatesCheckedAt", "pluginUpdatesError", "pluginUpdateResult", "miseVersion", "miseLoaded", "miseCurrentError", "miseLatestVersion",
	"miseLatestLoaded", "miseLatestError", "miseLatestCheckedAt", "miseNeedsReload", "miseLastResult", "miseInstalledChecked", "miseIsInstalled"] as const;
export function runtimeSnapshot() {
	return JSON.parse(JSON.stringify({ state: Object.fromEntries(sharedKeys.map(key => [key, appState[key]])), settings }));
}

export async function showTray() {
 if (!settings.showMenuBarIcon) return;
 if (native) await invoke("show_tray_window");
 else window.open(`${location.origin}/?surface=tray`, "mise-tray-preview", "width=440,height=620");
}

export async function hideTray() { if (native) await invoke("hide_tray_window"); }
export async function quitApp() { if (native) await invoke("quit_app"); else window.close(); }

/** Commands are always checked again against the owner's live appState. */
export async function runRuntimeAction(action: RuntimeAction) {
	if (action.type === "open") {
		if (!["updater", "updates", "mise", "installs", "settings", "logs"].includes(action.tab)) return;
		appState.activeTab = action.tab;
		if (action.name && appState.plugins.some(p => p.name === action.name)) appState.selectedToolName = action.name;
		if (native) await invoke("show_main_window");
		if (action.tab === "installs" && !appState.installsLoaded && !appState.busy && !appState.updateCheckRunning) await reloadPluginDefinitions();
		return;
	}
	if (appState.busy || appState.updateCheckRunning || appState.pendingDelete || appState.pendingMajorUpdate || appState.pendingMiseUpdateConfirm || appState.pendingPluginUrlDialog) return;
	if (action.type === "check") return checkAllUpdates();
	if (action.type === "use") {
		if (appState.plugins.some(p => p.name === action.name && p.installedVersions.includes(action.version))) await useInstalledVersion(action.name, action.version);
		return;
	}
	if (action.type !== "apply") return;
	const item = getUpdateSummary(appState).items.find(item => item.id === action.id);
	if (!item) return;
	if (item.kind === "series") await updateInstalledSeries(item.name, item.to);
	else if (item.kind === "plugin") await updatePluginDefinition(item.name);
	else {
		await runRuntimeAction({ type: "open", tab: item.kind === "mise" ? "mise" : "updater", name: item.name });
		if (item.kind === "mise") openMiseUpdateDialog();
		else requestMajorUpdate(item.name, item.to);
	}
}

type Message = { target: "main" | "tray"; type: "sync" | "snapshot" | "action" | "done"; payload?: any };
let send: ((message: Message) => Promise<void>) | undefined;
let lastBadge = "";
export async function publishRuntime(snapshot: ReturnType<typeof runtimeSnapshot>) {
	if (isTray || !send) return;
	await send({ target: "tray", type: "snapshot", payload: snapshot });
	if (native) {
		const summary = getUpdateSummary(appState);
		const status = { count: summary.items.length, attention: summary.attention, checking: appState.busy || appState.updateCheckRunning, visible: settings.showMenuBarIcon };
		const badge = JSON.stringify(status);
		if (badge !== lastBadge) { await invoke("set_tray_status", status); lastBadge = badge; }
	}
}

export async function dispatch(action: RuntimeAction) {
	connection.error = "";
	try {
		if (!isTray) { await runRuntimeAction(action); return; }
		if (!connection.ready || connection.sending || !send) return;
		connection.sending = true;
		await send({ target: "main", type: "action", payload: action });
	} catch (error) { connection.sending = false; connection.error = String(error); }
}

export async function connectRuntime() {
	const surface = isTray ? "tray" : "main";
	let handling = false;
	const receive = async (message: Message) => {
		if (message.target !== surface) return;
		try {
			if (isTray && message.type === "snapshot") {
				Object.assign(appState, message.payload.state);
				Object.assign(settings, message.payload.settings);
				connection.ready = true;
			} else if (isTray && message.type === "done") {
				connection.sending = false;
				connection.error = message.payload ?? "";
			} else if (!isTray && message.type === "sync") await publishRuntime(runtimeSnapshot());
			else if (!isTray && message.type === "action") {
				if (handling) return;
				handling = true;
				try { await runRuntimeAction(message.payload); await publishRuntime(runtimeSnapshot()); }
				finally { handling = false; await send?.({ target: "tray", type: "done" }); }
			}
		} catch (error) {
			connection.error = String(error);
			if (!isTray) await send?.({ target: "tray", type: "done", payload: String(error) });
		}
	};
	let dispose: () => void;
	if (native) {
		dispose = await listen<Message>("runtime-message", event => void receive(event.payload));
		send = message => emitTo(message.target, "runtime-message", message);
	} else {
		// The browser preview uses the same two-window flow with the existing mock RPC.
		const channel = new BroadcastChannel("mise-manager-runtime");
		channel.onmessage = event => void receive(event.data);
		send = async message => channel.postMessage(message);
		dispose = () => channel.close();
	}
	if (isTray) await send({ target: "main", type: "sync" });
	else await publishRuntime(runtimeSnapshot());
	// Also refresh on focus after a main-webview reload.
	const refresh = () => { if (isTray) void send?.({ target: "main", type: "sync" }); };
	window.addEventListener("focus", refresh);
	return () => { window.removeEventListener("focus", refresh); dispose(); send = undefined; };
}
