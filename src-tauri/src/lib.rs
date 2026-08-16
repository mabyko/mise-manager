mod actions;
mod catalog;
mod config;
mod contracts;
mod mise;
mod version;

use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // The macOS default menu Tauri installs already carries the Edit roles
    // (undo/redo/cut/copy/paste/select-all) that Electrobun's custom menu provided.
    tauri::Builder::default()
        .manage(mise::MiseState::default())
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            // Warm the mise path cache (a handful of stat calls).
            app.state::<mise::MiseState>().executable();
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            actions::get_mise_version,
            actions::get_latest_mise_release,
            actions::self_update_mise,
            actions::check_plugin_updates,
            actions::use_global_plugin,
            actions::install_plugin,
            actions::delete_plugin_version,
            actions::install_plugin_definition,
            actions::uninstall_plugin_definition,
            actions::check_mise_installed,
            actions::install_mise_sh,
            actions::install_mise_brew,
            actions::get_platform,
            catalog::list_installed_plugins,
            catalog::list_installed_plugin_names,
            catalog::list_installed_user_plugin_infos,
            catalog::list_core_plugin_names,
            catalog::list_installed_tool_names,
            catalog::list_remote_plugin_names,
            catalog::list_remote_plugin_infos,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
