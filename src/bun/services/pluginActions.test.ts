import { mkdtemp, readFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { afterEach, beforeEach, describe, expect, mock, test } from "bun:test";

const runMiseCalls: string[][] = [];
const originalXdgConfigHome = process.env.XDG_CONFIG_HOME;

mock.module("./mise", () => ({
	runMise: async (args: string[]) => {
		runMiseCalls.push(args);
		return { stdout: "installed", stderr: "", exitCode: 0 };
	},
	parseRemoteVersions: () => [],
	parsePluginInfoLines: () => [],
	pickPreferredVersion: (versions: string[]) => versions[0] ?? null,
	sanitizeVersion: (value: unknown) => (typeof value === "string" ? value : null),
}));

const { installPluginDefinition } = await import("./pluginActions");

describe("installPluginDefinition", () => {
	beforeEach(async () => {
		runMiseCalls.length = 0;
		process.env.XDG_CONFIG_HOME = await mkdtemp(
			join(tmpdir(), "mise-manager-actions-test-"),
		);
	});

	afterEach(() => {
		if (originalXdgConfigHome === undefined) {
			delete process.env.XDG_CONFIG_HOME;
		} else {
			process.env.XDG_CONFIG_HOME = originalXdgConfigHome;
		}
	});

	test("updates tool_alias after installing custom URL", async () => {
		const result = await installPluginDefinition({
			plugin: "zoxide",
			gitUrl: "https://github.com/nyrst/asdf-zoxide.git",
		});

		expect(runMiseCalls).toEqual([
			[
				"plugins",
				"install",
				"-y",
				"zoxide",
				"https://github.com/nyrst/asdf-zoxide.git",
			],
		]);
		expect(result.stdout).toContain("Updated tool_alias in ");
		expect(result.stdout).toContain("/mise/config.toml.");
		const configPath = join(
			process.env.XDG_CONFIG_HOME ?? "",
			"mise",
			"config.toml",
		);
		expect(await readFile(configPath, "utf8")).toContain(
			'"zoxide" = "https://github.com/nyrst/asdf-zoxide.git"',
		);
	});

	test("removes tool_alias after forcing default URL install", async () => {
		await installPluginDefinition({
			plugin: "flutter",
			gitUrl: "https://github.com/custom/asdf-flutter.git",
		});
		runMiseCalls.length = 0;

		const result = await installPluginDefinition({
			plugin: "flutter",
			force: true,
			removeToolAlias: true,
		});

		expect(runMiseCalls).toEqual([
			["plugins", "install", "-y", "--force", "flutter"],
		]);
		expect(result.stdout).toContain("Removed tool_alias from ");
		const configPath = join(
			process.env.XDG_CONFIG_HOME ?? "",
			"mise",
			"config.toml",
		);
		expect(await readFile(configPath, "utf8")).not.toContain("flutter");
	});
});
