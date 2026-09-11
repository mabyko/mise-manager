import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { Storage } from "happy-dom";
import { defaultSettings, loadSettings, setSetting, settings } from "./settings.svelte";

// Node exposes an unavailable localStorage that can shadow happy-dom's storage.
beforeEach(() => vi.stubGlobal("localStorage", new Storage()));
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); Object.assign(settings, defaultSettings, { saveError: "" }); });

test("settings survive reload and invalid saved values fall back to safe defaults", () => {
	expect(loadSettings().showMenuBarIcon).toBe(true);
	setSetting("theme", "dark");
	setSetting("checkIntervalHours", 6);
	setSetting("checkOnStartup", false);
	setSetting("showMenuBarIcon", false);
	expect(loadSettings()).toMatchObject({ showMenuBarIcon: false, theme: "dark", checkIntervalHours: 6, checkOnStartup: false, switchGlobalAfterUpdate: false });
	setSetting("showMenuBarIcon", true);
	expect(loadSettings().showMenuBarIcon).toBe(true);
	window.localStorage.setItem("mise-manager.settings", '{"theme":"dark"}');
	expect(loadSettings()).toMatchObject({ showMenuBarIcon: true, theme: "dark" });
	window.localStorage.setItem("mise-manager.settings", '{"showMenuBarIcon":"false","checkIntervalHours":-1,"switchGlobalAfterUpdate":"true","theme":"unknown"}');
	expect(loadSettings()).toEqual(defaultSettings);
	window.localStorage.setItem("mise-manager.settings", "broken");
	expect(loadSettings()).toEqual(defaultSettings);
});

test("storage failures keep the choice for the session and explain that it was not saved", () => {
	vi.spyOn(window.localStorage, "setItem").mockImplementation(() => { throw new Error("quota"); });
	setSetting("theme", "light");
	expect(settings.theme).toBe("light");
	expect(settings.saveError).toContain("이번 실행에만");
});
