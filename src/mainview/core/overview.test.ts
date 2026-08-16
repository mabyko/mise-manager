import { describe, expect, test } from "vitest";

import { buildOverviewRows } from "./overview";
import type { PluginRow } from "./types";

// Overview rules agreed in the design prototype: same-major is the primary
// one-click candidate, majors are secondary (confirmed), pre-releases hidden.
function row(partial: Partial<PluginRow> & { name: string }): PluginRow {
	return {
		activeGlobalVersion: null,
		installedVersions: [],
		sameMajorLatest: null,
		releaseLatest: null,
		overallLatest: null,
		checkedVersions: 0,
		status: "done",
		...partial,
	};
}

describe("buildOverviewRows", () => {
	test("same-major is primary, newer release becomes the major candidate", () => {
		const rows = buildOverviewRows([
			row({
				name: "node",
				activeGlobalVersion: "20.11.1",
				installedVersions: ["20.11.1"],
				sameMajorLatest: "20.12.2",
				releaseLatest: "22.3.0",
			}),
		]);
		expect(rows).toEqual([
			{ plugin: "node", current: "20.11.1", primary: "20.12.2", major: "22.3.0" },
		]);
	});

	test("major-only when same-major equals the base", () => {
		const rows = buildOverviewRows([
			row({
				name: "python",
				activeGlobalVersion: "2.7.18",
				installedVersions: ["2.7.18"],
				sameMajorLatest: "2.7.18",
				releaseLatest: "3.12.1",
			}),
		]);
		expect(rows[0].primary).toBeNull();
		expect(rows[0].major).toBe("3.12.1");
	});

	test("up-to-date plugins and pre-release-only candidates are excluded", () => {
		const rows = buildOverviewRows([
			row({
				name: "deno",
				activeGlobalVersion: "1.44.0",
				installedVersions: ["1.44.0"],
				sameMajorLatest: "1.44.0",
				releaseLatest: "1.44.0",
				overallLatest: "2.0.0-rc.1",
			}),
		]);
		expect(rows).toEqual([]);
	});

	test("error rows carry the error and no candidates", () => {
		const rows = buildOverviewRows([
			row({
				name: "terraform",
				activeGlobalVersion: "1.7.5",
				status: "error",
				error: "registry timeout",
			}),
		]);
		expect(rows).toEqual([
			{ plugin: "terraform", current: "1.7.5", primary: null, major: null, error: "registry timeout" },
		]);
	});

	test("falls back to installed versions when no active global exists", () => {
		const rows = buildOverviewRows([
			row({
				name: "zig",
				installedVersions: ["0.12.0"],
				sameMajorLatest: "0.13.0",
			}),
		]);
		expect(rows[0].current).toBe("0.12.0");
		expect(rows[0].primary).toBe("0.13.0");
	});
});
