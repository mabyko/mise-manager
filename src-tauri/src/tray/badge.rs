use objc2::{define_class, msg_send, rc::Retained, MainThreadMarker, MainThreadOnly};
use objc2_app_kit::{NSBezierPath, NSColor, NSStatusBarButton, NSView};
use objc2_foundation::{NSPoint, NSRect, NSSize};

define_class!(
    #[unsafe(super(NSView))]
    #[name = "MiseManagerUpdateBadge"]
    struct UpdateBadge;

    impl UpdateBadge {
        #[unsafe(method(drawRect:))]
        fn draw(&self, _rect: NSRect) {
            // A separate native view preserves the parent icon's template tint.
            let circle = NSBezierPath::bezierPathWithOvalInRect(NSRect::new(
                NSPoint::new(1.0, 1.0), NSSize::new(6.0, 6.0),
            ));
            NSColor::whiteColor().set();
            circle.setLineWidth(2.0);
            circle.stroke();
            NSColor::systemRedColor().set();
            circle.fill();
        }

        #[unsafe(method(hitTest:))]
        fn hit_test(&self, _point: NSPoint) -> *mut NSView {
            // Clicking the badge must still open the status item's popover.
            std::ptr::null_mut()
        }

        #[unsafe(method(isAccessibilityElement))]
        fn is_accessibility_element(&self) -> bool {
            false // The parent retains the update count and descriptive tooltip.
        }
    }
);

pub fn update(button: &NSStatusBarButton, available: bool, checking: bool) {
    // Checks temporarily clear version candidates; keep the last visible badge.
    if checking && !available {
        return;
    }
    let existing = button
        .subviews()
        .iter()
        .find_map(|view| view.downcast::<UpdateBadge>().ok());
    if !available {
        if let Some(badge) = existing {
            badge.setHidden(true);
        }
        return;
    }

    let bounds = button.bounds();
    let Some(cell) = button.cell() else { return };
    let icon = cell.imageRectForBounds(bounds);
    let top = if button.isFlipped() {
        icon.origin.y
    } else {
        icon.origin.y + icon.size.height - 8.0
    };
    let frame = NSRect::new(
        NSPoint::new(icon.origin.x + icon.size.width - 6.0, top),
        NSSize::new(8.0, 8.0),
    );
    let badge = existing.unwrap_or_else(|| {
        let allocated = UpdateBadge::alloc(MainThreadMarker::from(button));
        // NSView's designated initializer, called on the main thread.
        let view: Retained<UpdateBadge> = unsafe { msg_send![allocated, initWithFrame: frame] };
        button.addSubview(&view);
        view
    });
    badge.setFrame(frame);
    badge.setHidden(false);
}
