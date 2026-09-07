import { expect, test } from "vitest";
import { getToolUpdate, getToolStatus } from "./toolStatus";
import type { PluginRow } from "./types";

const node: PluginRow = {
	name: "node", activeGlobalVersion: "22.14.0", installedVersions: ["22.14.0"],
	sameMajorLatest: "22.15.0", releaseLatest: "24.0.0", overallLatest: "25.0.0-rc.1",
	checkedVersions: 10, status: "done",
};

test("stable update plan separates same-major and major upgrades, using the installed fallback", () => {
	expect(getToolUpdate(node)).toEqual({ primary: "22.15.0", major: "24.0.0" });
	expect(getToolUpdate({ ...node, activeGlobalVersion: null })).toEqual(getToolUpdate(node));
	expect(getToolUpdate({ ...node, sameMajorLatest: "22.14.0" })).toEqual({ primary: null, major: "24.0.0" });
	expect(getToolUpdate({ ...node, releaseLatest: "22.15.0" })).toEqual({ primary: "22.15.0", major: null });
	expect(getToolUpdate({ ...node, sameMajorLatest: "22.14.0", releaseLatest: "22.14.0" })).toBeNull();
});

test("failed, unfinished and channel checks never expose cached update actions", () => {
	for (const status of ["idle", "checking", "updating", "deleting", "error"] as const) {
		expect(getToolUpdate({ ...node, status })).toBeNull();
		expect(getToolStatus({ ...node, status })).not.toBe("최신 안정 버전");
	}
	expect(getToolUpdate({ ...node, activeGlobalVersion: "stable" })).toBeNull();
	expect(getToolUpdate({ ...node, activeGlobalVersion: null, installedVersions: [] })).toBeNull();
	expect(getToolStatus({ ...node, activeGlobalVersion: "stable" })).toBe("채널 버전");
});

test("tool labels distinguish updates, missing comparisons and prereleases from current stable versions", () => {
	expect(getToolStatus(node)).toBe("업데이트");
	expect(getToolStatus({ ...node, sameMajorLatest: null, releaseLatest: null })).toBe("비교 정보 없음");
	expect(getToolStatus({ ...node, activeGlobalVersion: "25.0.0-rc.1" })).toBe("프리릴리스 사용");
	expect(getToolStatus({ ...node, activeGlobalVersion: "24.0.0" })).toBe("최신 안정 버전");
});
