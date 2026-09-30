public enum MiseStatusKey: String, Sendable {
    case loading, updating
    case checkFailed = "check_failed"
    case notChecked = "not_checked"
    case updateAvailable = "update_available"
    case releaseWaiting = "release_waiting"
    case upToDate = "up_to_date"
    case aheadOrCustom = "ahead_or_custom"
}

public struct MiseStatusSnapshot: Equatable, Sendable {
    public let key: MiseStatusKey
    public let label: String
    public let description: String
    public let canUpdate: Bool
    public let buttonHint: String
}

/// The fields the decision table reads.
public struct MiseStatusInput: Sendable {
    public var progressLabel = Strings.ready
    public var currentError: String?
    public var latestError: String?
    public var loaded = true
    public var latestLoaded = true
    public var version: String?
    public var latestVersion: String?
    public var eligibleVersion: String?
    public var minimumAge = "24h"

    public init(
        progressLabel: String = Strings.ready, currentError: String? = nil,
        latestError: String? = nil, loaded: Bool = true, latestLoaded: Bool = true,
        version: String? = nil, latestVersion: String? = nil,
        eligibleVersion: String? = nil, minimumAge: String = "24h"
    ) {
        self.progressLabel = progressLabel
        self.currentError = currentError
        self.latestError = latestError
        self.loaded = loaded
        self.latestLoaded = latestLoaded
        self.version = version
        self.latestVersion = latestVersion
        self.eligibleVersion = eligibleVersion
        self.minimumAge = minimumAge
    }
}

/// Port of src/mainview/core/miseStatus.ts.
public enum MiseStatus {
    /// "2026.8.6 macos-arm64 (…)" → "2026.8.6", "v1.2.3-rc.1" → "1.2.3-rc.1".
    public static func normalizeVersionToken(_ value: String?) -> String? {
        guard let value, let match = value.firstMatch(of: /v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?/) else { return nil }
        var token = String(match.0)
        if token.hasPrefix("v") { token.removeFirst() }
        return token
    }

    public static func snapshot(_ input: MiseStatusInput) -> MiseStatusSnapshot {
        if input.progressLabel == Strings.runningMiseSelfUpdate {
            return .init(key: .updating, label: "Updating", description: "mise self-update가 실행 중입니다.",
                         canUpdate: false, buttonHint: "업데이트 실행 중입니다.")
        }
        if input.currentError != nil || input.latestError != nil {
            return .init(key: .checkFailed, label: "Check Failed",
                         description: "릴리스 목록 또는 mise 업데이트 정책을 확인하지 못했습니다. 오류 내용을 확인한 뒤 다시 시도하세요.",
                         canUpdate: false, buttonHint: "먼저 Current/Latest 버전 확인을 정상화하세요.")
        }
        if !input.loaded || !input.latestLoaded {
            return .init(key: .loading, label: "Loading", description: "현재 또는 최신 버전 정보를 불러오는 중입니다.",
                         canUpdate: false, buttonHint: "버전 정보를 불러온 뒤 활성화됩니다.")
        }
        guard let current = normalizeVersionToken(input.version), let latest = normalizeVersionToken(input.latestVersion) else {
            return .init(key: .notChecked, label: "Not Comparable",
                         description: "버전 형식을 해석할 수 없습니다. Current/Latest를 다시 확인하세요.",
                         canUpdate: false, buttonHint: "버전 비교가 가능한 형식이어야 합니다.")
        }
        guard let eligible = normalizeVersionToken(input.eligibleVersion) else {
            return .init(key: .notChecked, label: "정책 미확인", description: "mise 정책에 맞는 업데이트 후보를 다시 확인하세요.",
                         canUpdate: false, buttonHint: "업데이트 정책을 확인한 뒤 활성화됩니다.")
        }
        switch Version.compare(current, latest) {
        case .orderedAscending:
            if Version.compare(current, eligible) == .orderedAscending {
                return .init(key: .updateAvailable, label: "업데이트 가능", description: "\(current) → \(eligible) 업데이트가 가능합니다. 적용 정책: \(input.minimumAge).",
                             canUpdate: true, buttonHint: "mise 정책에 맞는 \(eligible) 버전으로 업데이트합니다.")
            }
            return .init(key: .releaseWaiting, label: "새 릴리스 대기 중",
                         description: "최신 릴리스 \(latest)은 적용 정책(\(input.minimumAge))에 따라 대기 중입니다. 현재 업데이트할 수 있는 버전이 없습니다.",
                         canUpdate: false, buttonHint: "mise가 새 릴리스를 업데이트 후보로 선택할 때까지 기다립니다.")
        case .orderedSame:
            return .init(key: .upToDate, label: "Up-to-date", description: "현재 버전(\(current))이 최신(\(latest))입니다.",
                         canUpdate: false, buttonHint: "이미 최신 버전입니다.")
        case .orderedDescending:
            return .init(key: .aheadOrCustom, label: "Ahead or Custom",
                         description: "현재 버전(\(current))이 최신 릴리스(\(latest))보다 높거나 커스텀 빌드입니다.",
                         canUpdate: false, buttonHint: "현재 버전 상태에서는 업데이트가 필요하지 않습니다.")
        }
    }
}

extension AppState {
    /// Only newer, unselected stable releases are shown in the waiting list.
    public var misePendingReleases: [MiseRelease] {
        guard miseLatestError == nil,
              let current = MiseStatus.normalizeVersionToken(miseVersion),
              let eligible = MiseStatus.normalizeVersionToken(miseEligibleVersion) else { return [] }
        return miseReleases.filter {
            Version.compare($0.version, current) == .orderedDescending
                && Version.compare($0.version, eligible) == .orderedDescending
        }
    }

    public var miseStatus: MiseStatusSnapshot {
        MiseStatus.snapshot(MiseStatusInput(
            progressLabel: progressLabel, currentError: miseCurrentError,
            latestError: miseLatestError, loaded: miseLoaded, latestLoaded: miseLatestLoaded,
            version: miseVersion, latestVersion: miseLatestVersion,
            eligibleVersion: miseEligibleVersion, minimumAge: miseMinimumReleaseAge))
    }
}
