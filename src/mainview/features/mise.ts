import type { MiseSelfUpdateResult } from "../../shared/contracts";
import { getMiseStatusSnapshot } from "../core/miseStatus";
import { rpc } from "../core/rpc";
import { state, setBusy } from "../core/state";
import { escapeHtml } from "../core/utils";
import { addLog } from "./logs";

const MISE_OFFICIAL_URL = "https://mise.jdx.dev/getting-started.html";
const IS_MAC = process.platform === "darwin";
const IS_WINDOWS = process.platform === "win32";

function renderCard(title: string, value: string, hint = ""): string {
	return `
		<div class="mise-summary-card">
			<div class="mise-summary-title">${escapeHtml(title)}</div>
			<div class="mise-summary-value">${escapeHtml(value)}</div>
			${hint ? `<div class="mise-summary-hint">${escapeHtml(hint)}</div>` : ""}
		</div>
	`;
}

export function renderMiseTab(): string {
	const status = getMiseStatusSnapshot(state);
	const current = state.miseCurrentError
		? `Error: ${state.miseCurrentError}`
		: state.miseLoaded
			? (state.miseVersion ?? "Unknown")
			: "Not loaded";
	const latest = state.miseLatestError
		? `Error: ${state.miseLatestError}`
		: state.miseLatestLoaded
			? (state.miseLatestVersion ?? "Unknown")
			: "Not checked";
	const checkedAt = state.miseLatestCheckedAt ?? "Not checked";

	return `
		<section class="panel">
			<div class="panel-header">
				<div>
					<h2>Mise Version Status</h2>
					<p>
						현재 설치된 mise 버전과 GitHub 최신 릴리스를 비교합니다.
						업데이트는 <code>mise self-update -y</code>로 실행됩니다.
					</p>
				</div>
			</div>
			<div class="mise-summary-grid">
				${renderCard("Current", current, "local: mise --version")}
				${renderCard("Latest", latest, "GitHub latest release")}
				${renderCard("Status", status.label, checkedAt)}
			</div>
			<div class="mise-status-note" style="margin-top: 12px;">
				<strong>Status Guide:</strong> ${escapeHtml(status.description)}
			</div>
			${state.miseNeedsReload ? `<div class="log-card" style="margin-top: 12px;"><strong>Update applied.</strong> 앱을 재시작하거나 화면을 다시 로드해 새 환경을 반영하세요.</div>` : ""}
			${state.miseLastResult ? `<div class="log-card" style="margin-top: 12px;"><pre>${escapeHtml(state.miseLastResult)}</pre></div>` : ""}
		</section>
	`;
}

export function renderMiseUpdateDialog(): string {
	if (!state.pendingMiseUpdateConfirm) {
		return "";
	}

	return `
		<div class="modal-overlay">
			<div class="modal-card">
				<h3>Update Mise</h3>
				<p>
					<code>mise self-update -y</code>를 실행합니다.<br/>
					설치 방식에 따라 실패할 수 있으며 실행 후 재시작이 필요할 수 있습니다.
				</p>
				<div class="modal-actions">
					<button class="mini-btn" data-action="cancel-mise-update">Cancel</button>
					<button class="mini-btn" data-action="confirm-mise-update" ${state.busy ? "disabled" : ""}>Run Update</button>
				</div>
			</div>
		</div>
	`;
}

export async function reloadMiseVersion(render: () => void): Promise<void> {
	setBusy(true, "Loading mise version", 15);
	render();
	try {
		const version = await rpc.request.getMiseVersion();
		state.miseVersion = version;
		state.miseLoaded = true;
		state.miseCurrentError = null;
		addLog(`Loaded mise version: ${version ?? "unknown"}.`);
		setBusy(false, "Ready", 0);
	} catch (error) {
		state.miseLoaded = true;
		state.miseCurrentError = (error as Error).message;
		addLog(`Failed to load mise version: ${(error as Error).message}`);
		setBusy(false, "Load failed", 0);
	} finally {
		render();
	}
}

export async function checkLatestMiseRelease(render: () => void): Promise<void> {
	setBusy(true, "Checking latest mise release", 20);
	render();
	try {
		const latest = await rpc.request.getLatestMiseRelease();
		state.miseLatestVersion = latest;
		state.miseLatestLoaded = true;
		state.miseLatestError = null;
		state.miseLatestCheckedAt = new Date().toLocaleString("ko-KR", {
			hour12: false,
		});
		addLog(`Loaded latest mise release: ${latest ?? "unknown"}.`);
		setBusy(false, "Ready", 0);
	} catch (error) {
		state.miseLatestLoaded = true;
		state.miseLatestError = (error as Error).message;
		state.miseLatestCheckedAt = new Date().toLocaleString("ko-KR", {
			hour12: false,
		});
		addLog(`Failed to check latest mise release: ${(error as Error).message}`);
		setBusy(false, "Check failed", 0);
	} finally {
		render();
	}
}

export function openMiseUpdateDialog(render: () => void): void {
	const status = getMiseStatusSnapshot(state);
	if (!status.canUpdate) {
		addLog(`mise update blocked: ${status.buttonHint}`);
		render();
		return;
	}
	state.pendingMiseUpdateConfirm = true;
	render();
}

export function cancelMiseUpdateDialog(render: () => void): void {
	state.pendingMiseUpdateConfirm = false;
	render();
}

