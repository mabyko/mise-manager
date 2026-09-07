import { beforeEach, describe, expect, test, vi } from "vitest";
import { flushSync, mount, unmount } from "svelte";

const rpcRequest = vi.hoisted(() => ({
	installPluginDefinition: vi.fn<(params: unknown) => Promise<unknown>>(),
	uninstallPluginDefinition: vi.fn<(params: unknown) => Promise<unknown>>(),
	listInstalledPluginNames: vi.fn<() => Promise<unknown>>(),
	listInstalledUserPluginInfos: vi.fn<() => Promise<unknown>>(),
	listCorePluginNames: vi.fn<() => Promise<unknown>>(),
	listInstalledToolNames: vi.fn<() => Promise<unknown>>(),
	listRemotePluginNames: vi.fn<() => Promise<unknown>>(),
	listRemotePluginInfos: vi.fn<() => Promise<unknown>>(),
}));

vi.mock("../core/rpc", () => ({ rpc: { request: rpcRequest } }));

import { state } from "../core/state.svelte";
import { resolvePluginInstallPlan, submitPluginUrlDialog } from "./installs";
import InstallsTab from "../components/InstallsTab.svelte";

function renderComponent(component: unknown): string {
	const instance = mount(component as never, { target: document.body });
	flushSync();
	const html = document.body.innerHTML;
	unmount(instance);
	document.body.innerHTML = "";
	return html;
}

