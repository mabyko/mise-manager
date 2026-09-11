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
