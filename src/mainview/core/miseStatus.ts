import { compareVersions } from "../../shared/version";
import type { MainViewState } from "./types";

export type MiseStatusKey =
	| "loading"
	| "check_failed"
	| "not_checked"
	| "updating"
	| "updated_needs_reload"
	| "update_available"
	| "up_to_date"
	| "ahead_or_custom";

export interface MiseStatusSnapshot {
	key: MiseStatusKey;
	label: string;
	description: string;
	canUpdate: boolean;
	buttonHint: string;
}

export function normalizeVersionToken(value: string | null): string | null {
	if (!value) {
		return null;
	}
	const matched = value.match(/v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?/);
	if (!matched) {
		return null;
	}
	return matched[0].replace(/^v/, "");
}

export function getMiseStatusSnapshot(state: MainViewState): MiseStatusSnapshot {
	if (state.miseNeedsReload) {
		return {
			key: "updated_needs_reload",
			label: "Updated (Reload Needed)",
			description: "업데이트가 적용되었습니다. 앱 재시작 또는 화면 재로드를 권장합니다.",
			canUpdate: false,
			buttonHint: "이미 업데이트를 적용했습니다. 먼저 앱을 다시 로드하세요.",
		};
	}

	if (state.progressLabel === "Running mise self-update") {
		return {
			key: "updating",
			label: "Updating",
			description: "mise self-update가 실행 중입니다.",
			canUpdate: false,
			buttonHint: "업데이트 실행 중입니다.",
		};
	}

	if (state.miseCurrentError || state.miseLatestError) {
		return {
			key: "check_failed",
			label: "Check Failed",
			description: "버전 확인에 실패했습니다. 네트워크 상태 또는 GitHub API 제한을 확인하세요.",
			canUpdate: false,
			buttonHint: "먼저 Current/Latest 버전 확인을 정상화하세요.",
		};
	}

	if (!state.miseLoaded || !state.miseLatestLoaded) {
		return {
			key: "loading",
			label: "Loading",
			description: "현재 또는 최신 버전 정보를 불러오는 중입니다.",
			canUpdate: false,
			buttonHint: "버전 정보를 불러온 뒤 활성화됩니다.",
		};
	}

	const current = normalizeVersionToken(state.miseVersion);
	const latest = normalizeVersionToken(state.miseLatestVersion);

	if (!current || !latest) {
		return {
			key: "not_checked",
			label: "Not Comparable",
			description: "버전 형식을 해석할 수 없습니다. Current/Latest를 다시 확인하세요.",
			canUpdate: false,
			buttonHint: "버전 비교가 가능한 형식이어야 합니다.",
		};
	}

	const cmp = compareVersions(current, latest);
	if (cmp < 0) {
		return {
			key: "update_available",
			label: "Update Available",
			description: `${current} -> ${latest} 업데이트가 가능합니다.`,
			canUpdate: true,
			buttonHint: "업데이트를 진행할 수 있습니다.",
		};
	}
	if (cmp === 0) {
		return {
			key: "up_to_date",
			label: "Up-to-date",
			description: `현재 버전(${current})이 최신(${latest})입니다.`,
			canUpdate: false,
			buttonHint: "이미 최신 버전입니다.",
		};
	}

	return {
		key: "ahead_or_custom",
		label: "Ahead or Custom",
		description: `현재 버전(${current})이 최신 릴리스(${latest})보다 높거나 커스텀 빌드입니다.`,
		canUpdate: false,
		buttonHint: "현재 버전 상태에서는 업데이트가 필요하지 않습니다.",
	};
}
