// Port of src/bun/services/mise.ts: mise executable discovery + runner + output parsers.
// GUI apps on macOS don't inherit the shell PATH, so we augment it with known bin dirs
// instead of pulling in fix-path-env-rs (which runs the user's interactive login shell).
use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Mutex;

use crate::contracts::PluginDefinitionInfo;
use crate::version::{pick_latest, starts_with_digit};

const FALLBACK_BIN_DIRS: &[&str] = &[
    ".local/bin",
    ".mise/bin",
    "bin",
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/usr/bin",
    "/bin",
];

pub struct MiseResult {
    pub stdout: String,
    pub stderr: String,
    pub exit_code: i32,
}

fn expand_home_dir(path_value: &str) -> PathBuf {
    if let (Ok(home), Some(rest)) = (std::env::var("HOME"), path_value.strip_prefix("~/")) {
        return Path::new(&home).join(rest);
    }
    PathBuf::from(path_value)
}

pub fn get_augmented_path() -> OsString {
    let mut dirs: Vec<PathBuf> = Vec::new();
    if let Some(current) = std::env::var_os("PATH") {
        for dir in std::env::split_paths(&current) {
            if !dir.as_os_str().is_empty() && !dirs.contains(&dir) {
                dirs.push(dir);
            }
        }
    }

    let home = std::env::var("HOME").ok();
    for dir in FALLBACK_BIN_DIRS {
        let resolved = if dir.starts_with('/') {
            PathBuf::from(dir)
        } else if let Some(home) = &home {
            Path::new(home).join(dir)
        } else {
            PathBuf::from(dir)
        };
        if !dirs.contains(&resolved) {
            dirs.push(resolved);
        }
    }

    std::env::join_paths(dirs).unwrap_or_default()
}

fn resolve_mise_executable() -> PathBuf {
    if let Ok(env_bin) = std::env::var("MISE_BIN") {
        let trimmed = env_bin.trim();
        if !trimmed.is_empty() {
            return expand_home_dir(trimmed);
        }
    }

    for dir in std::env::split_paths(&get_augmented_path()) {
        if dir.as_os_str().is_empty() {
            continue;
        }
        let candidate = dir.join("mise");
        if candidate.exists() {
            return candidate;
        }
    }

    PathBuf::from("mise")
}

/// Resolved mise path, cached after the first successful discovery.
/// Re-resolves while mise is missing so an in-app install is picked up immediately.
#[derive(Default)]
pub struct MiseState {
    exe: Mutex<Option<PathBuf>>,
}

impl MiseState {
    pub fn executable(&self) -> PathBuf {
        let mut cached = self.exe.lock().unwrap();
        if let Some(path) = cached.as_ref() {
            if path.exists() {
                return path.clone();
            }
        }
        let resolved = resolve_mise_executable();
        if resolved.is_absolute() && resolved.exists() {
            *cached = Some(resolved.clone());
        }
        resolved
    }
}

pub async fn run<S: AsRef<str>>(state: &MiseState, args: &[S]) -> Result<MiseResult, String> {
    let exe = state.executable();
    let args: Vec<String> = args.iter().map(|a| a.as_ref().to_string()).collect();
    tauri::async_runtime::spawn_blocking(move || {
        let path_value = get_augmented_path();
        let output = Command::new(&exe)
            .args(&args)
            .env("PATH", &path_value)
            .output()
            .map_err(|error| {
                format!(
                    "failed to spawn mise executable '{}' (PATH='{}'): {}",
                    exe.display(),
                    path_value.to_string_lossy(),
                    error
                )
            })?;
        Ok(MiseResult {
            stdout: String::from_utf8_lossy(&output.stdout).into_owned(),
            stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
            exit_code: output.status.code().unwrap_or(-1),
        })
    })
    .await
    .map_err(|error| error.to_string())?
}

