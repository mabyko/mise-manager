import { ApplicationMenu, BrowserView, BrowserWindow } from "electrobun/bun";
import type { AppRPC } from "../shared/contracts";
import { createApplicationMenu } from "./app/applicationMenu";
import { getMainViewUrl } from "./app/mainViewUrl";
import { requestHandlers } from "./rpc/handlers";

ApplicationMenu.setApplicationMenu(createApplicationMenu());

const url = await getMainViewUrl();

const rpc = BrowserView.defineRPC<AppRPC>({
	maxRequestTime: 1000 * 60 * 20,
	handlers: {
		requests: requestHandlers,
	},
});

const mainWindow = new BrowserWindow({
	title: "mise-manager",
	url,
	rpc,
	frame: {
		width: 1200,
		height: 820,
		x: 120,
		y: 80,
	},
});

console.log("mise-manager started", Boolean(mainWindow));
