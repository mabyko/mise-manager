import { expect, test } from "vitest";
import { flushSync, mount, unmount } from "svelte";
import Prototype from "./UpdateDesignPrototype.svelte";

test("viewing updates preserves the count; applying a sample update clears only that item", async () => {
	history.replaceState(null, "", "/?variant=A");
	const app = mount(Prototype, { target: document.body });
	const click = (selector: string) => {
		document.querySelector<HTMLButtonElement>(selector)!.click();
		flushSync();
	};
	try {
		flushSync();
		click('.prototype-sidebar nav button:nth-child(2)');
		expect(document.querySelector(".prototype-count")?.textContent).toBe("4");
		click('.prototype-sidebar nav button:first-child');
		expect(document.querySelector(".prototype-count")?.textContent).toBe("4");
		click('[aria-label="Node.js 24.x 24.21.0 설치 시뮬레이션"]');
		expect(document.querySelector(".prototype-count")?.textContent).toBe("3");
		expect(document.querySelector('[aria-label="Node.js 26.x 26.1.0 설치 시뮬레이션"]')).not.toBeNull();
		click('.prototype-sidebar nav button:nth-child(2)');
		expect(document.querySelector(".prototype-installed")?.textContent).toContain("26.0.0전역");
		expect(document.querySelector(".prototype-installed")?.textContent).toContain("24.21.0추가됨");
		click('[aria-label="다음 시안"]');
		expect(location.search).toBe("?variant=B");
		click('[aria-label="업데이트 패널 닫기"]');
		expect(document.querySelector(".prototype-drawer")).toBeNull();
		expect(document.querySelector(".prototype-update-trigger")?.textContent).toContain("4");
		click('.prototype-update-trigger');
		expect(document.querySelector(".prototype-drawer")).not.toBeNull();
	} finally {
		await unmount(app);
		document.body.innerHTML = "";
		history.replaceState(null, "", "/");
	}
});

test("the simplified layout keeps updates across pages and installs older-series updates independently", async () => {
	history.replaceState(null, "", "/?variant=D");
	const app = mount(Prototype, { target: document.body });
	const click = (selector: string) => {
		document.querySelector<HTMLButtonElement>(selector)!.click();
		flushSync();
	};
	try {
		flushSync();
		expect(document.querySelector<HTMLDetailsElement>(".simple-updates")?.open).toBe(false);
		expect(document.querySelector(".simple-updates summary")?.textContent).toContain("업데이트 4개");
		click('.sidebar nav button:last-child');
		expect(document.querySelector("h1")?.textContent).toBe("설정");
		expect(document.querySelector(".simple-updates summary")?.textContent).toContain("업데이트 4개");
		click('.simple-updates summary');
		expect(document.querySelector<HTMLDetailsElement>(".simple-updates")?.open).toBe(true);
		click('[aria-label="Node.js 24.x 24.21.0 빠른 설치 시뮬레이션"]');
		expect(document.querySelector(".simple-updates summary")?.textContent).toContain("업데이트 3개");
		click('.sidebar nav button:first-child');
		expect(document.querySelector<HTMLSelectElement>('[aria-label="Node.js 전역 버전"]')?.value).toBe("26.0.0");
		expect(document.querySelector(".simple-version-list")?.textContent).toContain("24.20.0");
		expect(document.querySelector(".simple-version-list")?.textContent).toContain("24.21.0");
		expect(document.querySelector('[aria-label="Node.js 26.1.0 설치 시뮬레이션"]')).not.toBeNull();
		const globalVersion = document.querySelector<HTMLSelectElement>('[aria-label="Node.js 전역 버전"]')!;
		globalVersion.value = "24.21.0";
		globalVersion.dispatchEvent(new Event("change", { bubbles: true }));
		flushSync();
		expect(document.querySelector(".tool-item.selected")?.textContent).toContain("24.21.0");
	} finally {
		await unmount(app);
		document.body.innerHTML = "";
		history.replaceState(null, "", "/");
	}
});
