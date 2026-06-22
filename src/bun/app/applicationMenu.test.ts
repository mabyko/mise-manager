import { describe, expect, test } from "bun:test";
import { createApplicationMenu } from "./applicationMenu";

describe("createApplicationMenu", () => {
	test("creates a native Edit menu with standard edit roles", () => {
		const menu = createApplicationMenu();

		expect(menu).toEqual([
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
		]);
	});
});
