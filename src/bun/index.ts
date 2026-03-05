import { BrowserView, BrowserWindow, Updater } from "electrobun/bun";

import type {
	AppRPC,
	PluginSummary,
	PluginUpdateInfo,
	UpdateResult,
} from "../shared/contracts";
import {
	compareVersions,
	getMajor,
	isPreReleaseVersion,
	isStableVersion,
	pickLatest,
} from "../shared/version";

const DEV_SERVER_PORT = 5173;
const DEV_SERVER_URL = `http://localhost:${DEV_SERVER_PORT}`;

async function getMainViewUrl(): Promise<string> {
	const channel = await Updater.localInfo.channel();
	if (channel === "dev") {
		try {
			await fetch(DEV_SERVER_URL, { method: "HEAD" });
			console.log(`HMR enabled: Using Vite dev server at ${DEV_SERVER_URL}`);
			return DEV_SERVER_URL;
		} catch {
			console.log(
				"Vite dev server not running. Run 'bun run dev:hmr' for HMR support.",
			);
		}
	}
	return "views://mainview/index.html";
}

async function runMise(args: string[]): Promise<{ stdout: string; stderr: string; exitCode: number }> {
	const proc = Bun.spawn(["mise", ...args], {
		stdout: "pipe",
		stderr: "pipe",
	});

	const [stdout, stderr, exitCode] = await Promise.all([
		new Response(proc.stdout).text(),
		new Response(proc.stderr).text(),
		proc.exited,
	]);

	return { stdout, stderr, exitCode };
}

function sanitizeVersion(input: unknown): string | null {
	if (typeof input === "string" && input.trim().length > 0) {
		return input.trim();
	}
	return null;
}

function parseRemoteVersions(stdout: string): string[] {
	const trimmed = stdout.trim();
	if (!trimmed) {
		return [];
	}

	try {
		const parsed = JSON.parse(trimmed);
		if (Array.isArray(parsed)) {
			const versions = parsed
				.map((entry) => {
					if (typeof entry === "string") {
						return sanitizeVersion(entry);
					}
					if (entry && typeof entry === "object" && "version" in entry) {
						return sanitizeVersion((entry as { version?: unknown }).version);
					}
					return null;
				})
				.filter((value): value is string => Boolean(value));

			return versions;
		}
	} catch {
		// Fallback to plain-text parsing below.
	}

	return trimmed
		.split("\n")
		.map((line) => line.trim())
		.filter((line) => line.length > 0);
}

function pickPreferredVersion(versions: string[]): string | null {
	if (versions.length === 0) {
		return null;
	}
	const semverCandidates = versions.filter((version) => /^\d/.test(version));
	return pickLatest(semverCandidates.length > 0 ? semverCandidates : versions);
}

async function listGlobalPlugins(): Promise<Map<string, string>> {
	const result = await runMise(["ls", "--global", "--json"]);
	if (result.exitCode !== 0) {
		return new Map();
	}

	let parsed: unknown;
	try {
		parsed = JSON.parse(result.stdout);
	} catch {
		return new Map();
	}

	if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
		return new Map();
	}

	const globalMap = new Map<string, string>();
	for (const [plugin, versionsRaw] of Object.entries(parsed)) {
		if (!Array.isArray(versionsRaw)) {
			continue;
		}

		const versions = versionsRaw
			.map((entry) => {
				if (entry && typeof entry === "object" && "version" in entry) {
					return sanitizeVersion((entry as { version?: unknown }).version);
				}
				return null;
			})
			.filter((version): version is string => Boolean(version));

		const preferred = pickPreferredVersion(versions);
		if (preferred) {
			globalMap.set(plugin, preferred);
		}
	}

	return globalMap;
}

async function listInstalledPlugins(): Promise<PluginSummary[]> {
	const result = await runMise(["ls", "--installed", "--json"]);
	if (result.exitCode !== 0) {
		throw new Error(result.stderr.trim() || "failed to run 'mise ls --installed --json'");
	}

	let parsed: unknown;
	try {
		parsed = JSON.parse(result.stdout);
	} catch {
		throw new Error("failed to parse JSON from 'mise ls --installed --json'");
	}

	if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
		throw new Error("unexpected installed tool JSON shape from mise");
	}

	const globalMap = await listGlobalPlugins();
	const summaries: PluginSummary[] = [];
	const touchedPlugins = new Set<string>();
	for (const [plugin, versionsRaw] of Object.entries(parsed)) {
		if (!Array.isArray(versionsRaw)) {
			continue;
		}

		const versions = versionsRaw
			.map((entry) => {
				if (entry && typeof entry === "object" && "version" in entry) {
					return sanitizeVersion((entry as { version?: unknown }).version);
				}
				return null;
			})
			.filter((version): version is string => Boolean(version));

		const installedVersions = [...new Set(versions)].sort((a, b) =>
			compareVersions(b, a),
		);
		if (installedVersions.length === 0) {
			continue;
		}

		summaries.push({
			name: plugin,
			activeGlobalVersion: globalMap.get(plugin) ?? null,
			installedVersions,
		});
		touchedPlugins.add(plugin);
	}

	for (const [plugin, activeGlobalVersion] of globalMap.entries()) {
		if (touchedPlugins.has(plugin)) {
			continue;
		}
		summaries.push({
			name: plugin,
			activeGlobalVersion,
			installedVersions: activeGlobalVersion ? [activeGlobalVersion] : [],
		});
	}

	return summaries.sort((a, b) => a.name.localeCompare(b.name));
}

