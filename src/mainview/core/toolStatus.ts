import { compareVersions, getMajor, isPreReleaseVersion } from "../../shared/version";
import { resolveBaseVersion } from "./helpers";
import type { PluginRow } from "./types";

/** Each installed major is tracked independently, including non-global versions. */
export function getInstalledSeries(plugin: PluginRow) {
	const installed = new Map<number, string>();
	for (const version of plugin.installedVersions) {
		const major = getMajor(version);
		if (major === null) continue;
		const previous = installed.get(major);
		if (!previous || compareVersions(version, previous) > 0) installed.set(major, version);
	}
	return [...installed].sort(([a], [b]) => b - a).map(([major, current]) => {
		const candidate = plugin.latestByMajor[major] ?? (getMajor(resolveBaseVersion(plugin) ?? "") === major ? plugin.sameMajorLatest : null);
		const latest = plugin.status === "done" && candidate && !isPreReleaseVersion(candidate) ? candidate : null;
		return { major, current, latest, update: latest && compareVersions(latest, current) > 0 ? latest : null };
	});
}

export function hasToolUpdates(plugin: PluginRow): boolean {
	return !!getToolUpdate(plugin) || getInstalledSeries(plugin).some(series => series.update);
}

/** Verified stable updates; prereleases remain separate in the version inspector. */
export function getToolUpdate(plugin: PluginRow): { primary: string | null; major: string | null } | null {
	const base = resolveBaseVersion(plugin);
	if (plugin.status !== "done" || !base || getMajor(base) === null) return null;
	const needsInstall = (version: string) => !plugin.installedVersions.some(installed =>
		getMajor(installed) === getMajor(version) && compareVersions(installed, version) >= 0);
	const primary = plugin.sameMajorLatest && needsInstall(plugin.sameMajorLatest) && !isPreReleaseVersion(plugin.sameMajorLatest) && compareVersions(plugin.sameMajorLatest, base) > 0
		? plugin.sameMajorLatest : null;
	const major = plugin.releaseLatest && needsInstall(plugin.releaseLatest) && !isPreReleaseVersion(plugin.releaseLatest) && getMajor(plugin.releaseLatest)! > getMajor(base)! && compareVersions(plugin.releaseLatest, base) > 0
		? plugin.releaseLatest : null;
	return primary || major ? { primary, major } : null;
}

export function getToolStatus(plugin: PluginRow): string {
	if (plugin.status === "error") return "확인 실패";
	if (plugin.status === "checking") return "확인 중";
	if (plugin.status === "updating") return "변경 중";
	if (plugin.status === "deleting") return "삭제 중";
	if (plugin.status !== "done") return "미확인";
	const base = resolveBaseVersion(plugin);
	if (getMajor(base ?? "") === null) return "채널 버전";
	if (hasToolUpdates(plugin)) return "업데이트";
	if (!plugin.sameMajorLatest && !plugin.releaseLatest) return "비교 정보 없음";
	if (isPreReleaseVersion(base!)) return "프리릴리스 사용";
	return "최신 안정 버전";
}