describe("installs", () => {
	beforeEach(() => {
		document.body.innerHTML = "";
		Object.assign(state, {
			busy: false,
			activeTab: "installs",
			pluginSearchQuery: "",
			remotePluginNames: [],
			installedPluginNames: [],
			corePluginNames: [],
			installedToolNames: [],
			remotePluginInfos: [],
			installedUserPluginInfos: [],
			pendingPluginUrlDialog: null,
			pendingPluginNameValue: "",
			pendingPluginUrlValue: "",
			logs: [],
			progressLabel: "Ready",
			progress: 0,
			installsLoaded: false,
		});
		for (const fn of Object.values(rpcRequest)) {
			fn.mockReset();
		}
		rpcRequest.installPluginDefinition.mockResolvedValue({ plugin: "plugin", stdout: "" });
		rpcRequest.uninstallPluginDefinition.mockResolvedValue({ plugin: "plugin", stdout: "" });
		rpcRequest.listInstalledPluginNames.mockResolvedValue([]);
		rpcRequest.listInstalledUserPluginInfos.mockResolvedValue([]);
		rpcRequest.listCorePluginNames.mockResolvedValue([]);
		rpcRequest.listInstalledToolNames.mockResolvedValue([]);
		rpcRequest.listRemotePluginNames.mockResolvedValue([]);
		rpcRequest.listRemotePluginInfos.mockResolvedValue([]);
	});

	test("shows custom plugin install action beside plugin search controls", () => {
		state.remotePluginNames = ["node", "python"];

		const html = renderComponent(InstallsTab);

		expect(html).toContain("사용자 플러그인 추가");
		expect(html).toContain("icon-btn");
		expect(html).toContain('aria-label="목록 새로고침"');
		expect(html).toContain("↻");
		expect(html.indexOf("사용자 플러그인 추가")).toBeLessThan(
			html.indexOf("목록 새로고침"),
		);
	});

	test("offers custom plugin install when search has no catalog matches", () => {
		state.pluginSearchQuery = "zoxide";
		state.remotePluginNames = ["node", "python"];

		const html = renderComponent(InstallsTab);

		expect(html).toContain("사용자 플러그인 추가");
		expect(html).toContain("검색 결과가 없습니다.");
	});

	test("keeps action buttons inside wrapper so table cells keep table layout", () => {
		state.remotePluginNames = ["node"];

		const html = renderComponent(InstallsTab);

		expect(html).toContain('class="actions"');
		expect(html).toContain('class="row-actions"');
		expect(html).toContain("플러그인 설치");
	});

	test("normalizes custom install shorthand and clears busy after reload", async () => {
		rpcRequest.installPluginDefinition.mockResolvedValue({ plugin: "zoxide", stdout: "" });
		rpcRequest.listInstalledPluginNames.mockResolvedValue(["zoxide"]);
		state.pendingPluginUrlDialog = { mode: "custom-install" };
		state.pendingPluginNameValue = "zoxide";
		state.pendingPluginUrlValue = "nyrst/asdf-zoxide.git";

		await submitPluginUrlDialog();

		expect(rpcRequest.installPluginDefinition).toHaveBeenCalledTimes(1);
		expect(rpcRequest.installPluginDefinition.mock.calls[0][0]).toEqual({
			plugin: "zoxide",
			gitUrl: "https://github.com/nyrst/asdf-zoxide.git",
			force: false,
		});
		expect(state.busy).toBe(false);
	});

	test("uses default install and removes tool_alias when edit URL matches remote default", async () => {
		rpcRequest.installPluginDefinition.mockResolvedValue({
			plugin: "flutter",
			stdout: "Removed tool_alias from /tmp/config.toml.",
		});
		state.installedUserPluginInfos = [
			{
				name: "flutter",
				url: "https://github.com/asdf-community/asdf-flutter.git",
				source: "tool_alias",
			},
		];
		state.remotePluginInfos = [
			{
				name: "flutter",
				url: "https://github.com/asdf-community/asdf-flutter.git",
			},
		];
		state.pendingPluginUrlDialog = { mode: "edit", pluginName: "flutter" };
		state.pendingPluginUrlValue = "asdf:asdf-community/asdf-flutter";

		await submitPluginUrlDialog();

		expect(rpcRequest.installPluginDefinition).toHaveBeenCalledTimes(1);
		const params = rpcRequest.installPluginDefinition.mock.calls[0][0] as Record<string, unknown>;
		expect(params).toMatchObject({
			plugin: "flutter",
			force: true,
			removeToolAlias: true,
		});
		expect(params.gitUrl).toBeUndefined();
	});

	test("resolvePluginInstallPlan normalizes custom install shorthand", () => {
		expect(
			resolvePluginInstallPlan({
				dialog: { mode: "custom-install" },
				nameValue: "zoxide",
				urlValue: "nyrst/asdf-zoxide.git",
				installedUserPluginInfos: [],
				remotePluginInfos: [],
			}),
		).toEqual({
			kind: "install",
			plugin: "zoxide",
			gitUrl: "https://github.com/nyrst/asdf-zoxide.git",
			force: false,
			removeToolAlias: false,
		});
	});

	test("resolvePluginInstallPlan rejects invalid custom input", () => {
		const noName = resolvePluginInstallPlan({
			dialog: { mode: "custom-install" },
			nameValue: "  ",
			urlValue: "owner/repo",
			installedUserPluginInfos: [],
			remotePluginInfos: [],
		});
		expect(noName.kind).toBe("invalid");

		const badName = resolvePluginInstallPlan({
			dialog: { mode: "custom-install" },
			nameValue: "bad name",
			urlValue: "owner/repo",
			installedUserPluginInfos: [],
			remotePluginInfos: [],
		});
		expect(badName.kind).toBe("invalid");

		const noUrl = resolvePluginInstallPlan({
			dialog: { mode: "custom-install" },
			nameValue: "zoxide",
			urlValue: "",
			installedUserPluginInfos: [],
			remotePluginInfos: [],
		});
		expect(noUrl.kind).toBe("invalid");
	});

	test("resolvePluginInstallPlan skips edit when URL is unchanged", () => {
		const plan = resolvePluginInstallPlan({
			dialog: { mode: "edit", pluginName: "zoxide" },
			nameValue: "",
			urlValue: "https://example.com/custom.git",
			installedUserPluginInfos: [
				{ name: "zoxide", url: "https://example.com/custom.git", source: "mise_user" },
			],
			remotePluginInfos: [],
		});
		expect(plan.kind).toBe("skip");
	});

	test("resolvePluginInstallPlan reverts to default install when edit URL matches remote", () => {
		expect(
			resolvePluginInstallPlan({
				dialog: { mode: "edit", pluginName: "flutter" },
				nameValue: "",
				urlValue: "asdf:asdf-community/asdf-flutter",
				installedUserPluginInfos: [
					{
						name: "flutter",
						url: "https://github.com/asdf-community/asdf-flutter.git",
						source: "tool_alias",
					},
				],
				remotePluginInfos: [
					{ name: "flutter", url: "https://github.com/asdf-community/asdf-flutter.git" },
				],
			}),
		).toEqual({
			kind: "install",
			plugin: "flutter",
			gitUrl: undefined,
			force: true,
			removeToolAlias: true,
		});
	});

	test("leaves failed installs visible in progress label", async () => {
		rpcRequest.installPluginDefinition.mockRejectedValue(new Error("GitHub 404"));
		state.pendingPluginUrlDialog = { mode: "custom-install" };
		state.pendingPluginNameValue = "zoxide";
		state.pendingPluginUrlValue = "nyrst/asdf-zoxide.git";

		await submitPluginUrlDialog();

		expect(state.busy).toBe(false);
		expect(state.progressLabel).toBe("Install failed: zoxide");
		expect(state.logs.at(-1)).toContain("GitHub 404");
	});
});
