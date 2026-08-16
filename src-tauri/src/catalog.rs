// Port of src/bun/services/pluginCatalog.ts — read-only listings from mise.
use std::collections::{HashMap, HashSet};

use tauri::State;

use crate::config;
use crate::contracts::{PluginDefinitionInfo, PluginSummary};
use crate::mise::{self, MiseState};
use crate::version::compare_versions;

fn versions_from_entry(value: &serde_json::Value) -> Vec<String> {
    let Some(entries) = value.as_array() else {
        return Vec::new();
    };
    entries
        .iter()
        .filter_map(|entry| {
            entry
                .get("version")
                .and_then(|v| v.as_str())
                .and_then(mise::sanitize_version_str)
        })
        .collect()
}

/// Not a command — used by delete_plugin_version's guard and the summaries below.
/// Mirrors TS behavior: any failure yields an empty map.
pub async fn list_global_plugins(state: &MiseState) -> HashMap<String, String> {
    let Ok(result) = mise::run(state, &["ls", "--global", "--json"]).await else {
        return HashMap::new();
    };
    if result.exit_code != 0 {
        return HashMap::new();
    }
    let Ok(parsed) = serde_json::from_str::<serde_json::Value>(result.stdout.trim()) else {
        return HashMap::new();
    };
    let Some(entries) = parsed.as_object() else {
        return HashMap::new();
    };

    entries
        .iter()
        .filter_map(|(plugin, raw)| {
            let versions = versions_from_entry(raw);
            mise::pick_preferred_version(&versions).map(|preferred| (plugin.clone(), preferred))
        })
        .collect()
}

#[tauri::command]
pub async fn list_installed_plugins(state: State<'_, MiseState>) -> Result<Vec<PluginSummary>, String> {
    let result = mise::run_ok(
        &state,
        &["ls", "--installed", "--json"],
        "failed to run 'mise ls --installed --json'",
    )
    .await?;

    let parsed: serde_json::Value = serde_json::from_str(result.stdout.trim())
        .map_err(|_| "failed to parse JSON from 'mise ls --installed --json'".to_string())?;
    let entries = parsed
        .as_object()
        .ok_or_else(|| "unexpected installed tool JSON shape from mise".to_string())?;

    let global_map = list_global_plugins(&state).await;
    let mut summaries: Vec<PluginSummary> = Vec::new();
    let mut touched: HashSet<String> = HashSet::new();

    for (plugin, versions_raw) in entries {
        if !versions_raw.is_array() {
            continue;
        }
        let mut installed = mise::dedupe(versions_from_entry(versions_raw));
        installed.sort_by(|a, b| compare_versions(b, a));
        if installed.is_empty() {
            continue;
        }
        summaries.push(PluginSummary {
            name: plugin.clone(),
            active_global_version: global_map.get(plugin).cloned(),
            installed_versions: installed,
        });
        touched.insert(plugin.clone());
    }

    for (plugin, active) in &global_map {
        if touched.contains(plugin) {
            continue;
        }
        summaries.push(PluginSummary {
            name: plugin.clone(),
            active_global_version: Some(active.clone()),
            installed_versions: vec![active.clone()],
        });
    }

    summaries.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(summaries)
}

async fn list_trimmed_lines(
    state: &MiseState,
    args: &[&str],
    fallback_error: &str,
) -> Result<Vec<String>, String> {
    let result = mise::run_ok(state, args, fallback_error).await?;
    Ok(result
        .stdout
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(String::from)
        .collect())
}

#[tauri::command]
pub async fn list_installed_plugin_names(state: State<'_, MiseState>) -> Result<Vec<String>, String> {
    let mut names = list_trimmed_lines(
        &state,
        &["plugins", "ls", "--user"],
        "failed to run 'mise plugins ls --user'",
    )
    .await?;
    names.sort();
    Ok(names)
}

#[tauri::command]
pub async fn list_installed_user_plugin_infos(
    state: State<'_, MiseState>,
) -> Result<Vec<PluginDefinitionInfo>, String> {
    let result = mise::run_ok(
        &state,
        &["plugins", "ls", "--user", "--urls"],
        "failed to run 'mise plugins ls --user --urls'",
    )
    .await?;

    let aliases = config::read_user_tool_aliases()?;
    let mut infos: Vec<PluginDefinitionInfo> = mise::parse_plugin_info_lines(&result.stdout)
        .into_iter()
        .map(|mut info| {
            if let Some(alias_url) = aliases.get(&info.name) {
                info.url = Some(alias_url.clone());
                info.source = Some("tool_alias".to_string());
            } else {
                info.source = Some("mise_user".to_string());
            }
            info
        })
        .collect();
    infos.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(infos)
}

#[tauri::command]
pub async fn list_core_plugin_names(state: State<'_, MiseState>) -> Result<Vec<String>, String> {
    let mut names = list_trimmed_lines(
        &state,
        &["plugins", "ls", "--core"],
        "failed to run 'mise plugins ls --core'",
    )
    .await?;
    names.sort();
    Ok(names)
}

#[tauri::command]
pub async fn list_installed_tool_names(state: State<'_, MiseState>) -> Result<Vec<String>, String> {
    let result = mise::run_ok(
        &state,
        &["ls", "--installed", "--json"],
        "failed to run 'mise ls --installed --json'",
    )
    .await?;
    let parsed: serde_json::Value = serde_json::from_str(result.stdout.trim())
        .map_err(|_| "failed to parse JSON from 'mise ls --installed --json'".to_string())?;
    let entries = parsed
        .as_object()
        .ok_or_else(|| "failed to parse JSON from 'mise ls --installed --json'".to_string())?;
    let mut names: Vec<String> = entries.keys().cloned().collect();
    names.sort();
    Ok(names)
}

#[tauri::command]
pub async fn list_remote_plugin_names(state: State<'_, MiseState>) -> Result<Vec<String>, String> {
    let names = list_trimmed_lines(
        &state,
        &["plugins", "ls-remote", "--only-names"],
        "failed to run 'mise plugins ls-remote --only-names'",
    )
    .await?;
    let mut names = mise::dedupe(names);
    names.sort();
    Ok(names)
}

#[tauri::command]
pub async fn list_remote_plugin_infos(
    state: State<'_, MiseState>,
) -> Result<Vec<PluginDefinitionInfo>, String> {
    let result = mise::run_ok(
        &state,
        &["plugins", "ls-remote", "--urls"],
        "failed to run 'mise plugins ls-remote --urls'",
    )
    .await?;
    let mut infos = mise::parse_plugin_info_lines(&result.stdout);
    infos.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(infos)
}