async function checkPluginUpdates(
	{
		plugin,
		baseVersion,
		includeChannels,
	}: { plugin: string; baseVersion: string; includeChannels: boolean },
): Promise<PluginUpdateInfo> {
	const remoteResult = await runMise(["ls-remote", plugin, "--json"]);
	if (remoteResult.exitCode !== 0) {
		return {
			plugin,
			baseVersion,
			sameMajorLatest: null,
			releaseLatest: null,
			overallLatest: null,
			checkedVersions: 0,
			error: remoteResult.stderr.trim() || `failed to fetch remote versions for ${plugin}`,
		};
	}

	const remoteVersions = parseRemoteVersions(remoteResult.stdout)
		.filter((version) => includeChannels || /^\d/.test(version))
		.filter((version) => isStableVersion(plugin, version))
		.sort((a, b) => compareVersions(a, b));

	const uniqueVersions = [...new Set(remoteVersions)];
	const semverVersions = uniqueVersions.filter((version) => /^\d/.test(version));
	const preReleaseVersions = semverVersions.filter((version) =>
		isPreReleaseVersion(version),
	);
	const preReleaseLatest = pickLatest(preReleaseVersions);
	const releaseLatest = pickLatest(
		semverVersions.filter((version) => !isPreReleaseVersion(version)),
	);
	const isBaseSemver = /^\d/.test(baseVersion);
	const overallLatest =
		preReleaseLatest &&
		((isBaseSemver && compareVersions(preReleaseLatest, baseVersion) > 0) ||
			(!isBaseSemver &&
				releaseLatest !== null &&
				compareVersions(preReleaseLatest, releaseLatest) >= 0))
			? preReleaseLatest
			: null;

	const major = getMajor(baseVersion);
	const sameMajorCandidates =
		major === null
			? []
			: semverVersions.filter((version) => {
				const versionMajor = getMajor(version);
				return versionMajor !== null && versionMajor === major;
			});

	const sameMajorLatest = pickLatest(sameMajorCandidates);

	return {
		plugin,
		baseVersion,
		sameMajorLatest,
		releaseLatest,
		overallLatest,
		checkedVersions: uniqueVersions.length,
	};
}

async function useGlobalPlugin({
	plugin,
	targetVersion,
}: {
	plugin: string;
	targetVersion: string;
}): Promise<UpdateResult> {
	const useResult = await runMise([
		"use",
		"-g",
		"-y",
		`${plugin}@${targetVersion}`,
	]);
	if (useResult.exitCode !== 0) {
		throw new Error(
			useResult.stderr.trim() ||
				`failed to set global version for ${plugin}@${targetVersion}`,
		);
	}

	return {
		plugin,
		targetVersion,
		stdout: useResult.stdout.trim(),
	};
}

async function installPlugin({
	plugin,
	targetVersion,
}: {
	plugin: string;
	targetVersion: string;
}): Promise<UpdateResult> {
	const installResult = await runMise([
		"install",
		"-y",
		`${plugin}@${targetVersion}`,
	]);
	if (installResult.exitCode !== 0) {
		throw new Error(
			installResult.stderr.trim() || `failed to install ${plugin}@${targetVersion}`,
		);
	}

	return {
		plugin,
		targetVersion,
		stdout: installResult.stdout.trim(),
	};
}

async function deletePluginVersion({
	plugin,
	targetVersion,
}: {
	plugin: string;
	targetVersion: string;
}): Promise<UpdateResult> {
	const globalMap = await listGlobalPlugins();
	const active = globalMap.get(plugin);
	if (active === targetVersion) {
		throw new Error("cannot delete active global version");
	}

	const uninstallResult = await runMise([
		"uninstall",
		"-y",
		`${plugin}@${targetVersion}`,
	]);
	if (uninstallResult.exitCode !== 0) {
		throw new Error(
			uninstallResult.stderr.trim() ||
				`failed to uninstall ${plugin}@${targetVersion}`,
		);
	}

	return {
		plugin,
		targetVersion,
		stdout: uninstallResult.stdout.trim(),
	};
}

const url = await getMainViewUrl();

const rpc = BrowserView.defineRPC<AppRPC>({
	maxRequestTime: 1000 * 60 * 20,
	handlers: {
		requests: {
			listInstalledPlugins,
			checkPluginUpdates,
			useGlobalPlugin,
			installPlugin,
			deletePluginVersion,
		},
	},
});

const mainWindow = new BrowserWindow({
	title: "mise-manager",
	url,
	rpc,
	frame: {
		width: 1200,
		height: 820,
		x: 120,
		y: 80,
	},
});

console.log("mise-manager PoC started");
