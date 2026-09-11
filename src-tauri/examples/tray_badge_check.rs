//! Native UI regression check: cargo run --example tray_badge_check (macOS).
#[cfg(target_os = "macos")]
#[path = "../src/tray/badge.rs"]
mod badge;

#[cfg(target_os = "macos")]
fn main() {
    use objc2::{msg_send, MainThreadMarker};
    use objc2_app_kit::{
        NSAppearance, NSAppearanceCustomization, NSApplication, NSBitmapImageFileType,
        NSCellImagePosition, NSImage, NSStatusBar,
    };
    use objc2_foundation::{NSDictionary, NSPoint, NSSize, NSString};

    let mtm = MainThreadMarker::new().expect("run on the main thread");
    let _app = NSApplication::sharedApplication(mtm);
    let bar = NSStatusBar::systemStatusBar();
    // Hiding and showing the app's tray creates a new native status item.
    for _ in 0..2 {
        let item = bar.statusItemWithLength(-1.0);
        let button = item.button(mtm).unwrap();
        let icon = NSImage::imageWithSystemSymbolName_accessibilityDescription(
            &NSString::from_str("line.3.horizontal"),
            None,
        )
        .unwrap();
        icon.setSize(NSSize::new(18.0, 18.0));
        icon.setTemplate(true);
        button.setImage(Some(&icon));
        button.setImagePosition(NSCellImagePosition::ImageLeft);
        let baseline = button.subviews().len();
        badge::update(&button, false, false);
        assert_eq!(button.subviews().len(), baseline);
        for title in ["3", "…", "12"] {
            button.setTitle(&NSString::from_str(title));
            button.sizeToFit();
            badge::update(&button, true, false);
            badge::update(&button, false, true);
            assert_eq!(button.subviews().len(), baseline + 1, "reuse one badge");
            let dot = button.subviews().lastObject().unwrap();
            assert!(!dot.isHidden(), "updates remain visible during checks");
            assert!(
                dot.hitTest(NSPoint::new(4.0, 4.0)).is_none(),
                "badge must not swallow clicks"
            );
            let accessible: bool = unsafe { msg_send![&dot, isAccessibilityElement] };
            assert!(
                !accessible,
                "badge is decorative; the parent describes updates"
            );
            assert!(
                button.image().unwrap().isTemplate(),
                "keep native light/dark tint"
            );
            assert!(dot.frame().origin.x >= 0.0);
            assert!(dot.frame().origin.y >= 0.0);
        }
        if let Some(directory) = std::env::var_os("MISE_BADGE_CAPTURE_DIR") {
            let directory = std::path::PathBuf::from(directory);
            std::fs::create_dir_all(&directory).unwrap();
            for theme in ["NSAppearanceNameAqua", "NSAppearanceNameDarkAqua"] {
                let appearance = NSAppearance::appearanceNamed(&NSString::from_str(theme)).unwrap();
                button.setAppearance(Some(&appearance));
                let bitmap = button
                    .bitmapImageRepForCachingDisplayInRect(button.bounds())
                    .unwrap();
                button.cacheDisplayInRect_toBitmapImageRep(button.bounds(), &bitmap);
                // No format-specific options are passed to AppKit.
                let png = unsafe {
                    bitmap.representationUsingType_properties(
                        NSBitmapImageFileType::PNG,
                        &NSDictionary::new(),
                    )
                }
                .unwrap();
                std::fs::write(directory.join(format!("{theme}.png")), png.to_vec()).unwrap();
            }
        }
        badge::update(&button, false, false);
        assert!(
            button.subviews().lastObject().unwrap().isHidden(),
            "clear when no updates remain"
        );
        bar.removeStatusItem(&item);
    }
    println!("Native badge: visibility, reuse, click-through, template tint and recreation passed");
}

#[cfg(not(target_os = "macos"))]
fn main() {
    eprintln!("This check requires macOS.");
}
