// Port of src/bun/services/pluginActions.ts — mutating mise operations + release check.
use std::cmp::Ordering;

use tauri::State;

use crate::catalog;
use crate::config;
use crate::contracts::{
    MiseInstallResult, MiseSelfUpdateResult, PluginInstallResult, PluginUpdateInfo, UpdateResult,
};
use crate::mise::{self, MiseState};
use crate::version::{
    compare_versions, get_major, is_pre_release_version, is_stable_version, pick_latest,
    starts_with_digit,
};

pub(crate) async fn mise_version(state: &MiseState) -> Result<Option<String>, String> {
    let result = mise::run_ok(state, &["--version"], "failed to run 'mise --version'").await?;
    Ok(result
        .stdout
        .lines()
        .map(str::trim)
        .find(|line| !line.is_empty())
        .map(String::from))
}

#[tauri::command]
pub async fn get_mise_version(state: State<'_, MiseState>) -> Result<Option<String>, String> {
    mise_version(&state).await
}

async fn http_text(url: &str) -> Result<String, String> {
    let response = reqwest::Client::new()
        .get(url)
        .timeout(std::time::Duration::from_secs(20))
        .header("User-Agent", "mise-manager")
        .send()
        .await
        .map_err(|error| error.to_string())?;
    if !response.status().is_success() {
        return Err(format!(
            "{url} returned status {}",
            response.status().as_u16()
        ));
    }
    response.text().await.map_err(|error| error.to_string())
}

/// `mise` isn't in its own tool registry, so there is no CLI way to ask for the
/// latest release. https://mise.jdx.dev/VERSION is what mise's own install.sh
/// reads: plain text, no GitHub API quota. The Releases API stays as a fallback
/// but costs one of the 60 unauthenticated requests/hour shared with self-update.
#[tauri::command]
pub async fn get_latest_mise_release() -> Result<Option<String>, String> {
    let tag = match http_text("https://mise.jdx.dev/VERSION").await {
        Ok(text) => text,
        Err(version_error) => {
            let body = http_text("https://api.github.com/repos/jdx/mise/releases/latest")
                .await
                .map_err(|api_error| format!("{version_error}; {api_error}"))?;
            serde_json::from_str::<serde_json::Value>(&body)
                .map_err(|error| error.to_string())?
                .get("tag_name")
                .and_then(|value| value.as_str())
                .unwrap_or_default()
                .to_string()
        }
    };
    Ok(Some(tag.trim().to_string()).filter(|tag| !tag.is_empty()))
}

#[tauri::command]
pub async fn self_update_mise(state: State<'_, MiseState>) -> Result<MiseSelfUpdateResult, String> {
    let before_version = mise_version(&state).await.unwrap_or(None);

    let result = mise::run_ok(
        &state,
        &["self-update", "-y", "--no-plugins"],
        "mise self-update failed; package-manager installations must be updated through their package manager",
    )
    .await?;

    let after_version = match mise_version(&state).await {
        Ok(version) => version,
        Err(_) => before_version.clone(),
    };

    Ok(MiseSelfUpdateResult {
        before_version,
        after_version,
        stdout: result.stdout.trim().to_string(),
        stderr: result.stderr.trim().to_string(),
    })
}

