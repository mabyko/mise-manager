// Port of src/bun/services/mise.ts: mise executable discovery + runner + output parsers.
// GUI apps on macOS don't inherit the shell PATH, so we augment it with known bin dirs
// instead of pulling in fix-path-env-rs (which runs the user's interactive login shell).
use std::ffi::{OsStr, OsString};
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::Mutex;

use crate::contracts::PluginDefinitionInfo;

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
/// Also carries the AppHandle so subprocess output can be streamed to the UI.
#[derive(Default)]
pub struct MiseState {
    exe: Mutex<Option<PathBuf>>,
    app: Mutex<Option<tauri::AppHandle>>,
}

impl MiseState {
    pub fn set_app_handle(&self, handle: tauri::AppHandle) {
        *self.app.lock().unwrap() = Some(handle);
    }

    pub fn app_handle(&self) -> Option<tauri::AppHandle> {
        self.app.lock().unwrap().clone()
    }

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

fn emit_output(app: &Option<tauri::AppHandle>, stream: &str, line: &str) {
    use tauri::Emitter;
    if let Some(app) = app {
        let _ = app.emit(
            "mise-output",
            serde_json::json!({ "stream": stream, "line": line }),
        );
    }
}

/// Runs a subprocess with piped output, emitting each line as a `mise-output`
/// event so the UI can show live progress instead of a fabricated percentage.
pub(crate) fn run_streaming_blocking(
    program: &Path,
    args: &[String],
    path_override: Option<&OsStr>,
    app: Option<tauri::AppHandle>,
) -> std::io::Result<MiseResult> {
    let mut command = Command::new(program);
    command
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    if let Some(path_value) = path_override {
        command.env("PATH", path_value);
    }
    let mut child = command.spawn()?;
    let stdout_pipe = child.stdout.take().expect("stdout is piped");
    let stderr_pipe = child.stderr.take().expect("stderr is piped");

    let app_for_stderr = app.clone();
    let stderr_thread = std::thread::spawn(move || {
        let mut collected = String::new();
        for line in BufReader::new(stderr_pipe).lines().map_while(Result::ok) {
            emit_output(&app_for_stderr, "stderr", &line);
            collected.push_str(&line);
            collected.push('\n');
        }
        collected
    });

    let mut stdout_collected = String::new();
    for line in BufReader::new(stdout_pipe).lines().map_while(Result::ok) {
        emit_output(&app, "stdout", &line);
        stdout_collected.push_str(&line);
        stdout_collected.push('\n');
    }

    let stderr_collected = stderr_thread.join().unwrap_or_default();
    let status = child.wait()?;
    Ok(MiseResult {
        stdout: stdout_collected,
        stderr: stderr_collected,
        exit_code: status.code().unwrap_or(-1),
    })
}

pub async fn run<S: AsRef<str>>(state: &MiseState, args: &[S]) -> Result<MiseResult, String> {
    let exe = state.executable();
    let app = state.app_handle();
    let args: Vec<String> = args.iter().map(|a| a.as_ref().to_string()).collect();
    tauri::async_runtime::spawn_blocking(move || {
        let path_value = get_augmented_path();
        run_streaming_blocking(&exe, &args, Some(path_value.as_os_str()), app).map_err(|error| {
            format!(
                "failed to spawn mise executable '{}' (PATH='{}'): {}",
                exe.display(),
                path_value.to_string_lossy(),
                error
            )
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
    items
        .into_iter()
        .filter(|item| seen.insert(item.clone()))
        .collect()
}

pub fn parse_remote_versions(stdout: &str) -> Vec<String> {
    let trimmed = stdout.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }

    if let Ok(serde_json::Value::Array(entries)) =
        serde_json::from_str::<serde_json::Value>(trimmed)
    {
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
    fn parses_plugin_info_lines_with_optional_urls() {
        let parsed =
            parse_plugin_info_lines("node https://example.com/node.git\ncore *builtin\nplain\n");
        assert_eq!(parsed.len(), 3);
        assert_eq!(
            parsed[0].url.as_deref(),
            Some("https://example.com/node.git")
        );
        assert_eq!(parsed[1].url, None);
        assert_eq!(parsed[2].url, None);
    }
}
