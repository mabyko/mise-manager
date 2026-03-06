import { compareVersions } from "../../shared/version";
import type { PluginDefinitionInfo } from "../../shared/contracts";

export function escapeHtml(value: string): string {
	return value
		.replaceAll("&", "&amp;")
		.replaceAll("<", "&lt;")
		.replaceAll(">", "&gt;")
		.replaceAll('"', "&quot;")
		.replaceAll("'", "&#39;");
}

export function nowLabel(): string {
	return new Date().toLocaleString("ko-KR", { hour12: false });
}

export function sortVersionsDesc(versions: string[]): string[] {
	return [...versions].sort((a, b) => compareVersions(b, a));
}

export function normalizePluginSourceToken(value: string): string {
	const raw = value.trim().replace(/\/+$/, "").replace(/\.git$/, "");
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
		return `github.com/${repo}`.toLowerCase().replace(/\/+$/, "").replace(/\.git$/, "");
	}
	if (raw.startsWith("vfox:")) {
		const repo = raw.slice("vfox:".length);
		if (repo.startsWith("https://") || repo.startsWith("http://")) {
			return normalizePluginSourceToken(repo);
		}
		return `github.com/${repo}`.toLowerCase().replace(/\/+$/, "").replace(/\.git$/, "");
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

export function isCustomUserPluginUrl(
	plugin: string,
	installedUserPluginInfos: PluginDefinitionInfo[],
	remotePluginInfos: PluginDefinitionInfo[],
): boolean {
	const userInfo = findUserPluginInfo(plugin, installedUserPluginInfos);
	if (!userInfo?.url) {
		return false;
	}
	const normalizedUser = normalizePluginSourceToken(userInfo.url);
	const remoteTokens = findRemoteSourceTokens(plugin, remotePluginInfos);
	if (remoteTokens.length === 0) {
		return true;
	}
	return !remoteTokens.some(
		(remote) => normalizePluginSourceToken(remote) === normalizedUser,
	);
}
