import AppKit

/// Red dot over the status item image. A separate view keeps the parent icon's template tint.
final class BadgeView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 6, height: 6))
        NSColor.white.set()
        circle.lineWidth = 2
        circle.stroke()
        NSColor.systemRed.set()
        circle.fill()
    }

    /// Clicking the badge must still open the status item's panel.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func isAccessibilityElement() -> Bool { false }

    /// Checks temporarily clear version candidates; keep the last visible badge while checking.
    static func update(on button: NSStatusBarButton, available: Bool, checking: Bool) {
        if checking && !available { return }
        let existing = button.subviews.compactMap { $0 as? BadgeView }.first
        guard available else {
            existing?.isHidden = true
            return
        }
        guard let cell = button.cell as? NSButtonCell else { return }
        let icon = cell.imageRect(forBounds: button.bounds)
        let top = button.isFlipped ? icon.minY : icon.maxY - 8
        let frame = NSRect(x: icon.maxX - 6, y: top, width: 8, height: 8)
        let badge = existing ?? {
            let view = BadgeView(frame: frame)
            button.addSubview(view)
            return view
        }()
        badge.frame = frame
        badge.isHidden = false
    }
}
