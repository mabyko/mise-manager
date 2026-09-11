import CoreGraphics

/// Where the menu-bar panel goes, in Cocoa screen coordinates (origin bottom-left).
/// The status item window can sit off-screen (menu bar hiders such as Thaw, notch overflow),
/// so the screen is chosen from the cursor and the icon position is trusted per axis only when
/// it lies inside that screen.
enum PanelPositioner {
    /// Icon axes outside `screen` fall back to the cursor x and the top of the visible area.
    static func anchor(icon: CGPoint?, fallback: CGPoint, screen: CGRect) -> CGPoint {
        CGPoint(
            x: icon.map(\.x).flatMap { (screen.minX..<screen.maxX).contains($0) ? $0 : nil } ?? fallback.x,
            y: icon.map(\.y).flatMap { (screen.minY..<screen.maxY).contains($0) ? $0 : nil } ?? fallback.y)
    }

    /// Frame centered on the anchor x with its top edge at the anchor y, kept inside `area`
    /// (the screen's visible frame, which may have negative coordinates) and never larger than it.
    static func frame(anchor: CGPoint, size: CGSize, area: CGRect) -> CGRect {
        let width = min(size.width, area.width)
        let height = min(size.height, area.height)
        let x = min(max(anchor.x - width / 2, area.minX), max(area.minX, area.maxX - width))
        let y = min(max(anchor.y - height, area.minY), max(area.minY, area.maxY - height))
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
