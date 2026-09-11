import { beforeEach, describe, expect, test, vi } from "vitest";

const rpcRequest = vi.hoisted(() => ({
	listInstalledPlugins: vi.fn<() => Promise<unknown>>(),
	checkPluginUpdates: vi.fn<(params: unknown) => Promise<unknown>>(),
	installPlugin: vi.fn<(params: unknown) => Promise<unknown>>(),
	useGlobalPlugin: vi.fn<(params: unknown) => Promise<unknown>>(),
	deletePluginVersion: vi.fn<(params: unknown) => Promise<unknown>>(),
}));
vi.mock("../core/rpc", () => ({ rpc: { request: rpcRequest } }));

import { state } from "../core/state.svelte";
import type { PluginRow } from "../core/types";
import { getToolUpdate } from "../core/toolStatus";
import { settings } from "../core/settings.svelte";
import {
	deleteInstalledVersion,
	installVersion,
	reloadAndCheckTools,
	retryCheck,
	updateToVersion,
	useInstalledVersion,
	updateInstalledSeries,
} from "./updater";

const row = (patch: Partial<PluginRow> = {}): PluginRow => ({
	name: "node",
	latestByMajor: {},
	activeGlobalVersion: "22.14.0",
	installedVersions: ["22.14.0"],
	sameMajorLatest: "22.15.0",
	releaseLatest: "24.0.0",
	overallLatest: null,
	checkedVersions: 10,
	status: "done",
	...patch,
});
const node = () => state.plugins.find((plugin) => plugin.name === "node");

