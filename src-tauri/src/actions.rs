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
    let result = mise::run(state, &["--version"]).await?;
    if result.exit_code != 0 {
        return Err(mise::err_or(&result.stderr, "failed to run 'mise --version'"));
    }
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

#[tauri::command]
pub async fn get_latest_mise_release() -> Result<Option<String>, String> {
    let response = reqwest::Client::new()
        .get("https://api.github.com/repos/jdx/mise/releases/latest")
        .header("User-Agent", "mise-manager")
        .header("Accept", "application/vnd.github+json")
        .send()
        .await
        .map_err(|error| error.to_string())?;
    if !response.status().is_success() {
        return Err(format!(
            "failed to fetch latest mise release (status={})",
            response.status().as_u16()
        ));
    }
    let parsed: serde_json::Value = response.json().await.map_err(|error| error.to_string())?;
    Ok(parsed
        .get("tag_name")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|tag| !tag.is_empty())
        .map(String::from))
}

#[tauri::command]
pub async fn self_update_mise(state: State<'_, MiseState>) -> Result<MiseSelfUpdateResult, String> {
    let before_version = mise_version(&state).await.unwrap_or(None);

    let result = mise::run(&state, &["self-update", "-y"]).await?;
    if result.exit_code != 0 {
        return Err(mise::err_or(&result.stderr, "failed to run 'mise self-update -y'"));
    }

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
            release_latest: None,
            overall_latest: None,
            checked_versions: 0,
            error: Some(error),
        });
    }

    let mut remote_versions: Vec<String> = mise::parse_remote_versions(&remote.stdout)
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

    let pre_release_latest = pick_latest(
        semver
            .iter()
            .copied()
            .filter(|v| is_pre_release_version(v)),
    );
    let release_latest = pick_latest(
        semver
            .iter()
            .copied()
            .filter(|v| !is_pre_release_version(v)),
    );

    // PRD rules: pre-release only counts as "overall latest" when
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

    let same_major_latest = get_major(&base_version).and_then(|major| {
        pick_latest(
            semver
                .iter()
                .copied()
                .filter(|v| get_major(v) == Some(major)),
        )
    });

    Ok(PluginUpdateInfo {
        checked_versions: unique.len(),
        plugin,
        base_version,
        same_major_latest,
        release_latest,
        overall_latest,
        error: None,
    })
}

#[tauri::command]
pub async fn use_global_plugin(
    state: State<'_, MiseState>,
    plugin: String,
    target_version: String,
) -> Result<UpdateResult, String> {
    let spec = format!("{plugin}@{target_version}");
    let result = mise::run(&state, &["use", "-g", "-y", &spec]).await?;
    if result.exit_code != 0 {
        return Err(mise::err_or(
            &result.stderr,
            &format!("failed to set global version for {spec}"),
        ));
    }
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
    let result = mise::run(&state, &["install", "-y", &spec]).await?;
    if result.exit_code != 0 {
        return Err(mise::err_or(&result.stderr, &format!("failed to install {spec}")));
    }
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
    let global_map = catalog::list_global_plugins(&state).await;
    if global_map.get(&plugin).map(String::as_str) == Some(target_version.as_str()) {
        return Err("cannot delete active global version".to_string());
    }

    let spec = format!("{plugin}@{target_version}");
    let result = mise::run(&state, &["uninstall", "-y", &spec]).await?;
    if result.exit_code != 0 {
        return Err(mise::err_or(&result.stderr, &format!("failed to uninstall {spec}")));
    }
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

    let result = mise::run(&state, &args).await?;
    if result.exit_code != 0 {
        return Err(mise::err_or(&result.stderr, &format!("failed to install plugin '{plugin}'")));
    }

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
    let result = mise::run(&state, &["plugins", "uninstall", "-y", &plugin]).await?;
    if result.exit_code != 0 {
        return Err(mise::err_or(&result.stderr, &format!("failed to uninstall plugin '{plugin}'")));
    }
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
async fn run_shell_command(program: &str, args: &[&str]) -> Result<MiseInstallResult, String> {
    let program = program.to_string();
    let args: Vec<String> = args.iter().map(|a| a.to_string()).collect();
    tauri::async_runtime::spawn_blocking(move || {
        let output = std::process::Command::new(&program)
            .args(&args)
            .output()
            .map_err(|error| error.to_string())?;
        Ok(MiseInstallResult {
            success: output.status.success(),
            stdout: String::from_utf8_lossy(&output.stdout).trim().to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        })
    })
    .await
    .map_err(|error| error.to_string())?
}

#[tauri::command]
pub async fn install_mise_sh() -> Result<MiseInstallResult, String> {
    run_shell_command("sh", &["-c", "curl https://mise.run | sh"]).await
}

#[tauri::command]
pub async fn install_mise_brew() -> Result<MiseInstallResult, String> {
    run_shell_command("brew", &["install", "mise"]).await
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
