export function handleNativeInputShortcutFallback(event: KeyboardEvent): void {
	if (!(event.metaKey || event.ctrlKey) || event.altKey || event.shiftKey) {
		return;
	}
	if (event.key.toLowerCase() !== "a") {
		return;
	}
	const target = event.target;
	if (
		target &&
		"select" in target &&
		typeof target.select === "function"
	) {
		target.select();
		event.preventDefault();
	}
}
