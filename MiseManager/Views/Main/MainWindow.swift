import MiseCore
import SwiftUI

struct MainWindow: View {
    @Bindable var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            Sidebar(state: state)
        } detail: {
            detail
                .safeAreaInset(edge: .bottom, spacing: 0) { StatusBar(state: state) }
        }
        .preferredColorScheme(colorScheme)
        .appDialogs(state)
        .onAppear {
            state.showMainWindow = {
                // LSUIElement app: the Dock icon comes back only while the window is open. Activation must
                // stay inside the user event that got us here; macOS 14+ drops it otherwise.
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
        }
        .onChange(of: state.settings.checkIntervalHours) { state.scheduleIntervalChecks() }
    }

    private var detail: some View { Self.tabView(state.activeTab, state: state) }

    @ViewBuilder static func tabView(_ tab: ActiveTab, state: AppState) -> some View {
        switch tab {
        case .updater: UpdaterTab(state: state)
        case .updates: UpdatesTab(state: state)
        case .mise: MiseTab(state: state)
        case .installs: InstallsTab(state: state)
        case .logs: LogsTab(state: state)
        case .settings: SettingsTab(state: state)
        }
    }

    private var colorScheme: ColorScheme? {
        switch state.settings.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
