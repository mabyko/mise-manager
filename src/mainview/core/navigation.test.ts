import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { flushSync, mount, tick, unmount } from "svelte";
import App from "../App.svelte";
import { state } from "./state.svelte";
import type { PluginRow } from "./types";

const requests = vi.hoisted(() => ({
	installPlugin: vi.fn(), useGlobalPlugin: vi.fn(), deletePluginVersion: vi.fn(), selfUpdateMise: vi.fn(),
}));
vi.mock("./rpc", () => ({ rpc: { request: requests } }));

let app: ReturnType<typeof mount>;
const tool = (name: string, current: string, target = current): PluginRow => ({
	name, activeGlobalVersion: current, installedVersions: [current], sameMajorLatest: target,
	releaseLatest: target, overallLatest: null, checkedVersions: 10, status: "done",
});
const button = (label: string) => [...document.querySelectorAll<HTMLButtonElement>("button")].find(b => b.textContent?.trim() === label)!;

beforeEach(async () => {
	vi.clearAllMocks();
	Object.assign(state, {
		activeTab: "overview", selectedToolName: null, toolSearchQuery: "", toolUpdatesOnly: false,
		busy: false, progress: null, progressLabel: "Ready", toolsLoaded: true, toolsError: null,
		toolsCheckedAt: null, updaterAutoChecked: true, installsLoaded: true, logs: [],
		miseIsInstalled: true, miseInstalledChecked: true, miseLoaded: true, miseLatestLoaded: true,
		miseCurrentError: null, miseLatestError: null, miseNeedsReload: false, miseLastResult: "",
		miseVersion: "2026.8.12", miseLatestVersion: "2026.8.13", pendingMiseUpdateConfirm: false,
		pendingMajorUpdate: null, pendingDelete: null, pendingPluginUrlDialog: null,
		plugins: [
			{ ...tool("node", "22.14.0", "22.15.0"), releaseLatest: "24.0.0", installedVersions: ["22.14.0", "20.19.0"] },
			tool("python", "3.12.8", "3.13.2"), tool("bun", "1.2.4"),
		],
	});
	app = mount(App, { target: document.body });
	flushSync();
	await tick();
});
afterEach(async () => { await unmount(app); document.body.innerHTML = ""; });

test("overview links select the tool; searches have no stale actions and survive navigation", async () => {
	(document.querySelectorAll<HTMLButtonElement>(".overview-tool")[1]).click();
	flushSync(); await tick();
	expect(document.querySelector(".tool-detail h2")?.textContent).toBe("python");
	const bun = [...document.querySelectorAll<HTMLButtonElement>(".tool-item")].find(b => b.textContent?.includes("bun"))!;
	bun.focus(); bun.click(); flushSync();
	expect(document.activeElement).toBe(bun);
	expect(document.querySelector(".tool-detail h2")?.textContent).toBe("bun");

	const search = document.querySelector<HTMLInputElement>("#tool-search")!;
	search.value = "bun"; search.dispatchEvent(new Event("input", { bubbles: true }));
	const filter = document.querySelector<HTMLInputElement>('input[type="checkbox"]')!;
	filter.click(); flushSync();
	expect(state.toolSearchQuery).toBe("bun");
	expect(document.querySelector(".tool-detail")?.textContent).toContain("조건에 맞는 도구가 없어요");
	expect(document.querySelector(".tool-detail")?.textContent).not.toContain("으로 업데이트");
	button("요약").click(); flushSync(); await tick();
	(document.querySelectorAll<HTMLButtonElement>("nav button")[1]).click(); flushSync(); await tick();
	expect(document.querySelector<HTMLInputElement>("#tool-search")?.value).toBe("bun");
	expect(document.querySelector<HTMLInputElement>('input[type="checkbox"]')?.checked).toBe(true);
	button("검색·필터 초기화").click(); flushSync(); await tick();
	expect(document.querySelector(".tool-detail h2")?.textContent).toBe("bun");
	await vi.waitFor(() => expect(document.activeElement?.id).toBe("tool-search"));
});

test("major and mise actions require confirmation; active global versions have no delete action", async () => {
	(document.querySelector<HTMLButtonElement>(".overview-tool"))!.click(); flushSync(); await tick();
	expect(document.querySelector('[aria-label="node 22.14.0 삭제"]')).toBeNull();
	expect(document.querySelector('[aria-label="node 20.19.0 삭제"]')).not.toBeNull();
	button("변경 검토…").focus(); button("변경 검토…").click(); flushSync();
	expect(document.querySelector<HTMLDialogElement>("dialog")?.open).toBe(true);
	expect(state.pendingMajorUpdate?.targetVersion).toBe("24.0.0");
	expect(requests.installPlugin).not.toHaveBeenCalled();
	button("취소").click(); flushSync();
	expect(state.pendingMajorUpdate).toBeNull();
	expect(document.activeElement?.textContent).toBe("변경 검토…");
	button("요약").click(); flushSync(); await tick();
	button("mise 업데이트…").click(); flushSync();
	expect(document.querySelector("dialog")?.textContent).toContain("2026.8.12 → 2026.8.13");
	const cancel = new Event("cancel", { cancelable: true });
	document.querySelector("dialog")!.dispatchEvent(cancel); flushSync();
	expect(state.pendingMiseUpdateConfirm).toBe(false);
	expect(requests.selfUpdateMise).not.toHaveBeenCalled();
});

test("overview surfaces failed and unknown checks instead of claiming all tools are current", () => {
	state.plugins = [
		{ ...tool("ruby", "3.4.2"), status: "error", error: "registry timeout" },
		{ ...tool("node", "22.14.0", "22.15.0"), status: "checking" },
		tool("flutter", "stable"),
	];
	flushSync();
	expect(document.querySelector(".overview-intro")?.textContent).toContain("확인이 필요한 도구");
	expect(document.querySelector(".overview-counts")?.textContent).toMatch(/0\s+최신 안정 버전/);
	expect(document.querySelector(".overview-tool")?.textContent).toContain("확인 실패");
	expect(document.querySelector(".overview-counts")?.textContent).toMatch(/2\s+확인 필요/);
});
