import AppKit
import MiseCore

/// Owns the app state for the whole process: the window can close and reopen, checks keep running.
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
        #if DEBUG
        installSnapshotHook()
        #endif
    }


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Dock click after the window was closed brings it back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { state.showMainWindow() }
        return false
    }
}
