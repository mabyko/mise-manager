import { beforeEach, describe, expect, mock, test } from "bun:test";

const state = {
	activeTab: "installs",
	busy: false,
	pluginSearchQuery: "",
	remotePluginNames: [] as string[],
	installedPluginNames: [] as string[],
	corePluginNames: [] as string[],
	installedToolNames: [] as string[],
	remotePluginInfos: [],
	installedUserPluginInfos: [],
	pendingPluginNameValue: "",
	pendingPluginUrlValue: "",
};

mock.module("../core/state", () => ({
	checkModeActiveOnly: true,
	default: state,
	state,
	setBusy: (nextBusy: boolean) => {
		state.busy = nextBusy;
	},
}));

mock.module("../core/rpc", () => ({
	default: {
		request: {},
	},
	rpc: {
		request: {},
	},
}));

const { renderInstallsTab } = await import("./installs");
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
		state.pendingPluginNameValue = "";
		state.pendingPluginUrlValue = "";
	});

	test("shows a custom plugin install action beside the plugin search controls", () => {
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

	test("offers custom plugin install when a search has no catalog matches", () => {
		state.remotePluginNames = ["node"];
		state.pluginSearchQuery = "not-in-catalog";

		const html = renderInstallsTab();

		expect(html).toContain('data-action="custom-install-plugin-def"');
		expect(html).toContain("검색 결과가 없습니다.");
	});

	test("keeps action buttons inside a wrapper so table cells keep table layout", () => {
		state.remotePluginNames = ["node"];

		const html = renderInstallsTab();

		expect(html).toContain('<td class="actions">');
		expect(html).toContain('<div class="row-actions">');
		expect(html).toContain('data-action="install-plugin-def"');
	});
});
