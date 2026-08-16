import { describe, expect, test } from "vitest";

import {
	compareVersions,
	getMajor,
	isPreReleaseVersion,
	isStableVersion,
	pickLatest,
} from "./version";

// Mirror of src-tauri/src/version.rs tests. The version logic is duplicated in
// Rust (backend) and TS (frontend sorting) — keep both test suites in sync so
// the implementations can't silently drift apart.
describe("compareVersions", () => {
	test("compares numeric parts not lexicographically", () => {
		expect(compareVersions("1.2.3", "1.2.10")).toBeLessThan(0);
		expect(compareVersions("1.10.0", "1.9.0")).toBeGreaterThan(0);
		expect(compareVersions("2.0.0", "2.0.0")).toBe(0);
	});

	test("missing parts count as zero then raw tiebreak", () => {
		expect(compareVersions("1.2", "1.2.0")).toBeLessThan(0);
	});

	test("pre-release sorts below release of same parts", () => {
		expect(compareVersions("2.0.0-rc.1", "2.0.0")).toBeLessThan(0);
		expect(compareVersions("2.0.0", "2.0.0-rc.1")).toBeGreaterThan(0);
	});

	test("non-semver fallback uses natural compare", () => {
		expect(compareVersions("temurin-21", "temurin-8")).toBeGreaterThan(0);
		expect(compareVersions("Temurin-8", "temurin-8")).toBe(0);
	});
});

describe("isPreReleaseVersion", () => {
	test("pre-release detection", () => {
		expect(isPreReleaseVersion("3.0.0-alpha")).toBe(true);
		expect(isPreReleaseVersion("3.13.0a1")).toBe(true);
		expect(isPreReleaseVersion("1.0.0rc2")).toBe(true);
		expect(isPreReleaseVersion("1.2.3")).toBe(false);
		expect(isPreReleaseVersion("1.2.3+build5")).toBe(false);
		expect(isPreReleaseVersion("nightly-2024")).toBe(true);
	});
});

describe("isStableVersion", () => {
	test("stable filter only applies to python and ruby", () => {
		expect(isStableVersion("python", "3.13.0a1")).toBe(false);
		expect(isStableVersion("python", "3.12.1")).toBe(true);
		expect(isStableVersion("ruby", "3.4.0-preview1")).toBe(false);
		expect(isStableVersion("node", "20.0.0-nightly")).toBe(true);
	});
});

describe("getMajor", () => {
	test("major extraction", () => {
		expect(getMajor("10.1.2")).toBe(10);
		expect(getMajor("1")).toBe(1);
		expect(getMajor("v1.2")).toBeNull();
		expect(getMajor("system")).toBeNull();
	});
});

describe("pickLatest", () => {
	test("prefers highest version", () => {
		expect(pickLatest(["1.9.0", "1.10.0", "1.2.0"])).toBe("1.10.0");
		expect(pickLatest([])).toBeNull();
	});
});
