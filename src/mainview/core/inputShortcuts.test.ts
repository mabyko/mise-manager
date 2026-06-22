import { describe, expect, test } from "bun:test";
import { handleNativeInputShortcutFallback } from "./inputShortcuts";

function makeKeyboardEvent(key: string) {
	let prevented = false;
	let selected = false;
	return {
		event: {
			key,
			metaKey: true,
			ctrlKey: false,
			altKey: false,
			shiftKey: false,
			target: {
				select: () => {
					selected = true;
				},
			},
			preventDefault: () => {
				prevented = true;
			},
		} as unknown as KeyboardEvent,
		wasPrevented: () => prevented,
		wasSelected: () => selected,
	};
}

describe("handleNativeInputShortcutFallback", () => {
	test("keeps command-a select all fallback for inputs", () => {
		const { event, wasPrevented, wasSelected } = makeKeyboardEvent("a");

		handleNativeInputShortcutFallback(event);

		expect(wasSelected()).toBe(true);
		expect(wasPrevented()).toBe(true);
	});

	test("does not handle native clipboard shortcuts", () => {
		const { event, wasPrevented, wasSelected } = makeKeyboardEvent("v");

		handleNativeInputShortcutFallback(event);

		expect(wasSelected()).toBe(false);
		expect(wasPrevented()).toBe(false);
	});
});