describe("updater", () => {
	beforeEach(() => {
		settings.switchGlobalAfterUpdate = false;
		Object.assign(state, {
			busy: false,
			progress: null,
			progressLabel: "Ready",
			toolsLoaded: false,
			toolsError: null,
			logs: [],
			plugins: [row()],
			pendingDelete: null,
			pendingMajorUpdate: null,
		});
		for (const fn of Object.values(rpcRequest)) fn.mockReset();
		// What mise reports after the action: the new version landed on disk.
		rpcRequest.listInstalledPlugins.mockResolvedValue([
			{ name: "node", activeGlobalVersion: "22.14.0", installedVersions: ["22.15.0", "22.14.0"] },
		]);
		rpcRequest.installPlugin.mockResolvedValue({});
		rpcRequest.useGlobalPlugin.mockResolvedValue({});
		rpcRequest.deletePluginVersion.mockResolvedValue({});
		rpcRequest.checkPluginUpdates.mockResolvedValue({
			sameMajorLatest: "22.15.0", releaseLatest: "24.0.0", overallLatest: null, checkedVersions: 3,
		});
	});

	test("updating an older installed major preserves the global version even with automatic switching enabled", async () => {
		settings.switchGlobalAfterUpdate = true;
		state.plugins = [row({ activeGlobalVersion: "26.0.0", installedVersions: ["26.0.0", "24.20.0"], latestByMajor: { 24: "24.21.0", 26: "26.1.0" } })];
		rpcRequest.listInstalledPlugins.mockResolvedValue([{ name: "node", activeGlobalVersion: "26.0.0", installedVersions: ["26.0.0", "24.21.0", "24.20.0"] }]);
		await updateInstalledSeries("node", "24.21.0");
		expect(rpcRequest.installPlugin).toHaveBeenCalledWith({ plugin: "node", targetVersion: "24.21.0" });
		expect(rpcRequest.useGlobalPlugin).not.toHaveBeenCalled();
		expect(node()?.activeGlobalVersion).toBe("26.0.0");
		expect(node()?.installedVersions).toContain("24.20.0");
		await updateInstalledSeries("node", "24.21.0");
		await updateInstalledSeries("node", "27.0.0");
		expect(rpcRequest.installPlugin).toHaveBeenCalledTimes(1);
	});

	test("series updates install only by default and switch the active major only when enabled", async () => {
		state.plugins = [row({ latestByMajor: { 22: "22.15.0" } })];
		await updateInstalledSeries("node", "22.15.0");
		expect(rpcRequest.useGlobalPlugin).not.toHaveBeenCalled();
		state.plugins = [row({ latestByMajor: { 22: "22.15.0" } })];
		settings.switchGlobalAfterUpdate = true;
		await updateInstalledSeries("node", "22.15.0");
		expect(rpcRequest.useGlobalPlugin).toHaveBeenCalledWith({ plugin: "node", targetVersion: "22.15.0" });
	});

	test("update keeps the installed version visible when switching global fails", async () => {
		rpcRequest.useGlobalPlugin.mockRejectedValue(new Error("use exploded"));

		await updateToVersion("node", "22.15.0");

		expect(rpcRequest.installPlugin).toHaveBeenCalledWith({ plugin: "node", targetVersion: "22.15.0" });
		expect(node()).toMatchObject({ status: "error", error: "use exploded", installedVersions: ["22.15.0", "22.14.0"] });
		expect(state.logs[0]).toContain("installed 22.15.0 but switching global failed - use exploded");
		expect(state.busy).toBe(false);
	});

	test("update stops before switching global when the install fails", async () => {
		rpcRequest.installPlugin.mockRejectedValue(new Error("install exploded"));

		await updateToVersion("node", "22.15.0");

		expect(rpcRequest.useGlobalPlugin).not.toHaveBeenCalled();
		expect(node()).toMatchObject({ status: "error", error: "install exploded" });
		expect(state.logs[0]).toContain("install failed - install exploded");
		expect(state.busy).toBe(false);
	});

	test("successful update re-reads the row from mise and clears a stale error", async () => {
		state.plugins = [row({ status: "error", error: "old" })];
		rpcRequest.listInstalledPlugins.mockResolvedValue([
			{ name: "node", activeGlobalVersion: "22.15.0", installedVersions: ["22.15.0", "22.14.0"] },
		]);

		await updateToVersion("node", "22.15.0");

		// The base moved (22.14 -> 22.15), so the candidates are re-checked against the new base.
		expect(rpcRequest.checkPluginUpdates).toHaveBeenCalledWith({ plugin: "node", baseVersion: "22.15.0", includeChannels: false });
		expect(node()).toMatchObject({ status: "done", error: undefined, activeGlobalVersion: "22.15.0", checkedVersions: 3 });
		expect(state.logs[1]).toContain("updated to 22.15.0");
		expect(state.logs[0]).toContain("checked 3 version(s), base=22.15.0");
	});

	test("a refresh failure after a successful command is reported as a refresh failure", async () => {
		rpcRequest.listInstalledPlugins.mockRejectedValue(new Error("ls exploded"));

		await useInstalledVersion("node", "22.14.0");

		expect(state.logs[1]).toContain("switched global version to 22.14.0");
		expect(node()).toMatchObject({ status: "error", error: "refresh failed after success - ls exploded" });
		expect(state.logs[0]).toContain("refresh failed after success - ls exploded");
		expect(state.busy).toBe(false);
	});

	test("install-only keeps the verified candidates when the base version does not move", async () => {
		await installVersion("node", "24.0.0");

		expect(rpcRequest.installPlugin).toHaveBeenCalledWith({ plugin: "node", targetVersion: "24.0.0" });
		expect(rpcRequest.checkPluginUpdates).not.toHaveBeenCalled();
		expect(node()).toMatchObject({ status: "done", sameMajorLatest: "22.15.0", installedVersions: ["22.15.0", "22.14.0"] });
		expect(state.logs[0]).toContain("installed 24.0.0.");
		expect(state.busy).toBe(false);
	});

	test("switching global to another major re-checks candidates for the new base", async () => {
		state.plugins = [row({ installedVersions: ["22.14.0", "20.19.0"] })];
		rpcRequest.listInstalledPlugins.mockResolvedValue([
			{ name: "node", activeGlobalVersion: "20.19.0", installedVersions: ["22.14.0", "20.19.0"] },
		]);
		rpcRequest.checkPluginUpdates.mockResolvedValue({
			sameMajorLatest: "20.20.0", releaseLatest: "24.0.0", overallLatest: null, checkedVersions: 5,
		});

		await useInstalledVersion("node", "20.19.0");

		expect(rpcRequest.checkPluginUpdates).toHaveBeenCalledWith({ plugin: "node", baseVersion: "20.19.0", includeChannels: false });
		expect(node()).toMatchObject({ status: "done", activeGlobalVersion: "20.19.0", sameMajorLatest: "20.20.0" });
		expect(getToolUpdate(node()!)).toEqual({ primary: "20.20.0", major: "24.0.0" });
	});

	test("a failed command whose base still moved drops the stale candidates", async () => {
		state.plugins = [row({ installedVersions: ["22.14.0", "20.19.0"] })];
		rpcRequest.useGlobalPlugin.mockRejectedValue(new Error("use exploded"));
		rpcRequest.listInstalledPlugins.mockResolvedValue([
			{ name: "node", activeGlobalVersion: "20.19.0", installedVersions: ["22.14.0", "20.19.0"] },
		]);

		await useInstalledVersion("node", "20.19.0");

		expect(rpcRequest.checkPluginUpdates).not.toHaveBeenCalled();
		expect(node()).toMatchObject({ status: "error", error: "use exploded", activeGlobalVersion: "20.19.0", sameMajorLatest: null, releaseLatest: null });
		expect(getToolUpdate(node()!)).toBeNull();
	});

	test("a row whose last check failed is re-checked after a successful command", async () => {
		state.plugins = [row({ status: "error", error: "network down" })];

		await installVersion("node", "22.15.0");

		expect(rpcRequest.checkPluginUpdates).toHaveBeenCalledWith({ plugin: "node", baseVersion: "22.14.0", includeChannels: false });
		expect(node()).toMatchObject({ status: "done", error: undefined, checkedVersions: 3 });
	});

	test("retry reconciles versions from mise before checking, and keeps a refresh failure", async () => {
		state.plugins = [row({ status: "error", error: "refresh failed after success - ls exploded" })];

		await retryCheck("node");
		expect(rpcRequest.listInstalledPlugins).toHaveBeenCalledTimes(1);
		expect(rpcRequest.checkPluginUpdates).toHaveBeenCalledWith({ plugin: "node", baseVersion: "22.14.0", includeChannels: false });
		expect(node()).toMatchObject({ status: "done", error: undefined, installedVersions: ["22.15.0", "22.14.0"] });
		expect(state).toMatchObject({ busy: false, progressLabel: "Check complete" });

		rpcRequest.listInstalledPlugins.mockRejectedValue(new Error("ls exploded again"));
		await retryCheck("node");
		expect(rpcRequest.checkPluginUpdates).toHaveBeenCalledTimes(1);
		expect(node()).toMatchObject({ status: "error", error: "refresh failed - ls exploded again" });
		expect(state.busy).toBe(false);
	});

	test("delete refuses the active global version and drops a tool mise no longer lists", async () => {
		await deleteInstalledVersion("node", "22.14.0");
		expect(rpcRequest.deletePluginVersion).not.toHaveBeenCalled();

		state.plugins = [row({ activeGlobalVersion: null, installedVersions: ["22.14.0"] })];
		rpcRequest.listInstalledPlugins.mockResolvedValue([]);
		await deleteInstalledVersion("node", "22.14.0");
		expect(rpcRequest.deletePluginVersion).toHaveBeenCalledWith({ plugin: "node", targetVersion: "22.14.0" });
		expect(node()).toBeUndefined();
		expect(state.busy).toBe(false);
	});

	test("actions are no-ops while another action is running", async () => {
		state.busy = true;
		await useInstalledVersion("node", "22.14.0");
		await reloadAndCheckTools();
		expect(rpcRequest.useGlobalPlugin).not.toHaveBeenCalled();
		expect(rpcRequest.listInstalledPlugins).not.toHaveBeenCalled();
	});

	test("reload records a load error and skips checks; a good load checks every tool", async () => {
		rpcRequest.listInstalledPlugins.mockRejectedValueOnce(new Error("mise missing"));
		await reloadAndCheckTools();
		expect(state).toMatchObject({ toolsLoaded: true, toolsError: "mise missing", busy: false });
		expect(rpcRequest.checkPluginUpdates).not.toHaveBeenCalled();

		await reloadAndCheckTools();
		expect(state.toolsError).toBeNull();
		expect(rpcRequest.checkPluginUpdates).toHaveBeenCalledWith({ plugin: "node", baseVersion: "22.14.0", includeChannels: false });
		expect(node()).toMatchObject({ status: "done", checkedVersions: 3, installedVersions: ["22.15.0", "22.14.0"] });
		expect(state).toMatchObject({ busy: false, progressLabel: "Check complete", progress: 100 });
	});
});
