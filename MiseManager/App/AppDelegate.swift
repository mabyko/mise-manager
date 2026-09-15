import AppKit
import MiseCore

/// Owns the app state for the whole process: the window can close and reopen, checks keep running.
/// The bundle is LSUIElement (no Dock icon); the Dock icon appears only while the main window is open.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let cli = MiseCLI()
    let state: AppState
    private(set) var statusItem: StatusItemController?
    private var outputTask: Task<Void, Never>?

    override init() {
        state = AppState(mise: Mise(runner: cli), settings: Settings())
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        outputTask = Task { [cli, state] in
            for await line in cli.output { state.liveOutputLine = line.line }
        }
        let statusItem = StatusItemController(state: state)
        self.statusItem = statusItem
        state.showTray = { statusItem.show() }
        Task { await state.startup() }
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: nil)
        if launchedAsLoginItem {
            // Menu bar only: SwiftUI already opened the main window scene, close it before it shows.
            NSApp.windows.filter(Self.isMainWindow).forEach { $0.close() }
        } else {
            // A launch by the user (Finder, Spotlight) asks for the window; accessory apps are not activated on launch.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        #if DEBUG
        installSnapshotHook()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Dock or Finder reopen after the window was closed brings it back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { state.showMainWindow() }
        return false
    }

    /// The open-application event carries this flag when loginwindow started us (SMAppService.mainApp).
    private var launchedAsLoginItem: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MISE_LOGIN_LAUNCH"] != nil { return true }
        #endif
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == AEEventID(kAEOpenApplication)
            && event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }

    /// Last main window closed: back to the menu bar only. Without a menu-bar icon the Dock icon stays so
    /// the app remains reachable.
    @objc private func windowWillClose(_ note: Notification) {
        guard let closing = note.object as? NSWindow, Self.isMainWindow(closing) else { return }
        let another = NSApp.windows.contains { $0 !== closing && $0.isVisible && Self.isMainWindow($0) }
        if !another, state.settings.showMenuBarIcon { NSApp.setActivationPolicy(.accessory) }
    }

    /// Not the tray panel, alerts, sheets or the status item's own window (none of those can become main).
    private static func isMainWindow(_ window: NSWindow) -> Bool { window.canBecomeMain && window.sheetParent == nil }
}
