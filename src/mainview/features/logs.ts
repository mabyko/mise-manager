import { state } from "../core/state";
import { escapeHtml, nowLabel } from "../core/utils";

export function addLog(message: string): void {
	state.logs = [`[${nowLabel()}] ${message}`, ...state.logs].slice(0, 150);
}

export function clearLogs(): void {
	state.logs = [];
}

export function renderLogsTab(): string {
	return `
		<section class="panel">
			<section class="log-card">
				<pre>${escapeHtml(state.logs.join("\n") || "로그가 없습니다.")}</pre>
			</section>
		</section>
	`;
}
