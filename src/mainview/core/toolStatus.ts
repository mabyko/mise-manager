import { compareVersions, getMajor, isPreReleaseVersion } from "../../shared/version";
import { resolveBaseVersion } from "./helpers";
import type { PluginRow } from "./types";

/** Verified stable updates; prereleases remain separate in the version inspector. */
export function getToolUpdate(plugin: PluginRow): { primary: string | null; major: string | null } | null {
	const base = resolveBaseVersion(plugin);
	if (plugin.status !== "done" || !base || getMajor(base) === null) return null;
	const primary = plugin.sameMajorLatest && compareVersions(plugin.sameMajorLatest, base) > 0
		? plugin.sameMajorLatest : null;
	const major = plugin.releaseLatest && compareVersions(plugin.releaseLatest, primary ?? base) > 0
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
	if (getToolUpdate(plugin)) return "업데이트";
	if (!plugin.sameMajorLatest && !plugin.releaseLatest) return "비교 정보 없음";
	if (isPreReleaseVersion(base!)) return "프리릴리스 사용";
	return "최신 안정 버전";
}
