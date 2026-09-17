import Foundation
import Observation

public enum ActiveTab: String, Sendable, CaseIterable { case mise, updater, updates, logs, installs, settings }
public enum PluginStatus: String, Sendable { case idle, checking, done, error, updating, deleting, skipped }
public enum MiseInstallMethod: String, Sendable { case sh, brew }

/// One tool in the sidebar: what mise reports plus the last update check against it.
public struct PluginRow: Equatable, Sendable {
    public var name: String
    public var activeGlobalVersion: String?
    public var installedVersions: [String]
    public var latestByMajor: [String: String]
    public var sameMajorLatest: String?
    public var releaseLatest: String?
    public var overallLatest: String?
    public var checkedVersions: Int
    public var status: PluginStatus
    public var error: String?

    public init(
        name: String, activeGlobalVersion: String? = nil, installedVersions: [String] = [],
        latestByMajor: [String: String] = [:], sameMajorLatest: String? = nil, releaseLatest: String? = nil,
        overallLatest: String? = nil, checkedVersions: Int = 0, status: PluginStatus = .idle, error: String? = nil
    ) {
        self.name = name
        self.activeGlobalVersion = activeGlobalVersion
        self.installedVersions = installedVersions
        self.latestByMajor = latestByMajor
        self.sameMajorLatest = sameMajorLatest
        self.releaseLatest = releaseLatest
        self.overallLatest = overallLatest
        self.checkedVersions = checkedVersions
        self.status = status
        self.error = error
    }

    public init(_ summary: PluginSummary) {
        self.init(name: summary.name, activeGlobalVersion: summary.activeGlobalVersion, installedVersions: summary.installedVersions)
        normalizeInstalled()
    }

    /// The version candidates are compared against: the global selection, else the newest installed.
    public var baseVersion: String? { activeGlobalVersion ?? installedVersions.first }

    mutating func normalizeInstalled() {
        installedVersions = Parsers.dedupe(installedVersions).sorted { Version.compare($0, $1) == .orderedDescending }
    }

    mutating func clearCandidates() {
        latestByMajor = [:]
        sameMajorLatest = nil
        releaseLatest = nil
        overallLatest = nil
        checkedVersions = 0
    }
}

public struct PendingDelete: Equatable, Sendable {
    public var pluginName: String
    public var version: String
    public init(pluginName: String, version: String) { self.pluginName = pluginName; self.version = version }
}

public struct PendingMajorUpdate: Equatable, Sendable {
    public var pluginName: String
    public var fromVersion: String?
    public var targetVersion: String
    public init(pluginName: String, fromVersion: String?, targetVersion: String) {
        self.pluginName = pluginName; self.fromVersion = fromVersion; self.targetVersion = targetVersion
    }
}

public enum PluginUrlDialog: Equatable, Sendable {
    case install(pluginName: String)
    case edit(pluginName: String)
    case customInstall

    public var pluginName: String? {
        switch self {
        case .install(let name), .edit(let name): name
        case .customInstall: nil
        }
    }
}

/// The whole app state (was state.svelte.ts) plus the feature methods in the Features/ extensions.
/// The tray observes the same object, so no main↔tray message bridge exists.
@MainActor @Observable public final class AppState {
    @ObservationIgnored public let mise: Mise
    public let settings: Settings
    @ObservationIgnored let latestRelease: @Sendable () async throws -> String?
    /// Installed by the app so runtime "open" actions can raise the main window.
    @ObservationIgnored public var showMainWindow: @MainActor () -> Void = {}
    /// Installed by the app (Phase 4); opens the menu bar panel.
    @ObservationIgnored public var showTray: @MainActor () -> Void = {}
    @ObservationIgnored var intervalTask: Task<Void, Never>?

