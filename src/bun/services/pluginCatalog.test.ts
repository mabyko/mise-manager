import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { randomUUID } from "node:crypto";
import { afterEach, beforeEach, describe, expect, mock, test } from "bun:test";

let runMiseResult = { stdout: "", stderr: "", exitCode: 0 };
const originalXdgConfigHome = process.env.XDG_CONFIG_HOME;

mock.module("./mise", () => ({
	runMise: async () => runMiseResult,
	parsePluginInfoLines: (stdout: string) =>
		stdout
			.split("\n")
			.map((line) => line.trim())
			.filter(Boolean)
			.map((line) => {
				const [name, url] = line.split(/\s+/);
				return { name, url: url ?? null };
			}),
	sanitizeVersion: (value: unknown) => (typeof value === "string" ? value : null),
	pickPreferredVersion: (versions: string[]) => versions[0] ?? null,
}));

const { listInstalledUserPluginInfos } = await import("./pluginCatalog");

describe("listInstalledUserPluginInfos", () => {
	beforeEach(async () => {
		runMiseResult = {
			stdout: "flutter https://github.com/asdf-community/asdf-flutter.git\nnode https://github.com/asdf-vm/asdf-nodejs.git\n",
			stderr: "",
			exitCode: 0,
		};
		process.env.XDG_CONFIG_HOME = join(
			tmpdir(),
			`mise-manager-catalog-test-${randomUUID()}`,
		);
	});

	afterEach(() => {
		if (originalXdgConfigHome === undefined) {
			delete process.env.XDG_CONFIG_HOME;
		} else {
			process.env.XDG_CONFIG_HOME = originalXdgConfigHome;
		}
	});

	test("marks normal user plugins as mise_user", async () => {
		await expect(listInstalledUserPluginInfos()).resolves.toContainEqual({
			name: "node",
			url: "https://github.com/asdf-vm/asdf-nodejs.git",
			source: "mise_user",
		});
	});

	test("overlays tool_alias URL and source over mise plugin URLs", async () => {
		const configDir = join(process.env.XDG_CONFIG_HOME ?? "", "mise");
		await mkdir(configDir, { recursive: true });
		await writeFile(
			join(configDir, "config.toml"),
			`[tool_alias]\nflutter = "https://github.com/custom/asdf-flutter.git"\n`,
		);

		await expect(listInstalledUserPluginInfos()).resolves.toContainEqual({
			name: "flutter",
			url: "https://github.com/custom/asdf-flutter.git",
			source: "tool_alias",
		});
	});
});
