import { expect, test } from "vitest";
import { flushSync, mount, unmount } from "svelte";
import Prototype from "./ReferenceDesignPrototype.svelte";

test("each reference layout applies the 24.x update independently and keeps a visible update count", async () => {
	for (const variant of ["E", "F", "G"]) {
		history.replaceState(null, "", `/?variant=${variant}`);
		const app = mount(Prototype, { target: document.body });
		try {
			flushSync();
			const countSelector = variant === "E" ? ".explorer-updates" : variant === "F" ? ".toolbox-tabs" : ".latest-header";
			expect(document.querySelector(countSelector)?.textContent).toContain("4");
			document.querySelector<HTMLButtonElement>('[aria-label="Node.js 24.x 24.21.0 적용 시뮬레이션"]')!.click();
			flushSync();
			expect(document.querySelector(countSelector)?.textContent).toContain("3");
			if (variant === "E") {
				expect(document.querySelector<HTMLSelectElement>('[aria-label="전역 버전"]')?.value).toBe("26.0.0");
				expect(document.querySelector('[aria-label="Node.js 26.x 26.1.0 적용 시뮬레이션"]')).not.toBeNull();
			} else if (variant === "F") {
				expect(document.querySelector(".toolbox-version-options")?.textContent).toContain("26.0.0");
				document.querySelector<HTMLButtonElement>(".toolbox-section-title button")!.click();
				flushSync();
				expect(document.querySelector(countSelector)?.textContent).toContain("0");
				expect(document.querySelector<HTMLButtonElement>(".toolbox-section-title button")?.disabled).toBe(true);
			} else {
				expect(document.querySelector(".latest-impact")?.textContent).toContain("26.0.0 유지");
				expect(document.querySelector(".latest-complete")?.textContent).toContain("적용을 마쳤어요");
			}
			expect(document.querySelector<HTMLAnchorElement>('.study-topline a')?.getAttribute("href")).toBe("/?variant=D");
		} finally {
			await unmount(app);
			document.body.innerHTML = "";
		}
	}
	history.replaceState(null, "", "/");
});
