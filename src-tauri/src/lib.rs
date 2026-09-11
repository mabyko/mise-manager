mod actions;
mod catalog;
mod config;
mod contracts;
mod mise;
mod tray;
mod version;

use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // The macOS default menu Tauri installs already carries the Edit roles
    // (undo/redo/cut/copy/paste/select-all) that Electrobun's custom menu provided.
    tauri::Builder::default()
        .manage(mise::MiseState::default())
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            let state = app.state::<mise::MiseState>();
            state.set_app_handle(app.handle().clone());
            // Warm the mise path cache (a handful of stat calls).
            state.executable();
            tray::setup(app)?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            tray::show_main_window,
            tray::show_tray_window,
            tray::hide_tray_window,
            tray::set_tray_status,
            actions::get_mise_version,
            actions::get_latest_mise_release,
            actions::self_update_mise,
            actions::check_plugin_updates,
            actions::use_global_plugin,
            actions::install_plugin,
            actions::delete_plugin_version,
            actions::install_plugin_definition,
            actions::uninstall_plugin_definition,
            actions::update_plugin_definition,
            actions::check_mise_installed,
            actions::install_mise_sh,
            actions::install_mise_brew,
            actions::get_platform,
            catalog::list_installed_plugins,
            catalog::list_outdated_plugin_definitions,
            catalog::list_installed_plugin_names,
            catalog::list_installed_user_plugin_infos,
            catalog::list_core_plugin_names,
            catalog::list_installed_tool_names,
            catalog::list_remote_plugin_names,
            catalog::list_remote_plugin_infos,
        ])
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                if let Err(error) = window.hide() {
                    log::warn!("Hide window: {error}");
                }
            }
        })
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(|app, event| {
            #[cfg(target_os = "macos")]
            if let tauri::RunEvent::Reopen { .. } = event {
                if let Err(error) = tray::show_main_window(app.clone()) {
                    log::warn!("Reopen: {error}");
                }
            }
        });
}
