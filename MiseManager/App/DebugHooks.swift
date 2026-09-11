#if DEBUG
import AppKit
import MiseCore
import SwiftUI

/// Debug-only inspection hooks, driven by the `MiseManager.snapshot` distributed notification.
/// Lets the migration be checked without screen-recording permission:
///   userInfo {path, tab?, action?}; action = major | delete | mise | plugin | close (dialogs),
///   ax (accessibility tree as text), render (tab body via ImageRenderer), default = key window cacheDisplay.
extension AppDelegate {
    /// Debug-only: `MiseManager.snapshot` distributed notification with userInfo
    /// {path, tab?, action?} switches tab / opens a dialog and writes the key window as PNG.
    /// Lets the migration be checked visually without screen-recording permission.
    func installSnapshotHook() {
        DistributedNotificationCenter.default().addObserver(forName: .init("MiseManager.snapshot"), object: nil, queue: .main) { note in
            guard let info = note.userInfo, let path = info["path"] as? String else { return }
            let tab = info["tab"] as? String
            let action = info["action"] as? String
            MainActor.assumeIsolated {
                let state = self.state
                if let tab = tab.flatMap(ActiveTab.init(rawValue:)) { state.activeTab = tab }
                switch action {
                case "major": state.requestMajorUpdate(state.plugins.first?.name ?? "node", "99.0.0")
                case "delete": state.requestDelete(state.plugins.first?.name ?? "node", "1.0.0")
                case "mise": state.pendingMiseUpdateConfirm = true
                case "plugin": state.openCustomPluginDialog()
                case "tray": state.showTray()
                case "sample": self.loadSample()
                case "trayMain":
                    // Under the menu bar of the main display, near its right edge, whatever the cursor does.
                    if let screen = NSScreen.main {
                        self.statusItem?.show(cursor: CGPoint(x: screen.frame.maxX - 260, y: screen.frame.maxY - 5))
                    }
                case "close":
                    state.pendingMajorUpdate = nil; state.pendingDelete = nil
                    state.pendingMiseUpdateConfirm = false; state.closePluginUrlDialog()
                default: break
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    switch action {
                    case "ax": self.dumpAccessibility(to: path)
                    case "render": self.render(state.activeTab, to: path)
                    case "trayrender": self.renderTray(to: path)
                    case "status": try? (self.statusItem?.debugDescription ?? "no controller").write(toFile: path, atomically: true, encoding: .utf8)
                    case "statusitem": self.renderStatusItem(to: path)
                    default: self.snapshot(to: path)
                    }
                }
            }
        }
    }

    /// Renders one tab's body offscreen with ImageRenderer (pure SwiftUI only; no sidebar/toolbar).
    private func render(_ tab: ActiveTab, to path: String) {
        let content = MainWindow.tabView(tab, state: state)
            .environment(\.snapshotMode, true)
            .frame(width: 860)
            .background(Color(nsColor: .windowBackgroundColor))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return }
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    /// Reproducible example state for README screenshots (same fixture the 0.1.x browser preview used).
    private func loadSample() {
        let now = AppState.nowLabel()
        state.settings.theme = .light
        state.miseVersion = "2026.8.12 macos-arm64"
        state.miseLoaded = true
        state.miseCurrentError = nil
        state.miseLatestVersion = "v2026.8.13"
        state.miseLatestLoaded = true
        state.miseLatestError = nil
        state.miseLatestCheckedAt = now
        func row(_ name: String, _ global: String, _ installed: [String], _ byMajor: [String: String], _ same: String, _ release: String, _ overall: String?, _ checked: Int) -> PluginRow {
            PluginRow(name: name, activeGlobalVersion: global, installedVersions: installed, latestByMajor: byMajor,
                      sameMajorLatest: same, releaseLatest: release, overallLatest: overall, checkedVersions: checked, status: .done)
        }
        state.plugins = [
            row("node", "26.0.0", ["26.0.0", "24.20.0", "24.19.0"], ["24": "24.21.0", "26": "26.1.0"], "26.1.0", "26.1.0", "27.0.0-rc.1", 860),
            row("python", "3.12.8", ["3.12.8", "3.11.11"], ["3": "3.13.2"], "3.13.2", "3.13.2", nil, 248),
            row("bun", "1.2.4", ["1.2.4"], ["1": "1.2.4"], "1.2.4", "1.2.4", nil, 214),
            row("rust", "1.85.0", ["1.85.0"], ["1": "1.85.0"], "1.85.0", "1.85.0", nil, 152),
            row("go", "1.24.0", ["1.24.0"], ["1": "1.24.0"], "1.24.0", "1.24.0", nil, 130),
            row("ruby", "3.4.2", ["3.4.2"], ["3": "3.4.2"], "3.4.2", "3.4.2", nil, 133),
        ]
        state.toolsLoaded = true
        state.toolsCheckedAt = now
        state.toolsError = nil
        state.outdatedPluginNames = ["flutter", "zoxide"]
        state.pluginUpdatesCheckedAt = now
        state.pluginUpdatesError = nil
        state.selectedToolName = "node"
        state.activeTab = .updater
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.contentView != nil && $0.isVisible }), let screen = NSScreen.main {
            let size = CGSize(width: 1200, height: 820)
            let origin = CGPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.midY - size.height / 2)
            window.setFrame(CGRect(origin: origin, size: size), display: true)
        }
    }

    /// The status bar button (icon, count, badge) on a transparent background.
    private func renderStatusItem(to path: String) {
        guard let button = statusItem?.button, let rep = button.bitmapImageRepForCachingDisplay(in: button.bounds) else { return }
        button.cacheDisplay(in: button.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    private func renderTray(to path: String) {
        let content = TrayPanelView(state: state, close: {})
            .environment(\.snapshotMode, true)
            .background(Color(nsColor: .windowBackgroundColor))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return }
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    /// Text dump of the key window's accessibility tree (roles + titles/values), for checks without pixels.
    private func dumpAccessibility(to path: String) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) else { return }
        var out = ""
        func visit(_ node: Any, _ depth: Int) {
            guard depth < 40, let element = node as? any NSAccessibilityProtocol else { return }
            let role = element.accessibilityRole()?.rawValue.replacingOccurrences(of: "AX", with: "") ?? "?"
            var parts: [String] = []
            for text in [element.accessibilityTitle(), element.accessibilityLabel(), element.accessibilityPlaceholderValue()] {
                if let text, !text.isEmpty { parts.append(text) }
            }
            if let value = element.accessibilityValue() {
                let text = (value as? String) ?? String(describing: value)
                if !text.isEmpty { parts.append("= " + text) }
            }
            if role == "Button" || role == "CheckBox" || role == "PopUpButton" || role == "TextField" || !parts.isEmpty {
                out += String(repeating: "  ", count: depth) + role + (parts.isEmpty ? "" : ": " + parts.joined(separator: " | "))
                    + (element.isAccessibilityEnabled() ? "" : " (disabled)") + "\n"
            }
            for child in element.accessibilityChildren() ?? [] { visit(child, depth + 1) }
        }
        visit(window, 0)
        try? out.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func snapshot(to path: String) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible),
              let content = window.contentView, let view = content.superview ?? Optional(content),
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        // Materials don't render offscreen; paint the window background so light-on-dark text stays legible.
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: view.bounds.size).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
#endif
