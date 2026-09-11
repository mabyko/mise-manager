import "./style.css";

import { listen } from "@tauri-apps/api/event";
import { mount } from "svelte";

import App from "./App.svelte";
import { state, setBusy } from "./core/state.svelte";
import { reloadMiseVersion, loadPlatform, checkMiseInstallationStatus } from "./features/mise";
import { settings } from "./core/settings.svelte";
import { checkAllUpdates } from "./features/updates";

import { isTray } from "./core/runtime.svelte";

import { reloadAndCheckTools } from "./features/updater";

const target = document.getElementById("app");

if (!target) {
	throw new Error("app container not found");
}

if (import.meta.env.DEV && new URLSearchParams(location.search).has("variant")) {
	// Throwaway design comparison; simulated actions never reach the RPC backend.
	const referenceStudy = ["E", "F", "G"].includes(new URLSearchParams(location.search).get("variant") ?? "");
	void (referenceStudy ? import("./components/ReferenceDesignPrototype.svelte") : import("./components/UpdateDesignPrototype.svelte")).then(({ default: Prototype }) => {
		mount(Prototype, { target });
	});
} else if (isTray) {
	mount(App, { target });
} else {
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
		setBusy(false);
		if (settings.checkOnStartup) await checkAllUpdates();
		else {
			await reloadMiseVersion();
			await reloadAndCheckTools(false);
		}
	})();
}
