/// User-facing labels. Progress labels are Korean throughout (the Tauri UI mixed English in).
public enum Strings {
    public static let ready = "대기"
    public static let loadingPlugins = "도구 목록 불러오는 중"
    public static let loadFailed = "불러오기 실패"
    public static let checkingUpdates = "업데이트 확인 중"
    public static func checking(_ name: String) -> String { "\(name) 확인 중" }
    public static let checkComplete = "확인 완료"
    public static let checkFailed = "확인 실패"
    public static func installing(_ spec: String) -> String { "\(spec) 설치 중" }
    public static func using(_ spec: String) -> String { "\(spec) 전역 전환 중" }
    public static func updating(_ spec: String) -> String { "\(spec) 업데이트 중" }
    public static func deleting(_ spec: String) -> String { "\(spec) 삭제 중" }

    public static let loadingPluginDefinitions = "플러그인 목록 불러오는 중"
    public static let checkingPluginUpdates = "플러그인 업데이트 확인 중"
    public static func updatingPluginDefinition(_ plugin: String) -> String { "\(plugin) 플러그인 업데이트 중" }
    public static func installingPlugin(_ plugin: String, force: Bool) -> String { force ? "\(plugin) 플러그인 수정 중" : "\(plugin) 플러그인 설치 중" }
    public static func pluginInstallFailed(_ plugin: String, force: Bool) -> String { force ? "수정 실패: \(plugin)" : "설치 실패: \(plugin)" }
    public static func removingPlugin(_ plugin: String) -> String { "\(plugin) 플러그인 제거 중" }
    public static func pluginUpdated(_ plugin: String) -> String { "\(plugin) 플러그인을 업데이트했습니다." }
    public static func pluginUpdateFailed(_ plugin: String, _ message: String) -> String { "\(plugin) 업데이트 실패: \(message)" }

    public static let loadingMiseVersion = "mise 버전 확인 중"
    public static let checkingLatestMise = "최신 mise 릴리스 확인 중"
    public static let runningMiseSelfUpdate = "mise self-update 실행 중"
    public static let updateComplete = "업데이트 완료"
    public static let updateFailed = "업데이트 실패"
    public static func installingMise(_ method: MiseInstallMethod) -> String { "mise 설치 중 (\(method == .sh ? "curl" : "brew"))" }
    public static let installed = "설치 완료"
    public static let installFailed = "설치 실패"
    public static let checkingMise = "mise 확인 중"
    public static let miseRequired = "mise 설치 필요"

    public enum ToolStatus {
        public static let checkFailed = "확인 실패"
        public static let checking = "확인 중"
        public static let changing = "변경 중"
        public static let deleting = "삭제 중"
        public static let unchecked = "미확인"
        public static let channel = "채널 버전"
        public static let updateAvailable = "업데이트"
        public static let noComparison = "비교 정보 없음"
        public static let prerelease = "프리릴리스 사용"
        public static let latestStable = "최신 안정 버전"
    }

    public enum Summary {
        public static func newMajor(_ name: String) -> String { "\(name) · 새 major" }
        public static let unselected = "미선택"
        public static func plugin(_ name: String) -> String { "\(name) · 플러그인" }
        public static let installedSource = "설치된 소스"
        public static let latestSource = "최신 소스"
    }
}
