use tauri::{
    image::Image,
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Manager, PhysicalPosition, WebviewUrl, WebviewWindowBuilder, WindowEvent,
};

#[tauri::command]
pub fn show_main_window(app: AppHandle) -> Result<(), String> {
    let window = app
        .get_webview_window("main")
        .ok_or("Main window unavailable")?;
    window.unminimize().map_err(|e| e.to_string())?;
    window.show().map_err(|e| e.to_string())?;
    window.set_focus().map_err(|e| e.to_string())?;
    hide_tray_window(app)
}

#[tauri::command]
pub fn hide_tray_window(app: AppHandle) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("tray") {
        window.hide().map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
pub fn show_tray_window(app: AppHandle) -> Result<(), String> {
    let show = || -> tauri::Result<()> {
        let Some(window) = app.get_webview_window("tray") else {
            return Ok(());
        };
        let rect = app
            .tray_by_id("updates")
            .map(|tray| tray.rect())
            .transpose()?
            .flatten();
        // Tray coordinates are physical. Tao's monitor_from_point uses logical
        // coordinates on macOS, so compare against physical monitor bounds here.
        let monitor = window
            .available_monitors()?
            .into_iter()
            .find(|monitor| {
                let Some(rect) = rect else { return false };
                let origin = rect.position.to_physical::<f64>(monitor.scale_factor());
                let position = monitor.position();
                let size = monitor.size();
                origin.x >= position.x as f64
                    && origin.x < position.x as f64 + size.width as f64
                    && origin.y >= position.y as f64
                    && origin.y < position.y as f64 + size.height as f64
            })
            .or(app
                .get_webview_window("main")
                .and_then(|main| main.current_monitor().ok().flatten()));
        if let Some(monitor) = monitor {
            let scale = monitor.scale_factor();
            let area = monitor.work_area();
            let width = (440.0 * scale).min(area.size.width as f64);
            let height = (620.0 * scale).min(area.size.height as f64);
            let anchor = rect
                .map(|rect| {
                    let origin = rect.position.to_physical::<f64>(scale);
                    let size = rect.size.to_physical::<f64>(scale);
                    (
                        origin.x + size.width / 2.0,
                        origin.y + size.height + 6.0 * scale,
                    )
                })
                .unwrap_or((
                    area.position.x as f64 + area.size.width as f64,
                    area.position.y as f64,
                ));
            let origin = clamped_origin(
                anchor,
                (width, height),
                (
                    area.position.x as f64,
                    area.position.y as f64,
                    area.size.width as f64,
                    area.size.height as f64,
                ),
            );
            window.set_size(tauri::LogicalSize::new(width / scale, height / scale))?;
            window.set_position(origin.to_logical::<f64>(scale))?;
        }
        window.show()?;
        window.set_focus()
    };
    show().map_err(|error| error.to_string())
}

#[tauri::command]
pub fn set_tray_status(
    app: AppHandle,
    count: usize,
    attention: bool,
    checking: bool,
    visible: bool,
) -> Result<(), String> {
    if let Some(tray) = app.tray_by_id("updates") {
        let title = if checking {
            "…".into()
        } else if count > 0 {
            count.to_string()
        } else if attention {
            "!".into()
        } else {
            String::new()
        };
        tray.set_title(Some(title)).map_err(|e| e.to_string())?;
        let detail = if checking {
            "확인 중"
        } else if attention {
            "일부 항목 미확인"
        } else {
            "확인 완료"
        };
        tray.set_tooltip(Some(format!(
            "Mise Manager · 업데이트 {count}개 · {detail}"
        )))
        .map_err(|e| e.to_string())?;
        tray.set_visible(visible).map_err(|e| e.to_string())?;
    }
    if !visible {
        hide_tray_window(app)?;
    }
    Ok(())
}

// Keep the popover within the clicked monitor, including negative desktop coordinates.
fn clamped_origin(
    anchor: (f64, f64),
    size: (f64, f64),
    area: (f64, f64, f64, f64),
) -> PhysicalPosition<f64> {
    PhysicalPosition::new(
        (anchor.0 - size.0 / 2.0).clamp(area.0, (area.0 + area.2 - size.0).max(area.0)),
        anchor
            .1
            .clamp(area.1, (area.1 + area.3 - size.1).max(area.1)),
    )
}

pub fn setup(app: &mut tauri::App) -> tauri::Result<()> {
    let popup = WebviewWindowBuilder::new(
        app,
        "tray",
        WebviewUrl::App("index.html?surface=tray".into()),
    )
    .title("Mise Manager · 빠른 관리")
    .inner_size(440.0, 620.0)
    .visible(false)
    .focused(false)
    .decorations(false)
    .resizable(false)
    .always_on_top(true)
    .skip_taskbar(true)
    .shadow(true)
    .build()?;
    let handle = app.handle().clone();
    popup.on_window_event(move |event| {
        if matches!(event, WindowEvent::Focused(false)) {
            if let Err(error) = hide_tray_window(handle.clone()) {
                log::warn!("Hide tray: {error}");
            }
        }
    });
    let open = MenuItem::with_id(app, "open-main", "Mise Manager 열기", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit-app", "Mise Manager 종료", true, None::<&str>)?;
    let menu = Menu::with_items(app, &[&open, &quit])?;
    // A small template icon; macOS supplies the correct menu-bar tint.
    let mut rgba = vec![0; 18 * 18 * 4];
    for y in [4, 8, 12] {
        for dy in 0..2 {
            for x in 3..15 {
                rgba[((y + dy) * 18 + x) * 4 + 3] = 255;
            }
        }
    }
    TrayIconBuilder::with_id("updates")
        .icon(Image::new_owned(rgba, 18, 18))
        .icon_as_template(true)
        .tooltip("Mise Manager · 업데이트 확인 전")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "open-main" => {
                if let Err(error) = show_main_window(app.clone()) {
                    log::warn!("Open main: {error}");
                }
            }
            "quit-app" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if matches!(
                event,
                TrayIconEvent::Click {
                    button: MouseButton::Left,
                    button_state: MouseButtonState::Up,
                    ..
                }
            ) {
                if let Err(error) = show_tray_window(tray.app_handle().clone()) {
                    log::warn!("Open tray: {error}");
                }
            }
        })
        .build(app)?
        // The main webview applies the saved visibility at startup.
        .set_visible(false)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn positions_on_small_and_negative_coordinate_monitors() {
        assert_eq!(
            clamped_origin(
                (-10.0, 30.0),
                (440.0, 620.0),
                (-1440.0, 24.0, 1440.0, 876.0)
            ),
            PhysicalPosition::new(-440.0, 30.0)
        );
        assert_eq!(
            clamped_origin((10.0, 900.0), (880.0, 1240.0), (0.0, 48.0, 800.0, 1000.0)),
            PhysicalPosition::new(0.0, 48.0)
        );
    }
}
