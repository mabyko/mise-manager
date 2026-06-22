import type { ElectrobunConfig } from "electrobun";

export default {
	app: {
		name: "Mise Manager",
		identifier: "forked.misemanager.local",
		version: "0.1.2",
	},
	build: {
		copy: {
			"dist/index.html": "views/mainview/index.html",
			"dist/assets": "views/mainview/assets",
		},
		mac: {
			bundleCEF: false,
			icons: "assets/icon.iconset",
		},
		linux: {
			bundleCEF: false,
			icon: "assets/icon.iconset/icon_256x256.png",
		},
		win: {
			bundleCEF: false,
			icon: "assets/icon.iconset/icon_256x256.png",
		},
	},
} satisfies ElectrobunConfig;