/// Update rules for the Plugins Updater columns, separated from the mise call so
/// they are testable without a mise binary. Input is the raw `ls-remote` stdout.
pub(crate) fn plan_plugin_update(
    plugin: String,
    base_version: String,
    include_channels: bool,
    remote_stdout: &str,
) -> PluginUpdateInfo {
    let mut remote_versions: Vec<String> = mise::parse_remote_versions(remote_stdout)
        .into_iter()
        .filter(|version| include_channels || starts_with_digit(version))
        .filter(|version| is_stable_version(&plugin, version))
        .collect();
    remote_versions.sort_by(|a, b| compare_versions(a, b));

    let unique = mise::dedupe(remote_versions);
    let semver: Vec<&str> = unique
        .iter()
        .map(String::as_str)
        .filter(|v| starts_with_digit(v))
        .collect();

    let pre_release_latest =
        pick_latest(semver.iter().copied().filter(|v| is_pre_release_version(v)));
    let release_latest = pick_latest(
        semver
            .iter()
            .copied()
            .filter(|v| !is_pre_release_version(v)),
    );

    // A pre-release only counts as "overall latest" when
    // (semver base) it is newer than the base, or
    // (non-semver base) it is at least the release latest.
    let is_base_semver = starts_with_digit(&base_version);
    let overall_latest = pre_release_latest
        .as_deref()
        .filter(|pre| {
            (is_base_semver && compare_versions(pre, &base_version) == Ordering::Greater)
                || (!is_base_semver
                    && release_latest
                        .as_deref()
                        .is_some_and(|release| compare_versions(pre, release) != Ordering::Less))
        })
        .map(String::from);

    // The remote list is fetched once per tool, regardless of installed majors.
    let mut latest_by_major = std::collections::BTreeMap::new();
    for version in semver
        .iter()
        .copied()
        .filter(|v| !is_pre_release_version(v))
    {
        if let Some(major) = get_major(version) {
            latest_by_major.insert(major.to_string(), version.to_string());
        }
    }
    let same_major_latest =
        get_major(&base_version).and_then(|major| latest_by_major.get(&major.to_string()).cloned());

    PluginUpdateInfo {
        checked_versions: unique.len(),
        plugin,
        base_version,
        same_major_latest,
        latest_by_major,
        release_latest,
        overall_latest,
        error: None,
    }
}

#[tauri::command]
pub async fn check_plugin_updates(
    state: State<'_, MiseState>,
    plugin: String,
    base_version: String,
    include_channels: bool,
) -> Result<PluginUpdateInfo, String> {
    let remote = mise::run(&state, &["ls-remote", &plugin, "--json"]).await?;
    if remote.exit_code != 0 {
        let error = mise::err_or(
            &remote.stderr,
            &format!("failed to fetch remote versions for {plugin}"),
        );
        return Ok(PluginUpdateInfo {
            plugin,
            base_version,
            same_major_latest: None,
            latest_by_major: Default::default(),
            release_latest: None,
            overall_latest: None,
            checked_versions: 0,
            error: Some(error),
        });
    }

    Ok(plan_plugin_update(
        plugin,
        base_version,
        include_channels,
        &remote.stdout,
    ))
}

#[tauri::command]
pub async fn use_global_plugin(
    state: State<'_, MiseState>,
    plugin: String,
    target_version: String,
) -> Result<UpdateResult, String> {
    let spec = format!("{plugin}@{target_version}");
    let result = mise::run_ok(
        &state,
        &["use", "-g", "-y", &spec],
        &format!("failed to set global version for {spec}"),
    )
    .await?;
    Ok(UpdateResult {
        plugin,
        target_version,
        stdout: result.stdout.trim().to_string(),
    })
}

#[tauri::command]
pub async fn install_plugin(
    state: State<'_, MiseState>,
    plugin: String,
    target_version: String,
) -> Result<UpdateResult, String> {
    let spec = format!("{plugin}@{target_version}");
    let result = mise::run_ok(
        &state,
        &["install", "-y", &spec],
        &format!("failed to install {spec}"),
    )
    .await?;
    Ok(UpdateResult {
        plugin,
        target_version,
        stdout: result.stdout.trim().to_string(),
    })
}

#[tauri::command]
pub async fn delete_plugin_version(
    state: State<'_, MiseState>,
    plugin: String,
    target_version: String,
) -> Result<UpdateResult, String> {
    let global_map = catalog::list_global_plugins(&state).await?;
    if global_map
        .get(&plugin)
        .is_some_and(|versions| versions.contains(&target_version))
    {
        return Err("cannot delete active global version".to_string());
    }

    let spec = format!("{plugin}@{target_version}");
    let result = mise::run_ok(
        &state,
        &["uninstall", "-y", &spec],
        &format!("failed to uninstall {spec}"),
    )
    .await?;
    Ok(UpdateResult {
        plugin,
        target_version,
        stdout: result.stdout.trim().to_string(),
    })
}

