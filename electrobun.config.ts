import type { ElectrobunConfig } from "electrobun";

export default {
	app: {
		name: "mise-manager",
		identifier: "dev.eugene.mise-manager",
		version: "0.1.0-poc",
	},
	build: {
		copy: {
			"dist/index.html": "views/mainview/index.html",
			"dist/assets": "views/mainview/assets",
		},
		mac: {
			bundleCEF: false,
		},
		linux: {
			bundleCEF: false,
		},
		win: {
			bundleCEF: false,
		},
	},
} satisfies ElectrobunConfig;
