import { state } from "../core/state.svelte";
import { nowLabel } from "../core/utils";

export function addLog(message: string): void {
	state.logs = [`[${nowLabel()}] ${message}`, ...state.logs].slice(0, 150);
}

export function clearLogs(): void {
	state.logs = [];
}
