// Mirrors src/shared/contracts.ts. Keep field names in sync — Tauri does NOT
// rename response fields, so every struct here must carry rename_all = "camelCase".
use serde::Serialize;

#[derive(Serialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct PluginSummary {
    pub name: String,
    pub active_global_version: Option<String>,
    pub installed_versions: Vec<String>,
}

#[derive(Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct PluginUpdateInfo {
    pub plugin: String,
    pub base_version: String,
    pub same_major_latest: Option<String>,
    pub latest_by_major: std::collections::BTreeMap<String, String>,
    pub release_latest: Option<String>,
    pub overall_latest: Option<String>,
    pub checked_versions: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct UpdateResult {
    pub plugin: String,
    pub target_version: String,
    pub stdout: String,
}

#[derive(Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct PluginInstallResult {
    pub plugin: String,
    pub stdout: String,
}

#[derive(Serialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct PluginDefinitionInfo {
    pub name: String,
    pub url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source: Option<String>,
}

#[derive(Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct MiseSelfUpdateResult {
    pub before_version: Option<String>,
    pub after_version: Option<String>,
    pub stdout: String,
    pub stderr: String,
}

#[derive(Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct MiseInstallResult {
    pub success: bool,
    pub stdout: String,
    pub stderr: String,
}
