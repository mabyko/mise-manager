// ponytail: browser-preview backend — answers rpc calls when the UI runs in a
// plain browser (no Tauri runtime), so screens can be reviewed and designed
// against realistic data without launching the desktop app. A few KB in the
// real bundle; never active inside Tauri.
import type { PluginSummary, PluginUpdateInfo } from "../../shared/contracts";
import type { RequestClient } from "./rpc";
import { getMajor } from "../../shared/version";

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// Fixed example versions keep UI reviews reproducible; these are not live releases.
let miseVersion = "2026.8.12 macos-arm64";
const plugins: PluginSummary[] = [
	{ name: "node", activeGlobalVersion: "26.0.0", installedVersions: ["26.0.0", "24.20.0", "24.19.0"] },
	{ name: "python", activeGlobalVersion: "3.12.8", installedVersions: ["3.12.8", "3.11.11"] },
	{ name: "bun", activeGlobalVersion: "1.2.4", installedVersions: ["1.2.4"] },
	{ name: "rust", activeGlobalVersion: "1.85.0", installedVersions: ["1.85.0"] },
	{ name: "go", activeGlobalVersion: "1.24.0", installedVersions: ["1.24.0"] },
	{ name: "ruby", activeGlobalVersion: "3.4.2", installedVersions: ["3.4.2"] },
];

const updates: Record<string, Omit<PluginUpdateInfo, "plugin" | "baseVersion">> = {
	node: { latestByMajor: { 24: "24.21.0", 26: "26.1.0" }, sameMajorLatest: "26.1.0", releaseLatest: "26.1.0", overallLatest: "27.0.0-rc.1", checkedVersions: 860 },
	python: { latestByMajor: { 3: "3.13.2" }, sameMajorLatest: "3.13.2", releaseLatest: "3.13.2", overallLatest: null, checkedVersions: 248 },
	bun: { latestByMajor: { 1: "1.2.4" }, sameMajorLatest: "1.2.4", releaseLatest: "1.2.4", overallLatest: null, checkedVersions: 214 },
	rust: { latestByMajor: { 1: "1.85.0" }, sameMajorLatest: "1.85.0", releaseLatest: "1.85.0", overallLatest: null, checkedVersions: 152 },
	go: { latestByMajor: { 1: "1.24.0" }, sameMajorLatest: "1.24.0", releaseLatest: "1.24.0", overallLatest: null, checkedVersions: 130 },
	ruby: { latestByMajor: { 3: "3.4.2" }, sameMajorLatest: "3.4.2", releaseLatest: "3.4.2", overallLatest: null, checkedVersions: 133 },
};

let outdatedPluginNames = ["flutter", "zoxide"];

const remoteNames = [
	"1password-cli", "act", "argo", "awscli", "bat", "cargo-binstall", "cmake", "deno",
	"dotnet", "elixir", "erlang", "fzf", "gcloud", "golang", "gradle", "helm", "java",
	"jq", "kotlin", "kubectl", "lua", "maven", "neovim", "nim", "ocaml", "perl", "php",
	"poetry", "pnpm", "protoc", "ripgrep", "scala", "swift", "terraform", "tmux",
	"yarn", "zig", "zoxide",
];

export const mockRequest: RequestClient = {
	listOutdatedPluginDefinitions: async () => { await delay(250); return [...outdatedPluginNames]; },
	updatePluginDefinition: async ({ plugin }) => {
		await delay(600);
		outdatedPluginNames = outdatedPluginNames.filter(name => name !== plugin);
		return { plugin, stdout: `updated plugin ${plugin}` };
	},
	getMiseVersion: async () => {
		await delay(120);
		return miseVersion;
	},
	getLatestMiseRelease: async () => {
		await delay(250);
		return "v2026.8.13";
	},
	selfUpdateMise: async () => {
		await delay(1200);
		const beforeVersion = miseVersion;
		miseVersion = "2026.8.13 macos-arm64";
		return {
			beforeVersion,
			afterVersion: miseVersion,
			stdout: "mise self-update\ndownloading mise-v2026.8.13-macos-arm64.tar.gz\ninstalled mise 2026.8.13",
			stderr: "",
		};
	},
	listInstalledPlugins: async () => {
		await delay(180);
		return structuredClone(plugins);
	},
	checkPluginUpdates: async ({ plugin, baseVersion }) => {
		await delay(300);
		const found = updates[plugin] ?? {
			latestByMajor: {},
			sameMajorLatest: null,
			releaseLatest: null,
			overallLatest: null,
			checkedVersions: 0,
		};
		return { plugin, baseVersion, ...found, sameMajorLatest: found.latestByMajor[getMajor(baseVersion) ?? ""] ?? null };
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
