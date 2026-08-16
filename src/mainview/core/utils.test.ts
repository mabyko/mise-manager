import { describe, expect, test } from "vitest";
import {
	isCustomUserPluginUrl,
	isDefaultPluginUrl,
	normalizePluginInstallUrl,
	normalizePluginSourceToken,
} from "./utils";

describe("plugin URL utilities", () => {
	test("normalizes owner/repo shorthand into a GitHub URL", () => {
		expect(normalizePluginInstallUrl("nyrst/asdf-zoxide.git")).toBe(
			"https://github.com/nyrst/asdf-zoxide.git",
		);
		expect(normalizePluginInstallUrl("https://example.com/repo.git")).toBe(
			"https://example.com/repo.git",
		);
		expect(normalizePluginInstallUrl("asdf:nyrst/asdf-zoxide")).toBe(
			"asdf:nyrst/asdf-zoxide",
		);
	});

	test("compares aliases, .git, and trailing slash as the same source token", () => {
		expect(normalizePluginSourceToken("asdf:nyrst/asdf-zoxide.git/")).toBe(
			normalizePluginSourceToken("https://github.com/nyrst/asdf-zoxide"),
		);
		expect(normalizePluginSourceToken("vfox:version-fox/vfox-nodejs")).toBe(
			normalizePluginSourceToken("https://github.com/version-fox/vfox-nodejs.git"),
		);
	});

	test("detects default URLs by comparing remote catalog source tokens", () => {
		expect(
			isDefaultPluginUrl(
				"flutter",
				"asdf:asdf-community/asdf-flutter",
				[
					{
						name: "flutter",
						url: "https://github.com/asdf-community/asdf-flutter.git",
					},
				],
			),
		).toBe(true);
	});

	test("treats tool_alias as custom even when URL matches remote default", () => {
		expect(
			isCustomUserPluginUrl(
				{ name: "flutter", url: "https://github.com/asdf-community/asdf-flutter.git", source: "tool_alias" },
				[
					{
						name: "flutter",
						url: "https://github.com/asdf-community/asdf-flutter.git",
					},
				],
			),
		).toBe(true);
	});

	test("keeps URL-less official remote plugins displayed as default", () => {
		expect(
			isCustomUserPluginUrl(
				{ name: "node", url: null, source: "mise_user" },
				[{ name: "node", url: null }],
			),
		).toBe(false);
	});
});
