import CoreGraphics
import Testing
@testable import MiseManager

// Mirrors the tray.rs tests, in Cocoa coordinates (origin bottom-left).
struct PanelPositionerTests {
    @Test func anchorIgnoresOffscreenIconAxes() {
        let screen = CGRect(x: 0, y: 0, width: 3456, height: 2234)
        // Thaw parks hidden items far left; keep the menu-bar row, use the cursor x.
        #expect(PanelPositioner.anchor(icon: CGPoint(x: -4690, y: 2200), fallback: CGPoint(x: 3000, y: 2210), screen: screen) == CGPoint(x: 3000, y: 2200))
        #expect(PanelPositioner.anchor(icon: CGPoint(x: 2800, y: 2200), fallback: CGPoint(x: 3000, y: 2210), screen: screen) == CGPoint(x: 2800, y: 2200))
        #expect(PanelPositioner.anchor(icon: nil, fallback: CGPoint(x: 3000, y: 2210), screen: screen) == CGPoint(x: 3000, y: 2210))
    }

    @Test func positionsOnSmallAndNegativeCoordinateMonitors() {
        // Anchor near the left edge of a display placed at negative x: the panel hugs that edge.
        #expect(PanelPositioner.frame(anchor: CGPoint(x: -10, y: 870), size: CGSize(width: 440, height: 620), area: CGRect(x: -1440, y: 0, width: 1440, height: 876))
            == CGRect(x: -440, y: 250, width: 440, height: 620))
        // A panel larger than the display shrinks to it and sits at its origin.
        #expect(PanelPositioner.frame(anchor: CGPoint(x: 10, y: 900), size: CGSize(width: 880, height: 1240), area: CGRect(x: 0, y: 0, width: 800, height: 1000))
            == CGRect(x: 0, y: 0, width: 800, height: 1000))
    }
}
