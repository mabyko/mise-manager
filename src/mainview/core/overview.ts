import { compareVersions, getMajor, isPreReleaseVersion } from "../../shared/version";
import { resolveBaseVersion } from "./helpers";
import type { PluginRow } from "./types";

export interface OverviewRow {
	plugin: string;
	current: string | null;
	/** Safe one-click candidate: same-major latest newer than the base. */
	primary: string | null;
	/** Major candidate (release latest beyond primary/base); goes through a confirm dialog. */
	major: string | null;
	error?: string;
}

// Overview "Available Updates" rules, agreed in the design prototype:
// same-major is the primary one-click action, majors are secondary and
// confirmed, pre-releases never appear here (Updater tab only).
export function buildOverviewRows(plugins: PluginRow[]): OverviewRow[] {
	const rows: OverviewRow[] = [];
	for (const plugin of plugins) {
		const base = resolveBaseVersion(plugin);
		const current = plugin.activeGlobalVersion ?? base;

		if (plugin.status === "error") {
			rows.push({
				plugin: plugin.name,
				current,
				primary: null,
				major: null,
				error: plugin.error ?? "check failed",
			});
			continue;
		}
		// Old candidates remain cached during a new check; don't present them as verified.
		if (plugin.status !== "done") {
			continue;
		}
		if (!base || getMajor(base) === null) {
			continue;
		}

		const primary =
			plugin.sameMajorLatest && compareVersions(plugin.sameMajorLatest, base) > 0
				? plugin.sameMajorLatest
				: null;
		const majorRef = primary ?? base;
		const major =
			plugin.releaseLatest && compareVersions(plugin.releaseLatest, majorRef) > 0
				? plugin.releaseLatest
				: null;

		if (primary || major) {
			rows.push({ plugin: plugin.name, current, primary, major });
		}
	}
	return rows;
}

export function getToolStatus(plugin: PluginRow): string {
	if (plugin.status === "error") return "확인 실패";
	if (plugin.status === "checking") return "확인 중";
	if (plugin.status === "updating") return "변경 중";
	if (plugin.status === "deleting") return "삭제 중";
	if (plugin.status !== "done") return "미확인";
	if (getMajor(resolveBaseVersion(plugin) ?? "") === null) return "채널 버전";
	if (buildOverviewRows([plugin]).length) return "업데이트";
	if (!plugin.sameMajorLatest && !plugin.releaseLatest) return "비교 정보 없음";
	if (isPreReleaseVersion(resolveBaseVersion(plugin)!)) return "프리릴리스 사용";
	return "최신 안정 버전";
}
