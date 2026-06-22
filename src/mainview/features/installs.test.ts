import { beforeEach, describe, expect, mock, test } from "bun:test";

const state = {
	activeTab: "installs",
	busy: false,
	progressLabel: "Ready",
	progress: 0,
	logs: [] as string[],
	pluginSearchQuery: "",
	remotePluginNames: [] as string[],
	installedPluginNames: [] as string[],
	corePluginNames: [] as string[],
	installedToolNames: [] as string[],
	remotePluginInfos: [] as Array<{ name: string; url: string | null }>,
	installedUserPluginInfos: [] as Array<{
		name: string;
		url: string | null;
		source?: "mise_user" | "tool_alias" | "remote" | "core";
	}>,
	pendingPluginUrlDialog: null as
		| { mode: "install" | "edit"; pluginName: string }
		| { mode: "custom-install" }
		| null,
	pendingPluginNameValue: "",
	pendingPluginUrlValue: "",
	installsLoaded: false,
};

const rpcRequest = {
	installPluginDefinition: async (_params: unknown) => ({
		plugin: "plugin",
		stdout: "",
	}),
	uninstallPluginDefinition: async (_params: unknown) => ({
		plugin: "plugin",
		stdout: "",
	}),
	listInstalledPluginNames: async () => [] as string[],
	listInstalledUserPluginInfos: async () => [] as unknown[],
	listCorePluginNames: async () => [] as string[],
	listInstalledToolNames: async () => [] as string[],
	listRemotePluginNames: async () => [] as string[],
	listRemotePluginInfos: async () => [] as unknown[],
};

mock.module("../core/state", () => ({
	checkModeActiveOnly: true,
	default: state,
	state,
	setBusy: (nextBusy: boolean, nextLabel = "Ready", nextProgress = 0) => {
		state.busy = nextBusy;
		state.progressLabel = nextLabel;
		state.progress = nextProgress;
	},
}));

mock.module("../core/rpc", () => ({
	default: {
		request: rpcRequest,
	},
	rpc: {
		request: rpcRequest,
	},
}));

const { renderInstallsTab, submitPluginUrlDialog } = await import("./installs");
const { renderFixedContext } = await import("../render/layout");

describe("renderInstallsTab", () => {
	beforeEach(() => {
		state.busy = false;
		state.activeTab = "installs";
		state.pluginSearchQuery = "";
		state.remotePluginNames = [];
		state.installedPluginNames = [];
		state.corePluginNames = [];
		state.installedToolNames = [];
		state.remotePluginInfos = [];
		state.installedUserPluginInfos = [];
		state.pendingPluginUrlDialog = null;
		state.pendingPluginNameValue = "";
		state.pendingPluginUrlValue = "";
		state.logs = [];
		state.progressLabel = "Ready";
		state.progress = 0;
		rpcRequest.installPluginDefinition = async (_params: unknown) => ({
			plugin: "plugin",
			stdout: "",
		});
		rpcRequest.listInstalledPluginNames = async () => [];
		rpcRequest.listInstalledUserPluginInfos = async () => [];
		rpcRequest.listCorePluginNames = async () => [];
		rpcRequest.listInstalledToolNames = async () => [];
		rpcRequest.listRemotePluginNames = async () => [];
		rpcRequest.listRemotePluginInfos = async () => [];
	});

	test("shows custom plugin install action beside plugin search controls", () => {
		state.remotePluginNames = ["node", "python"];

		const html = renderFixedContext();

		expect(html).toContain('data-action="custom-install-plugin-def"');
		expect(html).toContain("Install Custom Plugin");
		expect(html).toContain('class="icon-btn"');
		expect(html).toContain('aria-label="Reload Plugins"');
		expect(html).toContain(">↻</button>");
		expect(html.indexOf("Install Custom Plugin")).toBeLessThan(
			html.indexOf("Reload Plugins"),
		);
	});

	test("offers custom plugin install when search no catalog matches", () => {
		state.pluginSearchQuery = "zoxide";
		state.remotePluginNames = ["node", "python"];

		const html = renderInstallsTab();

		expect(html).toContain('data-action="custom-install-plugin-def"');
		expect(html).toContain("검색 결과가 없습니다.");
	});

	test("keeps action buttons inside wrapper so table cells keep table layout", () => {
		state.remotePluginNames = ["node"];

		const html = renderInstallsTab();

		expect(html).toContain('<td class="actions">');
		expect(html).toContain('<div class="row-actions">');
		expect(html).toContain('data-action="install-plugin-def"');
	});

	test("normalizes custom install shorthand and clears busy after reload", async () => {
		const calls: unknown[] = [];
		rpcRequest.installPluginDefinition = async (params: unknown) => {
			calls.push(params);
			return { plugin: "zoxide", stdout: "" };
		};
		rpcRequest.listInstalledPluginNames = async () => ["zoxide"];
		state.pendingPluginUrlDialog = { mode: "custom-install" };
		state.pendingPluginNameValue = "zoxide";
		state.pendingPluginUrlValue = "nyrst/asdf-zoxide.git";

		await submitPluginUrlDialog(() => {});

		expect(calls).toEqual([
			{
				plugin: "zoxide",
				gitUrl: "https://github.com/nyrst/asdf-zoxide.git",
				force: false,
			},
		]);
		expect(state.busy).toBe(false);
	});

	test("uses default install and removes tool_alias when edit URL matches remote default", async () => {
		const calls: unknown[] = [];
		rpcRequest.installPluginDefinition = async (params: unknown) => {
			calls.push(params);
			return {
				plugin: "flutter",
				stdout: "Removed tool_alias from /tmp/config.toml.",
			};
		};
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

		await submitPluginUrlDialog(() => {});

		expect(calls).toEqual([
			{
				plugin: "flutter",
				gitUrl: undefined,
				force: true,
				removeToolAlias: true,
			},
		]);
	});

	test("leaves failed installs visible in progress label", async () => {
		rpcRequest.installPluginDefinition = async () => {
			throw new Error("GitHub 404");
		};
		state.pendingPluginUrlDialog = { mode: "custom-install" };
		state.pendingPluginNameValue = "zoxide";
		state.pendingPluginUrlValue = "nyrst/asdf-zoxide.git";

		await submitPluginUrlDialog(() => {});

		expect(state.busy).toBe(false);
		expect(state.progressLabel).toBe("Install failed: zoxide");
		expect(state.logs.at(-1)).toContain("GitHub 404");
	});
});