export async function confirmMiseSelfUpdate(render: () => void): Promise<void> {
	if (state.busy) {
		return;
	}
	state.pendingMiseUpdateConfirm = false;
	setBusy(true, "Running mise self-update", 30);
	render();

	try {
		const result: MiseSelfUpdateResult = await rpc.request.selfUpdateMise();
		state.miseVersion = result.afterVersion;
		state.miseLoaded = true;
		state.miseCurrentError = null;
		state.miseNeedsReload = true;
		state.miseLastResult = [
			`Before: ${result.beforeVersion ?? "unknown"}`,
			`After: ${result.afterVersion ?? "unknown"}`,
			result.stdout ? `\nSTDOUT:\n${result.stdout}` : "",
			result.stderr ? `\nSTDERR:\n${result.stderr}` : "",
		]
			.filter((line) => line.length > 0)
			.join("\n");
		addLog(`mise self-update finished: ${result.beforeVersion ?? "unknown"} -> ${result.afterVersion ?? "unknown"}.`);
		setBusy(false, "Update complete", 100);
	} catch (error) {
		state.miseNeedsReload = false;
		state.miseLastResult = `ERROR:\n${(error as Error).message}`;
		addLog(`mise self-update failed: ${(error as Error).message}`);
		setBusy(false, "Update failed", 0);
	}
	render();
}

export async function checkMiseInstallationStatus(render: () => void): Promise<void> {
	try {
		const installed = await rpc.request.checkMiseInstalled();
		state.miseIsInstalled = installed;
		state.miseInstalledChecked = true;
		if (!installed) {
			addLog("mise is not installed on this system.");
		}
	} catch (error) {
		state.miseIsInstalled = false;
		state.miseInstalledChecked = true;
		addLog(`Failed to check mise installation: ${(error as Error).message}`);
	}
	render();
}

export function renderMiseNotDetected(): string {
	if (state.miseIsInstalled || !state.miseInstalledChecked) {
		return "";
	}

	if (IS_WINDOWS) {
		return `
			<section class="panel">
				<div class="panel-header">
					<div>
						<h2>mise Not Detected</h2>
						<p>
							mise가 설치되어 있지 않습니다.<br/>
							Windows에서는 공식 사이트에서 설치 방법을 확인하세요.
						</p>
					</div>
				</div>
				<div style="margin-top: 16px;">
					<a href="${MISE_OFFICIAL_URL}" target="_blank" class="primary-btn" style="display: inline-block; text-decoration: none;">
						Visit Official Site
					</a>
				</div>
			</section>
		`;
	}

	return `
		<section class="panel">
			<div class="panel-header">
				<div>
					<h2>mise Not Detected</h2>
					<p>
						mise가 설치되어 있지 않습니다.<br/>
						아래 방법 중 하나로 설치할 수 있습니다.
					</p>
				</div>
			</div>
			${state.miseInstalling ? `
				<div class="log-card" style="margin-top: 12px;">
					<strong>Installing mise...</strong>
					${state.miseLastResult ? `<pre>${escapeHtml(state.miseLastResult)}</pre>` : ""}
				</div>
			` : `
				<div style="margin-top: 16px; display: flex; gap: 8px; flex-wrap: wrap;">
					<button class="primary-btn" data-action="install-mise-sh">
						Quick Install (sh)
					</button>
					<button class="primary-btn" data-action="install-mise-brew">
						Homebrew Install
					</button>
					<a href="${MISE_OFFICIAL_URL}" target="_blank" class="mini-btn" style="display: inline-block; text-decoration: none;">
						Visit Official Site
					</a>
				</div>
				<div class="log-card" style="margin-top: 12px;">
					<strong>Quick Install (sh):</strong> <code>curl https://mise.run | sh</code><br/>
					<strong>Homebrew:</strong> <code>brew install mise</code>
				</div>
			`}
		</section>
	`;
}

export async function startMiseInstall(method: "sh" | "brew", render: () => void): Promise<void> {
	if (state.busy || state.miseInstalling) {
		return;
	}

	state.miseInstalling = true;
	state.miseInstallMethod = method;
	state.miseLastResult = "";
	setBusy(true, `Installing mise (${method === "sh" ? "curl" : "brew"})...`, 30);
	render();

	try {
		const result = method === "sh"
			? await rpc.request.installMiseSh()
			: await rpc.request.installMiseBrew();

		state.miseLastResult = [
			result.success ? "Installation completed successfully!" : "Installation failed.",
			result.stdout ? `\nSTDOUT:\n${result.stdout}` : "",
			result.stderr ? `\nSTDERR:\n${result.stderr}` : "",
		].filter((line) => line.length > 0).join("\n");

		addLog(`mise ${method} install ${result.success ? "succeeded" : "failed"}.`);

		if (result.success) {
			addLog("mise installed. Verifying installation...");
			await new Promise((resolve) => setTimeout(resolve, 2000));
			await checkMiseInstallationStatus(render);

			if (state.miseIsInstalled) {
				addLog("mise installation verified. Loading version...");
				await reloadMiseVersion(render);
			} else {
				addLog("mise installation completed but not yet detected in PATH. You may need to restart the app.");
			}
		}

		setBusy(false, result.success ? "Installed" : "Install failed", 0);
	} catch (error) {
		state.miseLastResult = `ERROR:\n${(error as Error).message}`;
		addLog(`mise install failed: ${(error as Error).message}`);
		setBusy(false, "Install failed", 0);
	} finally {
		state.miseInstalling = false;
		state.miseInstallMethod = null;
		render();
	}
}
