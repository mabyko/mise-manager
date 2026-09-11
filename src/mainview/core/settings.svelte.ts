export interface Settings {
	showMenuBarIcon: boolean;
	checkOnStartup: boolean;
	checkIntervalHours: number;
	theme: "system" | "light" | "dark";
	showPrereleases: boolean;
	switchGlobalAfterUpdate: boolean;
}

export const defaultSettings: Settings = {
	showMenuBarIcon: true,
	checkOnStartup: true,
	checkIntervalHours: 0,
	theme: "system",
	showPrereleases: false,
	switchGlobalAfterUpdate: false,
};
const storageKey = "mise-manager.settings";

export function loadSettings(): Settings {
	try {
		const saved = JSON.parse(window.localStorage.getItem(storageKey) ?? "{}");
		return {
			showMenuBarIcon: typeof saved.showMenuBarIcon === "boolean" ? saved.showMenuBarIcon : true,
			checkOnStartup: typeof saved.checkOnStartup === "boolean" ? saved.checkOnStartup : true,
			checkIntervalHours: [0, 1, 6, 24].includes(saved.checkIntervalHours) ? saved.checkIntervalHours : 0,
			theme: ["system", "light", "dark"].includes(saved.theme) ? saved.theme : "system",
			showPrereleases: saved.showPrereleases === true,
			switchGlobalAfterUpdate: saved.switchGlobalAfterUpdate === true,
		};
	} catch {
		return { ...defaultSettings };
	}
}

export const settings = $state({ ...loadSettings(), saveError: "" });

export function setSetting<K extends keyof Settings>(key: K, value: Settings[K]): void {
	Object.assign(settings, { [key]: value });
	try {
		const { saveError: _, ...values } = settings;
		window.localStorage.setItem(storageKey, JSON.stringify(values));
		settings.saveError = "";
	} catch {
		settings.saveError = "설정을 저장하지 못했습니다. 이번 실행에만 적용됩니다.";
	}
}
