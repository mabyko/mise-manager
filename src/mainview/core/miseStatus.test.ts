import { describe, expect, test } from "vitest";

import {
	getMiseStatusSnapshot,
	normalizeVersionToken,
	type MiseStatusInput,
} from "./miseStatus";

function input(overrides: Partial<MiseStatusInput> = {}): MiseStatusInput {
	return {
		miseNeedsReload: false,
		progressLabel: "Ready",
		miseCurrentError: null,
		miseLatestError: null,
		miseLoaded: true,
		miseLatestLoaded: true,
		miseVersion: "2026.8.6 macos-arm64 (2026-08-14)",
		miseLatestVersion: "v2026.8.7",
		...overrides,
	};
}

describe("normalizeVersionToken", () => {
	test("extracts the semver token from mise output", () => {
		expect(normalizeVersionToken("2026.8.6 macos-arm64 (2026-08-14)")).toBe("2026.8.6");
		expect(normalizeVersionToken("v1.2.3-rc.1")).toBe("1.2.3-rc.1");
		expect(normalizeVersionToken("garbage")).toBeNull();
		expect(normalizeVersionToken(null)).toBeNull();
	});
});

describe("getMiseStatusSnapshot", () => {
	test("update available only when latest is newer", () => {
		const snapshot = getMiseStatusSnapshot(input());
		expect(snapshot.key).toBe("update_available");
		expect(snapshot.canUpdate).toBe(true);
	});

	test("up to date when versions match", () => {
		const snapshot = getMiseStatusSnapshot(input({ miseLatestVersion: "v2026.8.6" }));
		expect(snapshot.key).toBe("up_to_date");
		expect(snapshot.canUpdate).toBe(false);
	});

	test("ahead or custom when current is newer than latest", () => {
		const snapshot = getMiseStatusSnapshot(
			input({ miseVersion: "2026.9.0 macos-arm64", miseLatestVersion: "v2026.8.7" }),
		);
		expect(snapshot.key).toBe("ahead_or_custom");
		expect(snapshot.canUpdate).toBe(false);
	});

	test("needs-reload wins over everything else", () => {
		const snapshot = getMiseStatusSnapshot(input({ miseNeedsReload: true }));
		expect(snapshot.key).toBe("updated_needs_reload");
		expect(snapshot.canUpdate).toBe(false);
	});

	test("self-update in flight reports updating", () => {
		const snapshot = getMiseStatusSnapshot(input({ progressLabel: "Running mise self-update" }));
		expect(snapshot.key).toBe("updating");
	});

	test("any check error blocks updating", () => {
		expect(getMiseStatusSnapshot(input({ miseCurrentError: "boom" })).key).toBe("check_failed");
		expect(getMiseStatusSnapshot(input({ miseLatestError: "boom" })).key).toBe("check_failed");
	});

	test("loading until both versions arrive", () => {
		expect(getMiseStatusSnapshot(input({ miseLoaded: false })).key).toBe("loading");
		expect(getMiseStatusSnapshot(input({ miseLatestLoaded: false })).key).toBe("loading");
	});

	test("unparsable versions are not comparable", () => {
		const snapshot = getMiseStatusSnapshot(input({ miseVersion: "unknown" }));
		expect(snapshot.key).toBe("not_checked");
	});
});