/// run + non-zero-exit handling folded together: the caller only ever sees a
/// successful MiseResult or a user-facing error string.
pub async fn run_ok<S: AsRef<str>>(
    state: &MiseState,
    args: &[S],
    fallback_error: &str,
) -> Result<MiseResult, String> {
    let result = run(state, args).await?;
    if result.exit_code != 0 {
        return Err(err_or(&result.stderr, fallback_error));
    }
    Ok(result)
}

pub fn err_or(stderr: &str, fallback: &str) -> String {
    let trimmed = stderr.trim();
    if trimmed.is_empty() {
        fallback.to_string()
    } else {
        trimmed.to_string()
    }
}

pub fn sanitize_version_str(input: &str) -> Option<String> {
    let trimmed = input.trim();
    (!trimmed.is_empty()).then(|| trimmed.to_string())
}

pub fn dedupe(items: Vec<String>) -> Vec<String> {
    let mut seen = std::collections::HashSet::new();
    items.into_iter().filter(|item| seen.insert(item.clone())).collect()
}

pub fn parse_remote_versions(stdout: &str) -> Vec<String> {
    let trimmed = stdout.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }

    if let Ok(serde_json::Value::Array(entries)) = serde_json::from_str::<serde_json::Value>(trimmed) {
        return entries
            .iter()
            .filter_map(|entry| match entry {
                serde_json::Value::String(s) => sanitize_version_str(s),
                serde_json::Value::Object(obj) => obj
                    .get("version")
                    .and_then(|v| v.as_str())
                    .and_then(sanitize_version_str),
                _ => None,
            })
            .collect();
    }

    trimmed
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(String::from)
        .collect()
}

pub fn pick_preferred_version(versions: &[String]) -> Option<String> {
    if versions.is_empty() {
        return None;
    }
    let semver: Vec<&str> = versions
        .iter()
        .map(String::as_str)
        .filter(|v| starts_with_digit(v))
        .collect();
    if semver.is_empty() {
        pick_latest(versions.iter().map(String::as_str))
    } else {
        pick_latest(semver)
    }
}

pub fn parse_plugin_info_lines(stdout: &str) -> Vec<PluginDefinitionInfo> {
    stdout
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .filter_map(|line| {
            let mut cols = line.split_whitespace();
            let name = cols.next().unwrap_or("").to_string();
            if name.is_empty() {
                return None;
            }
            let url = cols
                .next()
                .filter(|col| !col.starts_with('*'))
                .map(String::from);
            Some(PluginDefinitionInfo {
                name,
                url,
                source: None,
            })
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_remote_versions_from_json_strings_and_objects() {
        assert_eq!(
            parse_remote_versions(r#"["1.0.0", {"version": "1.1.0"}, {"other": 1}, 42]"#),
            vec!["1.0.0".to_string(), "1.1.0".to_string()]
        );
    }

    #[test]
    fn falls_back_to_plain_text_lines() {
        assert_eq!(
            parse_remote_versions("1.0.0\n  1.1.0  \n\n"),
            vec!["1.0.0".to_string(), "1.1.0".to_string()]
        );
        assert!(parse_remote_versions("   ").is_empty());
    }

    #[test]
    fn preferred_version_prefers_semver_candidates() {
        let versions = vec!["system".to_string(), "1.2.3".to_string(), "1.10.0".to_string()];
        assert_eq!(pick_preferred_version(&versions), Some("1.10.0".to_string()));
        let non_semver = vec!["system".to_string(), "latest".to_string()];
        assert_eq!(pick_preferred_version(&non_semver), Some("system".to_string()));
    }

    #[test]
    fn parses_plugin_info_lines_with_optional_urls() {
        let parsed = parse_plugin_info_lines("node https://example.com/node.git\ncore *builtin\nplain\n");
        assert_eq!(parsed.len(), 3);
        assert_eq!(parsed[0].url.as_deref(), Some("https://example.com/node.git"));
        assert_eq!(parsed[1].url, None);
        assert_eq!(parsed[2].url, None);
    }
}
