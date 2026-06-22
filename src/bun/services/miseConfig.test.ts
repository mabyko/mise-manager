import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { afterEach, describe, expect, test } from "bun:test";
import {
	parseToolAliasToml,
	readUserToolAliases,
	removeToolAliasToml,
	removeUserToolAlias,
	updateUserToolAlias,
} from "./miseConfig";

const originalHome = process.env.HOME;
const originalXdgConfigHome = process.env.XDG_CONFIG_HOME;

afterEach(() => {
	if (originalHome === undefined) {
		delete process.env.HOME;
	} else {
		process.env.HOME = originalHome;
	}
	if (originalXdgConfigHome === undefined) {
		delete process.env.XDG_CONFIG_HOME;
	} else {
		process.env.XDG_CONFIG_HOME = originalXdgConfigHome;
	}
});

describe("tool_alias mise config helpers", () => {
	test("parses quoted and unquoted string aliases from tool_alias", () => {
		const aliases = parseToolAliasToml(`
[settings]
experimental = true

[tool_alias]
flutter = "https://github.com/asdf-community/asdf-flutter.git"
"nodejs-lts" = 'https://github.com/asdf-vm/asdf-nodejs.git'

[tools]
node = "22"
`);

		expect(aliases).toEqual(
			new Map([
				["flutter", "https://github.com/asdf-community/asdf-flutter.git"],
				["nodejs-lts", "https://github.com/asdf-vm/asdf-nodejs.git"],
			]),
		);
	});

	test("removes only the requested alias line", () => {
		const nextToml = removeToolAliasToml(
			`[tool_alias]
flutter = "https://example.com/flutter.git"
node = "https://example.com/node.git"

[tools]
node = "22"
`,
			"flutter",
		);

		expect(nextToml).not.toContain("flutter =");
		expect(nextToml).toContain('node = "https://example.com/node.git"');
		expect(nextToml).toContain("[tools]");
	});

	test("reads missing user config as an empty map", async () => {
		const dir = await mkdtemp(join(tmpdir(), "mise-manager-test-"));
		process.env.XDG_CONFIG_HOME = dir;

		await expect(readUserToolAliases()).resolves.toEqual(new Map());
	});

	test("updates and removes aliases from XDG mise config", async () => {
		const dir = await mkdtemp(join(tmpdir(), "mise-manager-test-"));
		process.env.XDG_CONFIG_HOME = dir;

		const configPath = await updateUserToolAlias({
			plugin: "zoxide",
			gitUrl: "https://github.com/nyrst/asdf-zoxide.git",
		});
		expect(configPath).toBe(join(dir, "mise", "config.toml"));
		expect(await readUserToolAliases()).toEqual(
			new Map([["zoxide", "https://github.com/nyrst/asdf-zoxide.git"]]),
		);

		await writeFile(
			configPath,
			`[tool_alias]
zoxide = "https://github.com/nyrst/asdf-zoxide.git"
node = "https://github.com/asdf-vm/asdf-nodejs.git"
`,
		);

		await removeUserToolAlias({ plugin: "zoxide" });

		const nextToml = await readFile(configPath, "utf8");
		expect(nextToml).not.toContain("zoxide");
		expect(nextToml).toContain("node");
	});
});
