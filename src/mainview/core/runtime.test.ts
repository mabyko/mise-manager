import { beforeEach, expect, test, vi } from "vitest";
import { state } from "./state.svelte";
import { settings } from "./settings.svelte";
import { connectRuntime, runRuntimeAction } from "./runtime.svelte";
import { getUpdateSummary } from "./updateSummary";
import type { PluginRow } from "./types";

const requests = vi.hoisted(() => ({ installPlugin: vi.fn(), listInstalledPlugins: vi.fn(), useGlobalPlugin: vi.fn() }));
vi.mock("./rpc", () => ({ rpc: { request: requests } }));
let node: PluginRow;
beforeEach(() => {
 vi.clearAllMocks();
 node = { name: "node", activeGlobalVersion: "26.0.0", installedVersions: ["26.0.0", "24.20.0"], latestByMajor: { 26: "26.1.0", 24: "24.21.0" }, sameMajorLatest: "26.1.0", releaseLatest: "26.1.0", overallLatest: null, checkedVersions: 20, status: "done" };
 Object.assign(state, { plugins: [node], busy: false, updateCheckRunning: false, pendingDelete: null, pendingMajorUpdate: null, pendingMiseUpdateConfirm: false, pendingPluginUrlDialog: null, outdatedPluginNames: [], miseLatestLoaded: false });
 settings.switchGlobalAfterUpdate = false;
});

test("the owner handles a tray install once, shares its result, and keeps the global default", async () => {
 const channel = new BroadcastChannel("mise-manager-runtime");
 const messages: any[] = [];
 channel.onmessage = event => messages.push(event.data);
 const disconnect = await connectRuntime();
 try {
  let finish!: () => void;
  requests.installPlugin.mockImplementation(() => new Promise<void>(resolve => { finish = resolve; }));
  requests.listInstalledPlugins.mockImplementation(async () => [{ ...node, installedVersions: [...node.installedVersions, "24.21.0"] }]);
  const id = getUpdateSummary(state).items.find(item => item.to === "24.21.0")!.id;
  channel.postMessage({ target: "main", type: "action", payload: { type: "apply", id } });
  await vi.waitFor(() => expect(requests.installPlugin).toHaveBeenCalledTimes(1));
  channel.postMessage({ target: "main", type: "action", payload: { type: "apply", id } });
  finish();
  await vi.waitFor(() => expect(messages.some(message => message.type === "done")).toBe(true));
  expect(requests.installPlugin).toHaveBeenCalledTimes(1);
  expect(requests.useGlobalPlugin).not.toHaveBeenCalled();
  const snapshot = messages.filter(message => message.type === "snapshot").at(-1).payload;
  expect(snapshot.state.plugins[0].installedVersions).toContain("24.21.0");
  expect(snapshot.state.plugins[0].activeGlobalVersion).toBe("26.0.0");
  expect(snapshot.state).not.toHaveProperty("remotePluginInfos");
  expect(getUpdateSummary(state).items.map(item => item.to)).toEqual(["26.1.0"]);
  await runRuntimeAction({ type: "apply", id });
  await runRuntimeAction({ type: "use", name: "node", version: "99.0.0" });
  expect(requests.installPlugin).toHaveBeenCalledTimes(1);
  expect(requests.useGlobalPlugin).not.toHaveBeenCalled();
  state.updateCheckRunning = true;
  await runRuntimeAction({ type: "apply", id: getUpdateSummary(state).items[0]!.id });
  expect(requests.installPlugin).toHaveBeenCalledTimes(1);
 } finally { state.updateCheckRunning = false; disconnect(); channel.close(); }
});
