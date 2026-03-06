import "./style.css";

import { registerEvents } from "./events";
import { checkLatestMiseRelease, reloadMiseVersion } from "./features/mise";
import { createRenderer } from "./render/render";
import "./core/rpc";

const app = document.getElementById("app");

if (!app) {
	throw new Error("app container not found");
}

const render = createRenderer(app);
registerEvents(app, render);

render();
void (async () => {
	await reloadMiseVersion(render);
	await checkLatestMiseRelease(render);
})();
