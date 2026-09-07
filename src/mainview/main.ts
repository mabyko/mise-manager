import "./style.css";

import { listen } from "@tauri-apps/api/event";
import { mount } from "svelte";

import App from "./App.svelte";
import { state, setBusy } from "./core/state.svelte";
import { checkLatestMiseRelease, reloadMiseVersion, loadPlatform, checkMiseInstallationStatus } from "./features/mise";

import { reloadAndCheckTools } from "./features/updater";

const target = document.getElementById("app");

if (!target) {
	throw new Error("app container not found");
}

setBusy(true, "mise 확인 중");
mount(App, { target });

// Live subprocess output from the backend (mise / install scripts).
if ("__TAURI_INTERNALS__" in window) void listen<{ stream: string; line: string }>("mise-output", (event) => {
	state.liveOutputLine = event.payload.line;
});

void (async () => {
	await loadPlatform();
	await checkMiseInstallationStatus();
	if (!state.miseIsInstalled) {
		state.activeTab = "mise";
		setBusy(false, "mise 설치 필요");
		return;
	}
	await reloadMiseVersion();
	await checkLatestMiseRelease();
	await reloadAndCheckTools();
})();
