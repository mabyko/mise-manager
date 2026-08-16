import { compareVersions } from "../../shared/version";
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
		if (!base) {
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
