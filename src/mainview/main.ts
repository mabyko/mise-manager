import "./style.css";

import { listen } from "@tauri-apps/api/event";
import { mount } from "svelte";

import App from "./App.svelte";
import { state } from "./core/state.svelte";
import { checkLatestMiseRelease, reloadMiseVersion } from "./features/mise";

const target = document.getElementById("app");

if (!target) {
	throw new Error("app container not found");
}

mount(App, { target });

// Live subprocess output from the backend (mise / install scripts).
void listen<{ stream: string; line: string }>("mise-output", (event) => {
	state.liveOutputLine = event.payload.line;
});

void (async () => {
	await reloadMiseVersion();
	await checkLatestMiseRelease();
})();