fn append_log_line(stdout: String, extra: String) -> String {
    if stdout.is_empty() {
        extra
    } else {
        format!("{stdout}\n{extra}")
    }
}

#[tauri::command]
pub async fn update_plugin_definition(
    state: State<'_, MiseState>,
    plugin: String,
) -> Result<PluginInstallResult, String> {
    // Empty input to `plugins update` means ALL plugins; require one installed name.
    if plugin.is_empty() || plugin.starts_with('-') || plugin.contains('#') {
        return Err("invalid plugin name".to_string());
    }
    let installed = mise::run_ok(
        &state,
        &["plugins", "ls", "--user"],
        "cannot read installed plugins",
    )
    .await?;
    if !installed.stdout.lines().any(|line| line.trim() == plugin) {
        return Err(
            "only installed external plugins can be updated; update mise for core plugins"
                .to_string(),
        );
    }
    let result = mise::run_ok(
        &state,
        &["plugins", "update", &plugin],
        "plugin update failed",
    )
    .await?;
    Ok(PluginInstallResult {
        plugin,
        stdout: result.stdout.trim().to_string(),
    })
}

#[tauri::command]
pub async fn install_plugin_definition(
    state: State<'_, MiseState>,
    plugin: String,
    git_url: Option<String>,
    force: Option<bool>,
    remove_tool_alias: Option<bool>,
) -> Result<PluginInstallResult, String> {
    let mut args: Vec<String> = vec!["plugins".into(), "install".into(), "-y".into()];
    if force.unwrap_or(false) {
        args.push("--force".into());
    }
    args.push(plugin.clone());
    let trimmed_git_url = git_url
        .as_deref()
        .map(str::trim)
        .filter(|url| !url.is_empty())
        .map(String::from);
    if let Some(url) = &trimmed_git_url {
        args.push(url.clone());
    }

    let result = mise::run_ok(
        &state,
        &args,
        &format!("failed to install plugin '{plugin}'"),
    )
    .await?;

    let stdout = result.stdout.trim().to_string();
    if let Some(url) = &trimmed_git_url {
        let config_path = config::update_user_tool_alias(&plugin, url)?;
        return Ok(PluginInstallResult {
            plugin,
            stdout: append_log_line(stdout, format!("Updated tool_alias in {config_path}.")),
        });
    }

    if remove_tool_alias.unwrap_or(false) {
        let config_path = config::remove_user_tool_alias(&plugin)?;
        return Ok(PluginInstallResult {
            plugin,
            stdout: append_log_line(stdout, format!("Removed tool_alias from {config_path}.")),
        });
    }

    Ok(PluginInstallResult { plugin, stdout })
}

#[tauri::command]
pub async fn uninstall_plugin_definition(
    state: State<'_, MiseState>,
    plugin: String,
) -> Result<PluginInstallResult, String> {
    let result = mise::run_ok(
        &state,
        &["plugins", "uninstall", "-y", &plugin],
        &format!("failed to uninstall plugin '{plugin}'"),
    )
    .await?;
    Ok(PluginInstallResult {
        plugin,
        stdout: result.stdout.trim().to_string(),
    })
}

#[tauri::command]
pub async fn check_mise_installed(state: State<'_, MiseState>) -> Result<bool, String> {
    Ok(mise_version(&state).await.is_ok())
}

// Runs with the plain process env on purpose: these are the "mise isn't installed
// yet" paths, so the augmented-PATH machinery in mise::run doesn't apply.
// Output still streams to the UI via the shared mise-output event.
async fn run_shell_command(
    state: &MiseState,
    program: &str,
    args: &[&str],
) -> Result<MiseInstallResult, String> {
    let app = state.app_handle();
    let program = std::path::PathBuf::from(program);
    let args: Vec<String> = args.iter().map(|a| a.to_string()).collect();
    tauri::async_runtime::spawn_blocking(move || {
        let result = mise::run_streaming_blocking(&program, &args, None, app)
            .map_err(|error| error.to_string())?;
        Ok(MiseInstallResult {
            success: result.exit_code == 0,
            stdout: result.stdout.trim().to_string(),
            stderr: result.stderr.trim().to_string(),
        })
    })
    .await
    .map_err(|error| error.to_string())?
}

