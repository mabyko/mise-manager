import { getInstalledSeries, getToolUpdate } from "./toolStatus";
import { getMiseStatusSnapshot, normalizeVersionToken } from "./miseStatus";
import type { MainViewState } from "./types";

export interface UpdateItem {
	id: string;
	kind: "series" | "major" | "mise" | "plugin";
	name: string;
	label: string;
	from: string;
	to: string;
}

/** The app, popover and menu-bar count all describe the same pending installs. */
export function getUpdateSummary(state: MainViewState) {
	const items: UpdateItem[] = [];
	for (const tool of state.plugins) {
		for (const series of getInstalledSeries(tool)) {
			if (series.update) items.push({ id: JSON.stringify([tool.name, series.update]), kind: "series", name: tool.name, label: `${tool.name} ${series.major}.x`, from: series.current, to: series.update });
		}
		const major = getToolUpdate(tool)?.major;
		if (major && !items.some(item => item.name === tool.name && item.to === major)) {
			items.push({ id: JSON.stringify([tool.name, major]), kind: "major", name: tool.name, label: `${tool.name} · 새 major`, from: tool.activeGlobalVersion ?? "미선택", to: major });
		}
	}
	const mise = getMiseStatusSnapshot(state);
	if (mise.canUpdate) items.push({ id: "mise", kind: "mise", name: "mise", label: "mise", from: normalizeVersionToken(state.miseVersion)!, to: normalizeVersionToken(state.miseLatestVersion)! });
	if (!state.pluginUpdatesError) for (const name of state.outdatedPluginNames) {
		items.push({ id: JSON.stringify(["plugin", name]), kind: "plugin", name, label: `${name} · 플러그인`, from: "설치된 소스", to: "최신 소스" });
	}
	const errors = [state.toolsError, state.miseCurrentError, state.miseLatestError, state.pluginUpdatesError,
		...state.plugins.filter(p => p.status === "error").map(p => `${p.name}: ${p.error ?? "확인 실패"}`)].filter(Boolean) as string[];
	const unchecked = !state.toolsLoaded || !state.toolsCheckedAt || !state.miseLatestCheckedAt || !state.pluginUpdatesCheckedAt ||
		!["up_to_date", "ahead_or_custom", "update_available", "updated_needs_reload"].includes(mise.key) ||
		state.plugins.some(p => p.status !== "done" || (!p.sameMajorLatest && !p.releaseLatest && !Object.keys(p.latestByMajor).length));
	return { items, errors, attention: unchecked || errors.length > 0 };
}
