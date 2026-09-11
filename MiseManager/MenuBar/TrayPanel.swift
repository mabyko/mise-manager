import AppKit
import MiseCore
import SwiftUI

/// Non-activating popover under the status item: the app never comes forward, the main window
/// does not follow, and an outside click or Esc closes it. Shows over full-screen apps.
final class TrayPanel: NSPanel {
    static let size = CGSize(width: 440, height: 620)
    /// Screen rect of the status item; clicks there belong to its action, not to "outside".
    var ownerFrame: @MainActor () -> CGRect? = { nil }
    private(set) var lastClosedAt = Date.distantPast
    private var outsideClickMonitor: Any?

    init(state: AppState) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered, defer: false)
        title = "Mise Manager · 빠른 관리"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { standardWindowButton(kind)?.isHidden = true }
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        isOpaque = false
        backgroundColor = .clear

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        let hosting = NSHostingView(rootView: TrayPanelView(state: state, close: { [weak self] in self?.close() }).ignoresSafeArea())
        hosting.frame = effect.bounds
        hosting.autoresizingMask = [.width, .height]
        effect.addSubview(hosting)
        contentView = effect
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(at frame: CGRect) {
        setFrame(frame, display: false)
        orderFrontRegardless()
        makeKey()
        if outsideClickMonitor == nil {
            // macOS 26 routes status-item clicks through the Control Center proxy, so they arrive here
            // as another app's click; closing on them would let the click's own action reopen the panel.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if let owner = self.ownerFrame(), owner.contains(NSEvent.mouseLocation) { return }
                    self.close()
                }
            }
        }
    }

    override func close() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
        if isVisible { lastClosedAt = Date() }
        super.close()
    }

    override func resignKey() {
        super.resignKey()
        close()
    }

    override func cancelOperation(_ sender: Any?) { close() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { close() } else { super.keyDown(with: event) }
    }
}
