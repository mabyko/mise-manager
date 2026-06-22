import type { PluginDefinitionInfo, PluginSummary } from "../../shared/contracts";
import { compareVersions } from "../../shared/version";
import {
	parsePluginInfoLines,
	pickPreferredVersion,
	runMise,
	sanitizeVersion,
} from "./mise";
import { readUserToolAliases } from "./miseConfig";

export async function listGlobalPlugins(): Promise<Map<string, string>> {
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

export async function listInstalledPluginNames(): Promise<string[]> {
	const result = await runMise(["plugins", "ls", "--user"]);
	if (result.exitCode !== 0) {
		throw new Error(
			result.stderr.trim() || "failed to run 'mise plugins ls --user'",
		);
	}

	return result.stdout
		.split("\n")
		.map((line) => line.trim())
		.filter((line) => line.length > 0)
		.sort((a, b) => a.localeCompare(b));
}

export async function listInstalledUserPluginInfos(): Promise<PluginDefinitionInfo[]> {
	const result = await runMise(["plugins", "ls", "--user", "--urls"]);
	if (result.exitCode !== 0) {
		throw new Error(
			result.stderr.trim() || "failed to run 'mise plugins ls --user --urls'",
		);
	}
	const aliases = await readUserToolAliases();
	return parsePluginInfoLines(result.stdout)
		.map((entry) => {
			const aliasUrl = aliases.get(entry.name);
			if (aliasUrl) {
				return { ...entry, url: aliasUrl, source: "tool_alias" as const };
			}
			return { ...entry, source: "mise_user" as const };
		})
		.sort((a, b) => a.name.localeCompare(b.name));
}

export async function listCorePluginNames(): Promise<string[]> {
	const result = await runMise(["plugins", "ls", "--core"]);
	if (result.exitCode !== 0) {
		throw new Error(result.stderr.trim() || "failed to run 'mise plugins ls --core'");
	}

	return result.stdout
		.split("\n")
		.map((line) => line.trim())
		.filter((line) => line.length > 0)
		.sort((a, b) => a.localeCompare(b));
}

export async function listInstalledToolNames(): Promise<string[]> {
	const result = await runMise(["ls", "--installed", "--json"]);
	if (result.exitCode !== 0) {
		throw new Error(
			result.stderr.trim() || "failed to run 'mise ls --installed --json'",
		);
	}

	try {
		const parsed = JSON.parse(result.stdout) as Record<string, unknown>;
		return Object.keys(parsed).sort((a, b) => a.localeCompare(b));
	} catch {
		throw new Error("failed to parse JSON from 'mise ls --installed --json'");
	}
}

export async function listRemotePluginNames(): Promise<string[]> {
	const result = await runMise(["plugins", "ls-remote", "--only-names"]);
	if (result.exitCode !== 0) {
		throw new Error(
			result.stderr.trim() || "failed to run 'mise plugins ls-remote --only-names'",
		);
	}

	return [
		...new Set(
			result.stdout
				.split("\n")
				.map((line) => line.trim())
				.filter((line) => line.length > 0),
		),
	].sort((a, b) => a.localeCompare(b));
}

export async function listRemotePluginInfos(): Promise<PluginDefinitionInfo[]> {
	const result = await runMise(["plugins", "ls-remote", "--urls"]);
	if (result.exitCode !== 0) {
		throw new Error(
			result.stderr.trim() || "failed to run 'mise plugins ls-remote --urls'",
		);
	}
	return parsePluginInfoLines(result.stdout).sort((a, b) =>
		a.name.localeCompare(b.name),
	);
}

export async function listInstalledPlugins(): Promise<PluginSummary[]> {
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
