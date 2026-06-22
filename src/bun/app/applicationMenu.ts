import type { ApplicationMenuItemConfig } from "electrobun/bun";

export function createApplicationMenu(): ApplicationMenuItemConfig[] {
	return [
		{
			label: "Edit",
			submenu: [
				{ role: "undo" },
				{ role: "redo" },
				{ type: "separator" },
				{ role: "cut" },
				{ role: "copy" },
				{ role: "paste" },
				{ type: "separator" },
				{ role: "selectAll" },
			],
		},
	];
}
