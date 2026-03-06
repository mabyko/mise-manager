import { state } from "../core/state";
import { escapeHtml } from "../core/utils";
import { renderInstallsTab, renderPluginUrlDialog } from "../features/installs";
import { renderLogsTab } from "../features/logs";
import { renderMiseTab, renderMiseUpdateDialog } from "../features/mise";
import { renderDeleteDialog, renderUpdaterTab } from "../features/updater";
import { renderFixedContext } from "./layout";

export function createRenderer(appRoot: HTMLElement): () => void {
	return () => {
		appRoot.innerHTML = `
			<main>
				<div class="app-header">
					<nav class="tabs">
						<button class="tab ${state.activeTab === "mise" ? "active" : ""}" data-action="tab-mise">Mise Version</button>
						<button class="tab ${state.activeTab === "installs" ? "active" : ""}" data-action="tab-installs">Plugin Installs</button>
						<button class="tab ${state.activeTab === "updater" ? "active" : ""}" data-action="tab-updater">Plugins Updater</button>
						<button class="tab ${state.activeTab === "logs" ? "active" : ""}" data-action="tab-logs">Logs</button>
					</nav>
					${renderFixedContext()}
					<section class="global-progress">
						<div class="progress-head">
							<strong>${escapeHtml(state.progressLabel)}</strong>
							<span>${Math.round(state.progress)}%</span>
						</div>
						<div class="progress-track"><div class="progress-fill" style="width:${Math.max(0, Math.min(100, state.progress))}%"></div></div>
					</section>
				</div>
				<section class="app-content">
					${state.activeTab === "mise" ? renderMiseTab() : state.activeTab === "updater" ? renderUpdaterTab() : state.activeTab === "logs" ? renderLogsTab() : renderInstallsTab()}
				</section>
			</main>
			${renderDeleteDialog()}
			${renderPluginUrlDialog()}
			${renderMiseUpdateDialog()}
		`;
	};
}
