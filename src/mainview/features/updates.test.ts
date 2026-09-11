import { beforeEach, expect, test, vi } from "vitest";
const calls = vi.hoisted(() => ({ current: vi.fn(), latest: vi.fn(), tools: vi.fn(), toolUpdates: vi.fn(), plugins: vi.fn() }));
vi.mock("./mise", () => ({ reloadMiseVersion: calls.current, checkLatestMiseRelease: calls.latest }));
vi.mock("./updater", () => ({ reloadAndCheckTools: calls.tools, checkUpdates: calls.toolUpdates }));
vi.mock("./installs", () => ({ checkPluginDefinitionUpdates: calls.plugins }));
import { state } from "../core/state.svelte";
import { checkAllUpdates } from "./updates";

beforeEach(() => { vi.resetAllMocks(); Object.assign(state, { busy: false, updateCheckRunning: false, miseIsInstalled: true }); });

test("all update sources are checked once and overlapping checks are skipped", async () => {
	const first = checkAllUpdates();
	await checkAllUpdates();
	await first;
	for (const fn of Object.values(calls)) expect(fn).toHaveBeenCalledTimes(1);
	expect(calls.current.mock.invocationCallOrder[0]).toBeLessThan(calls.tools.mock.invocationCallOrder[0]);
	expect(calls.tools).toHaveBeenCalledWith(false);
	expect(calls.tools.mock.invocationCallOrder[0]).toBeLessThan(calls.latest.mock.invocationCallOrder[0]);
	expect(state.updateCheckRunning).toBe(false);
	state.busy = true;
	await checkAllUpdates();
	expect(calls.current).toHaveBeenCalledTimes(1);
});
