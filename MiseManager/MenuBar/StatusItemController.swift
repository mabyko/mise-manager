import AppKit
import MiseCore
import Observation

/// Owns the NSStatusItem and its panel. Title (`…` / count / `!` / empty), tooltip, red badge and
/// visibility follow the app state through observation tracking. No `statusItem.menu`: macOS 26
/// pops it on its own for clicks routed through the Control Center proxy, so open and quit live
/// inside the panel.
@MainActor
final class StatusItemController {
    private let state: AppState
    private let panel: TrayPanel
    private var item: NSStatusItem?

    init(state: AppState) {
        self.state = state
        panel = TrayPanel(state: state)
        observe()
    }

    private func observe() {
        withObservationTracking {
            apply()
        } onChange: {
            Task { @MainActor [weak self] in self?.observe() }
        }
    }

    private func apply() {
        guard state.settings.showMenuBarIcon else {
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
            panel.close()
            return
        }
        let item = self.item ?? makeItem()
        guard let button = item.button else { return }
        let summary = state.updateSummary
        let checking = state.busy || state.updateCheckRunning
        let count = summary.items.count
        button.title = checking ? "…" : count > 0 ? "\(count)" : summary.attention ? "!" : ""
        let detail = checking ? "확인 중" : summary.attention ? "일부 항목 미확인" : "확인 완료"
        button.toolTip = "Mise Manager · 업데이트 \(count)개 · \(detail)"
        BadgeView.update(on: button, available: count > 0, checking: checking)
    }

    private func makeItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Mise Manager")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(toggle)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.item = item
        return item
    }

    @objc private func toggle() {
        if panel.isVisible { panel.close() } else { show() }
    }

    func show() {
        guard state.settings.showMenuBarIcon else { return }
        let cursor = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSApp.keyWindow?.screen ?? NSScreen.main else { return }
        let icon = item?.button.flatMap { button -> CGPoint? in
            guard let window = button.window else { return nil }
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            return CGPoint(x: rect.midX, y: rect.minY - 6)
        }
        let anchor = PanelPositioner.anchor(
            icon: icon, fallback: CGPoint(x: cursor.x, y: screen.visibleFrame.maxY), screen: screen.frame)
        panel.show(at: PanelPositioner.frame(anchor: anchor, size: TrayPanel.size, area: screen.visibleFrame))
    }

    func hide() { panel.close() }

    var debugDescription: String {
        guard let button = item?.button else { return "status item: hidden" }
        let badge = button.subviews.compactMap { $0 as? BadgeView }.first
        return "status item: visible title='\(button.title)' tooltip='\(button.toolTip ?? "")' badge=\(badge.map { $0.isHidden ? "hidden" : "shown" } ?? "none") panel=\(panel.isVisible)"
    }
}
