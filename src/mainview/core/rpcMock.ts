// ponytail: browser-preview backend — answers rpc calls when the UI runs in a
// plain browser (no Tauri runtime), so screens can be reviewed and designed
// against realistic data without launching the desktop app. A few KB in the
// real bundle; never active inside Tauri.
import type { PluginSummary, PluginUpdateInfo } from "../../shared/contracts";
import type { RequestClient } from "./rpc";

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const plugins: PluginSummary[] = [
	{ name: "bun", activeGlobalVersion: "1.3.14", installedVersions: ["1.3.14"] },
	{ name: "flutter", activeGlobalVersion: "stable", installedVersions: ["stable"] },
	{ name: "node", activeGlobalVersion: "24.19.0", installedVersions: ["24.19.0", "22.11.0"] },
	{ name: "python", activeGlobalVersion: "3.14.7", installedVersions: ["3.14.7"] },
	{ name: "ruby", activeGlobalVersion: "4.0.6", installedVersions: ["4.0.6"] },
	{ name: "rust", activeGlobalVersion: "1.97.1", installedVersions: ["1.97.1"] },
];

const updates: Record<string, Omit<PluginUpdateInfo, "plugin" | "baseVersion">> = {
	bun: { sameMajorLatest: "1.3.14", releaseLatest: "1.3.14", overallLatest: null, checkedVersions: 214 },
	flutter: { sameMajorLatest: null, releaseLatest: "1.12.13+hotfix.9-stable", overallLatest: "3.47.0-stable", checkedVersions: 312 },
	node: { sameMajorLatest: "24.19.0", releaseLatest: "26.7.0", overallLatest: null, checkedVersions: 860 },
	python: { sameMajorLatest: "3.14.7", releaseLatest: "3.14.7", overallLatest: null, checkedVersions: 248 },
	ruby: { sameMajorLatest: null, releaseLatest: null, overallLatest: null, checkedVersions: 0, error: "ls-remote failed: registry timeout" },
	rust: { sameMajorLatest: "1.97.1", releaseLatest: "1.97.1", overallLatest: null, checkedVersions: 152 },
};

const remoteNames = [
	"1password-cli", "act", "argo", "awscli", "bat", "cargo-binstall", "cmake", "deno",
	"dotnet", "elixir", "erlang", "fzf", "gcloud", "golang", "gradle", "helm", "java",
	"jq", "kotlin", "kubectl", "lua", "maven", "neovim", "nim", "ocaml", "perl", "php",
	"poetry", "pnpm", "protoc", "ripgrep", "scala", "swift", "terraform", "tmux",
	"yarn", "zig", "zoxide",
];

export const mockRequest: RequestClient = {
	getMiseVersion: async () => {
		await delay(120);
		return "2026.8.6 macos-arm64 (2026-08-14)";
	},
	getLatestMiseRelease: async () => {
		await delay(250);
		return "v2026.8.7";
	},
	selfUpdateMise: async () => {
		await delay(1200);
		return {
			beforeVersion: "2026.8.6 macos-arm64 (2026-08-14)",
			afterVersion: "2026.8.7 macos-arm64 (2026-08-16)",
			stdout: "mise self-update\ndownloading mise-v2026.8.7-macos-arm64.tar.gz\ninstalled mise 2026.8.7",
			stderr: "",
		};
	},
	listInstalledPlugins: async () => {
		await delay(180);
		return structuredClone(plugins);
	},
	checkPluginUpdates: async ({ plugin, baseVersion }) => {
		await delay(300 + Math.floor(Math.random() * 500));
		const found = updates[plugin] ?? {
			sameMajorLatest: null,
			releaseLatest: null,
			overallLatest: null,
			checkedVersions: 0,
		};
		return { plugin, baseVersion, ...found };
	},
	useGlobalPlugin: async ({ plugin, targetVersion }) => {
		await delay(400);
		const entry = plugins.find((p) => p.name === plugin);
		if (entry) {
			entry.activeGlobalVersion = targetVersion;
		}
		return { plugin, targetVersion, stdout: `mise ${plugin}@${targetVersion} is now active` };
	},
	installPlugin: async ({ plugin, targetVersion }) => {
		await delay(900);
		const entry = plugins.find((p) => p.name === plugin);
		if (entry && !entry.installedVersions.includes(targetVersion)) {
			entry.installedVersions = [targetVersion, ...entry.installedVersions];
		}
		return { plugin, targetVersion, stdout: `mise ${plugin}@${targetVersion} installed` };
	},
	deletePluginVersion: async ({ plugin, targetVersion }) => {
		await delay(400);
		const entry = plugins.find((p) => p.name === plugin);
		if (entry) {
			entry.installedVersions = entry.installedVersions.filter((v) => v !== targetVersion);
		}
		return { plugin, targetVersion, stdout: `removed ${plugin}@${targetVersion}` };
	},
	listInstalledPluginNames: async () => ["flutter", "zoxide"],
	listInstalledUserPluginInfos: async () => [
		{ name: "flutter", url: "https://github.com/leoafarias/fvm-asdf.git", source: "tool_alias" },
		{ name: "zoxide", url: "https://github.com/nyrst/asdf-zoxide.git", source: "mise_user" },
	],
	listCorePluginNames: async () => ["bun", "go", "node", "python", "ruby", "rust"],
	listInstalledToolNames: async () => plugins.map((p) => p.name),
	listRemotePluginNames: async () => [...remoteNames],
	listRemotePluginInfos: async () =>
		remoteNames.map((name) => ({ name, url: `https://github.com/mise-plugins/mise-${name}.git` })),
	installPluginDefinition: async ({ plugin }) => {
		await delay(700);
		return { plugin, stdout: `plugin ${plugin} installed` };
	},
	uninstallPluginDefinition: async ({ plugin }) => {
		await delay(400);
		return { plugin, stdout: `plugin ${plugin} removed` };
	},
	checkMiseInstalled: async () => true,
	installMiseSh: async () => ({ success: true, stdout: "installed", stderr: "" }),
	installMiseBrew: async () => ({ success: true, stdout: "installed", stderr: "" }),
	getPlatform: async () => "darwin",
};
