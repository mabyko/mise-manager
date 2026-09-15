public enum MiseStatusKey: String, Sendable {
    case loading, updating
    case checkFailed = "check_failed"
    case notChecked = "not_checked"
    case updateAvailable = "update_available"
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

    public init(
        progressLabel: String = Strings.ready, currentError: String? = nil,
        latestError: String? = nil, loaded: Bool = true, latestLoaded: Bool = true,
        version: String? = nil, latestVersion: String? = nil
    ) {
        self.progressLabel = progressLabel
        self.currentError = currentError
        self.latestError = latestError
        self.loaded = loaded
        self.latestLoaded = latestLoaded
        self.version = version
        self.latestVersion = latestVersion
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
                         description: "버전 확인에 실패했습니다. 네트워크 상태 또는 GitHub API 제한을 확인하세요.",
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
        switch Version.compare(current, latest) {
        case .orderedAscending:
            return .init(key: .updateAvailable, label: "Update Available", description: "\(current) -> \(latest) 업데이트가 가능합니다.",
                         canUpdate: true, buttonHint: "업데이트를 진행할 수 있습니다.")
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
    public var miseStatus: MiseStatusSnapshot {
        MiseStatus.snapshot(MiseStatusInput(
            progressLabel: progressLabel, currentError: miseCurrentError,
            latestError: miseLatestError, loaded: miseLoaded, latestLoaded: miseLatestLoaded,
            version: miseVersion, latestVersion: miseLatestVersion))
    }
}
