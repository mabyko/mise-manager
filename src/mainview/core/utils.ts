import { compareVersions } from "../../shared/version";
import type { PluginDefinitionInfo } from "../../shared/contracts";

export function nowLabel(): string {
	return new Date().toLocaleString("ko-KR", { hour12: false });
}

export function sortVersionsDesc(versions: string[]): string[] {
	return [...versions].sort((a, b) => compareVersions(b, a));
}

export function normalizePluginInstallUrl(value: string): string {
	const raw = value.trim();
	if (/^(https?:\/\/|git@|ssh:\/\/|asdf:|vfox:)/i.test(raw)) {
		return raw;
	}
	if (/^[^/\s]+\/[^/\s]+(?:\.git)?$/i.test(raw)) {
		return `https://github.com/${raw}`;
	}
	return raw;
}

export function normalizePluginSourceToken(value: string): string {
	const raw = value.trim().replace(/\/+$/, "").replace(/\.git$/i, "");
	if (raw.startsWith("https://")) {
		return raw.slice("https://".length).toLowerCase();
	}
	if (raw.startsWith("http://")) {
		return raw.slice("http://".length).toLowerCase();
	}
	if (raw.startsWith("asdf:")) {
		const repo = raw.slice("asdf:".length);
		if (repo.startsWith("https://") || repo.startsWith("http://")) {
			return normalizePluginSourceToken(repo);
		}
		return normalizePluginSourceToken(`https://github.com/${repo}`);
	}
	if (raw.startsWith("vfox:")) {
		const repo = raw.slice("vfox:".length);
		if (repo.startsWith("https://") || repo.startsWith("http://")) {
			return normalizePluginSourceToken(repo);
		}
		return normalizePluginSourceToken(`https://github.com/${repo}`);
	}
	return raw.toLowerCase();
}

export function findUserPluginInfo(
	plugin: string,
	installedUserPluginInfos: PluginDefinitionInfo[],
): PluginDefinitionInfo | undefined {
	return installedUserPluginInfos.find((entry) => entry.name === plugin);
}

export function findRemoteSourceTokens(
	plugin: string,
	remotePluginInfos: PluginDefinitionInfo[],
): string[] {
	return remotePluginInfos
		.filter((entry) => entry.name === plugin && entry.url)
		.map((entry) => entry.url as string);
}

export function isDefaultPluginUrl(
	plugin: string,
	gitUrl: string | null | undefined,
	remotePluginInfos: PluginDefinitionInfo[],
): boolean {
	if (!gitUrl) {
		return remotePluginInfos.some((entry) => entry.name === plugin && !entry.url);
	}
	const normalizedGitUrl = normalizePluginSourceToken(gitUrl);
	return findRemoteSourceTokens(plugin, remotePluginInfos).some(
		(remote) => normalizePluginSourceToken(remote) === normalizedGitUrl,
	);
}

export function isCustomUserPluginUrl(
	pluginOrUserInfo: string | PluginDefinitionInfo,
	installedUserPluginInfosOrRemotePluginInfos: PluginDefinitionInfo[],
	remotePluginInfos = installedUserPluginInfosOrRemotePluginInfos,
): boolean {
	const userInfo =
		typeof pluginOrUserInfo === "string"
			? findUserPluginInfo(
					pluginOrUserInfo,
					installedUserPluginInfosOrRemotePluginInfos,
				)
			: pluginOrUserInfo;
	if (!userInfo) return false;
	if (userInfo.source === "tool_alias") return true;
	if (!userInfo.url) return false;

	const remoteTokens = findRemoteSourceTokens(userInfo.name, remotePluginInfos);
	if (remoteTokens.length === 0) {
		return true;
	}
	return !isDefaultPluginUrl(userInfo.name, userInfo.url, remotePluginInfos);
}