    public var toolsCheckedAt: String?
    public var updateCheckRunning = false
    public var outdatedPluginNames: [String] = []
    public var pluginUpdatesCheckedAt: String?
    public var pluginUpdatesError: String?
    public var pluginUpdateResult: String?
    public var installsError: String?
    public var activeTab: ActiveTab = .updater
    public var selectedToolName: String?
    public var toolSearchQuery = ""
    public var toolsLoaded = false
    public var toolsError: String?
    public var miseVersion: String?
    public var miseLoaded = false
    public var miseCurrentError: String?
    public var miseLatestVersion: String?
    public var miseLatestLoaded = false
    public var miseLatestError: String?
    public var miseLatestCheckedAt: String?
    public var miseLastResult = ""
    public var miseSelfUpdateError: String?
    public var pendingMiseUpdateConfirm = false
    public var plugins: [PluginRow] = []
    public var logs: [String] = []
    var globalBusy = false
    public internal(set) var toolOperations: [String: String] = [:]
    public var busy: Bool { globalBusy || !toolOperations.isEmpty }
    @ObservationIgnored var globalVersionChanging = false
    @ObservationIgnored var globalVersionWaiters: [CheckedContinuation<Void, Never>] = []
    /// Real percentage when one exists (N/M plugin checks); nil = indeterminate.
    private var globalProgress: Double? = 0
    public var progress: Double? { toolOperations.isEmpty ? globalProgress : nil }
    private var globalProgressLabel = Strings.ready
    public var progressLabel: String {
        if toolOperations.count > 1 { return "도구 \(toolOperations.count)개 작업 중" }
        return toolOperations.values.first ?? globalProgressLabel
    }
    /// Latest subprocess output line while busy.
    public var liveOutputLine = ""
    public var pendingDelete: PendingDelete?
    public var pendingMajorUpdate: PendingMajorUpdate?
    public var remotePluginNames: [String] = []
    public var installedPluginNames: [String] = []
    public var corePluginNames: [String] = []
    public var installedToolNames: [String] = []
    public var remotePluginInfos: [PluginDefinitionInfo] = []
    public var installedUserPluginInfos: [PluginDefinitionInfo] = []
    public var pluginSearchQuery = ""
    public var installsLoaded = false
    public var pendingPluginUrlDialog: PluginUrlDialog?
    public var pendingPluginNameValue = ""
    public var pendingPluginUrlValue = ""
    public var miseInstalledChecked = false
    public var miseIsInstalled = true
    public var miseInstalling = false
    public var miseInstallMethod: MiseInstallMethod?

    @ObservationIgnored private var statusResetTask: Task<Void, Never>?

    public init(
        mise: Mise, settings: Settings,
        latestRelease: @escaping @Sendable () async throws -> String? = ReleaseChecker.latestMiseRelease
    ) {
        self.mise = mise
        self.settings = settings
        self.latestRelease = latestRelease
    }

    // MARK: Busy / progress

    public func toolActionsDisabled(_ name: String) -> Bool {
        globalBusy || updateCheckRunning || toolOperations[name] != nil || toolOperations.count >= 2
    }

    public func setBusy(_ nextBusy: Bool, _ label: String = Strings.ready, progress nextProgress: Double? = nil) {
        statusResetTask?.cancel()
        statusResetTask = nil
        if nextBusy { liveOutputLine = "" }
        globalBusy = nextBusy
        globalProgressLabel = label
        globalProgress = nextProgress
        // Completion labels ("확인 완료 · 100%") shouldn't linger forever.
        if !nextBusy && label != Strings.ready {
            statusResetTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled, let self, !self.busy else { return }
                self.globalProgressLabel = Strings.ready
                self.globalProgress = 0
            }
        }
    }

    // MARK: Logs (150 lines, newest first)

    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy. M. d. HH:mm:ss"
        return formatter
    }()

    public static func nowLabel() -> String { logFormatter.string(from: Date()) }

    public func addLog(_ message: String) {
        logs.insert("[\(Self.nowLabel())] \(message)", at: 0)
        if logs.count > 150 { logs.removeLast(logs.count - 150) }
    }

    public func clearLogs() { logs = [] }

    // MARK: Row helpers

    public func plugin(_ name: String) -> PluginRow? { plugins.first { $0.name == name } }

    func updatePlugin(_ name: String, _ patch: (inout PluginRow) -> Void) {
        guard let index = plugins.firstIndex(where: { $0.name == name }) else { return }
        patch(&plugins[index])
        plugins[index].normalizeInstalled()
    }

    /// Every name the installs tab can offer: remote catalog, user plugins, core plugins, installed tools.
    public var installCatalog: [String] {
        Array(Set(remotePluginNames + installedPluginNames + corePluginNames + installedToolNames))
            .sorted { $0.localizedCompare($1) == .orderedAscending }
    }
}
