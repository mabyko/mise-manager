import type {
	MiseSelfUpdateResult,
	PluginInstallResult,
	PluginUpdateInfo,
	UpdateResult,
} from "../../shared/contracts";
import {
	compareVersions,
	getMajor,
	isPreReleaseVersion,
	isStableVersion,
	pickLatest,
} from "../../shared/version";
import { listGlobalPlugins } from "./pluginCatalog";
import { parseRemoteVersions, runMise } from "./mise";

export async function getMiseVersion(): Promise<string | null> {
	const result = await runMise(["--version"]);
	if (result.exitCode !== 0) {
		throw new Error(result.stderr.trim() || "failed to run 'mise --version'");
	}
	const line = result.stdout
		.split("\n")
		.map((entry) => entry.trim())
		.find((entry) => entry.length > 0);
	return line ?? null;
}

export async function getLatestMiseRelease(): Promise<string | null> {
	const response = await fetch(
		"https://api.github.com/repos/jdx/mise/releases/latest",
		{
			headers: {
				"User-Agent": "mise-manager",
				Accept: "application/vnd.github+json",
			},
		},
	);
	if (!response.ok) {
		throw new Error(
			`failed to fetch latest mise release (status=${response.status})`,
		);
	}
	const parsed = (await response.json()) as { tag_name?: unknown };
	if (typeof parsed.tag_name === "string" && parsed.tag_name.trim().length > 0) {
		return parsed.tag_name.trim();
	}
	return null;
}

export async function selfUpdateMise(): Promise<MiseSelfUpdateResult> {
	let beforeVersion: string | null = null;
	try {
		beforeVersion = await getMiseVersion();
	} catch {
		beforeVersion = null;
	}

	const result = await runMise(["self-update", "-y"]);
	if (result.exitCode !== 0) {
		throw new Error(result.stderr.trim() || "failed to run 'mise self-update -y'");
	}

	let afterVersion: string | null = beforeVersion;
	try {
		afterVersion = await getMiseVersion();
	} catch {
		afterVersion = beforeVersion;
	}

	return {
		beforeVersion,
		afterVersion,
		stdout: result.stdout.trim(),
		stderr: result.stderr.trim(),
	};
}

export async function checkPluginUpdates(
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

export async function useGlobalPlugin({
	plugin,
	targetVersion,
}: {
	plugin: string;
	targetVersion: string;
}): Promise<UpdateResult> {
	const useResult = await runMise(["use", "-g", "-y", `${plugin}@${targetVersion}`]);
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

export async function installPlugin({
	plugin,
	targetVersion,
}: {
	plugin: string;
	targetVersion: string;
}): Promise<UpdateResult> {
	const installResult = await runMise(["install", "-y", `${plugin}@${targetVersion}`]);
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

export async function deletePluginVersion({
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

	const uninstallResult = await runMise(["uninstall", "-y", `${plugin}@${targetVersion}`]);
	if (uninstallResult.exitCode !== 0) {
		throw new Error(
			uninstallResult.stderr.trim() || `failed to uninstall ${plugin}@${targetVersion}`,
		);
	}

	return {
		plugin,
		targetVersion,
		stdout: uninstallResult.stdout.trim(),
	};
}

export async function installPluginDefinition({
	plugin,
	gitUrl,
	force,
}: {
	plugin: string;
	gitUrl?: string;
	force?: boolean;
}): Promise<PluginInstallResult> {
	const args = ["plugins", "install", "-y"];
	if (force) {
		args.push("--force");
	}
	args.push(plugin);
	if (gitUrl && gitUrl.trim().length > 0) {
		args.push(gitUrl.trim());
	}
	const result = await runMise(args);
	if (result.exitCode !== 0) {
		throw new Error(result.stderr.trim() || `failed to install plugin '${plugin}'`);
	}
	return { plugin, stdout: result.stdout.trim() };
}

export async function uninstallPluginDefinition({
	plugin,
}: {
	plugin: string;
}): Promise<PluginInstallResult> {
	const result = await runMise(["plugins", "uninstall", "-y", plugin]);
	if (result.exitCode !== 0) {
		throw new Error(result.stderr.trim() || `failed to uninstall plugin '${plugin}'`);
	}
	return { plugin, stdout: result.stdout.trim() };
}
