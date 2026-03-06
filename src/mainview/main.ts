import "./style.css";

import { reloadPlugins } from "./core/app";
import { registerEvents } from "./events";
import { createRenderer } from "./render/render";
import "./core/rpc";

const app = document.getElementById("app");

if (!app) {
	throw new Error("app container not found");
}

const render = createRenderer(app);
registerEvents(app, render);

render();
void reloadPlugins(render);
