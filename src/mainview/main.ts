import "./style.css";

import { mount } from "svelte";

import App from "./App.svelte";
import { checkLatestMiseRelease, reloadMiseVersion } from "./features/mise";

const target = document.getElementById("app");

if (!target) {
	throw new Error("app container not found");
}

mount(App, { target });

void (async () => {
	await reloadMiseVersion();
	await checkLatestMiseRelease();
})();
