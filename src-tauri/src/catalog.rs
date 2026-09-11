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
/// Fail closed: an unreadable global config must never authorize deletion.
pub async fn list_global_plugins(
    state: &MiseState,
) -> Result<HashMap<String, Vec<String>>, String> {
    let result = mise::run_ok(
        state,
        &["ls", "--global", "--json"],
        "cannot read global tool versions",
    )
    .await?;
    parse_global_plugins(&result.stdout)
}

fn parse_global_plugins(stdout: &str) -> Result<HashMap<String, Vec<String>>, String> {
    let parsed: serde_json::Value = serde_json::from_str(stdout.trim())
        .map_err(|error| format!("cannot parse global tool versions: {error}"))?;
    let entries = parsed
        .as_object()
        .ok_or("unexpected global tool JSON shape")?;
    entries
        .iter()
        .map(|(plugin, raw)| {
            let rows = raw.as_array().ok_or("unexpected global version list")?;
            if rows
                .iter()
                .any(|row| row.get("version").and_then(|v| v.as_str()).is_none())
            {
                return Err("missing global tool version".to_string());
            }
            Ok((plugin.clone(), versions_from_entry(raw)))
        })
        .collect()
}

#[tauri::command]
pub async fn list_installed_plugins(
    state: State<'_, MiseState>,
) -> Result<Vec<PluginSummary>, String> {
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

    let global_map = list_global_plugins(&state).await?;
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
            active_global_version: global_map
                .get(plugin)
                .and_then(|versions| versions.first().cloned()),
            installed_versions: installed,
        });
        touched.insert(plugin.clone());
    }

    for (plugin, versions) in &global_map {
        if touched.contains(plugin) || versions.is_empty() {
            continue;
        }
        summaries.push(PluginSummary {
            name: plugin.clone(),
            active_global_version: versions.first().cloned(),
            installed_versions: vec![],
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
pub async fn list_outdated_plugin_definitions(
    state: State<'_, MiseState>,
) -> Result<Vec<String>, String> {
    let result = mise::run_ok(
        &state,
        &["plugins", "ls", "--user", "--outdated"],
        "cannot check plugin updates; this mise version may not support --outdated",
    )
    .await?;
    parse_outdated_plugins(&result.stdout, &result.stderr)
}

fn parse_outdated_plugins(stdout: &str, stderr: &str) -> Result<Vec<String>, String> {
    // An unreachable remote only emits a warning in mise. Its normal "all up
    // to date" message is also on stderr; allow that message, not warnings.
    if stderr
        .lines()
        .any(|line| !line.trim().is_empty() && line.trim() != "mise All plugins are up to date")
    {
        return Err(stderr.trim().to_string());
    }
    // Piped mise output is a headerless table: name, URL, ref, local SHA, remote SHA.
    Ok(stdout
        .lines()
        .filter_map(|line| line.split_whitespace().next())
        .map(String::from)
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plugin_check_parses_tables_but_does_not_hide_remote_failures() {
        assert_eq!(
            parse_outdated_plugins(
                "node https://example.com/node main abc def\npython url main 123 456\n",
                ""
            )
            .unwrap(),
            ["node", "python"]
        );
        assert!(
            parse_outdated_plugins("", "mise All plugins are up to date\n")
                .unwrap()
                .is_empty()
        );
        assert!(parse_outdated_plugins(
            "",
            "mise WARN plugin: remote unavailable\nmise All plugins are up to date\n"
        )
        .is_err());
    }

    #[test]
    fn global_versions_preserve_every_selection_and_reject_unreadable_data() {
        let globals =
            parse_global_plugins(r#"{"node":[{"version":"26.0.0"},{"version":"24.20.0"}]}"#)
                .unwrap();
        assert_eq!(globals["node"], ["26.0.0", "24.20.0"]);
        for invalid in ["invalid", "[]", r#"{"node":{}}"#, r#"{"node":[{}]}"#] {
            assert!(parse_global_plugins(invalid).is_err());
        }
        assert!(parse_global_plugins("{}").unwrap().is_empty());
    }
}

#[tauri::command]
pub async fn list_installed_plugin_names(
    state: State<'_, MiseState>,
) -> Result<Vec<String>, String> {
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