#[tauri::command]
pub async fn install_mise_sh(state: State<'_, MiseState>) -> Result<MiseInstallResult, String> {
    run_shell_command(&state, "sh", &["-c", "curl https://mise.run | sh"]).await
}

#[tauri::command]
pub async fn install_mise_brew(state: State<'_, MiseState>) -> Result<MiseInstallResult, String> {
    run_shell_command(&state, "brew", &["install", "mise"]).await
}

#[tauri::command]
pub fn get_platform() -> String {
    // The frontend compares Node-style values (features/mise.ts: "darwin"/"win32").
    match std::env::consts::OS {
        "macos" => "darwin",
        "windows" => "win32",
        other => other,
    }
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn plan(plugin: &str, base: &str, include_channels: bool, stdout: &str) -> PluginUpdateInfo {
        plan_plugin_update(
            plugin.to_string(),
            base.to_string(),
            include_channels,
            stdout,
        )
    }

    #[test]
    fn computes_same_major_release_and_pre_release_columns() {
        let info = plan(
            "node",
            "20.1.0",
            false,
            "20.2.0\n21.0.0\n22.0.0-rc1\nlts\n20.1.0",
        );
        // "lts" is dropped without include_channels; 22.0.0-rc1 > base so it surfaces.
        assert_eq!(info.same_major_latest.as_deref(), Some("20.2.0"));
        assert_eq!(info.release_latest.as_deref(), Some("21.0.0"));
        assert_eq!(info.overall_latest.as_deref(), Some("22.0.0-rc1"));
        assert_eq!(info.checked_versions, 4);
        assert!(info.error.is_none());
    }

    #[test]
    fn python_pre_releases_are_filtered_out_entirely() {
        let info = plan("python", "3.12.0", false, "3.13.0a1\n3.12.1\n3.13.0");
        assert_eq!(info.release_latest.as_deref(), Some("3.13.0"));
        assert_eq!(info.overall_latest, None);
        assert_eq!(info.checked_versions, 2);
    }

    #[test]
    fn pre_release_not_newer_than_semver_base_stays_hidden() {
        let info = plan("node", "22.0.0", false, "21.0.0\n22.0.0-rc1\n22.0.0");
        assert_eq!(info.release_latest.as_deref(), Some("22.0.0"));
        assert_eq!(info.overall_latest, None);
    }

    #[test]
    fn non_semver_base_requires_pre_release_at_least_release_latest() {
        let info = plan("java", "system", true, "17.0.0\n18-ea\n17.0.1");
        assert_eq!(info.release_latest.as_deref(), Some("17.0.1"));
        assert_eq!(info.overall_latest.as_deref(), Some("18-ea"));
        assert_eq!(info.same_major_latest, None);
    }

    #[test]
    fn accepts_json_remote_listings() {
        let info = plan("node", "1.0.0", false, r#"["1.0.0", {"version": "1.1.0"}]"#);
        assert_eq!(info.release_latest.as_deref(), Some("1.1.0"));
        assert_eq!(info.checked_versions, 2);
    }

    #[test]
    fn tracks_each_major_without_promoting_prereleases() {
        let info = plan(
            "node",
            "26.0.0",
            false,
            r#"["24.20.0","26.0.0","24.21.0","26.1.0","24.22.0-rc.1","27.0.0-rc.1"]"#,
        );
        assert_eq!(
            info.latest_by_major.get("24").map(String::as_str),
            Some("24.21.0")
        );
        assert_eq!(
            info.latest_by_major.get("26").map(String::as_str),
            Some("26.1.0")
        );
        assert!(!info.latest_by_major.contains_key("27"));
        assert_eq!(info.same_major_latest.as_deref(), Some("26.1.0"));
        assert_eq!(info.release_latest.as_deref(), Some("26.1.0"));
    }
}
