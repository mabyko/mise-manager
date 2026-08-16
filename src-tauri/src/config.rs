// Port of src/bun/services/miseConfig.ts — edits the [tool_alias] section of the
// user-owned mise config.toml. toml_edit preserves comments, formatting, and every
// unrelated section; that guarantee is why the serde-based `toml` crate is off-limits.
// Unlike the TS line parser, a config that fails to parse as TOML aborts the edit
// instead of being rewritten blind.
use std::collections::HashMap;
use std::path::{Path, PathBuf};

use toml_edit::{DocumentMut, Item, Table};

const TOOL_ALIAS_SECTION: &str = "tool_alias";

pub fn get_mise_config_path() -> Result<PathBuf, String> {
    if let Ok(xdg_config_home) = std::env::var("XDG_CONFIG_HOME") {
        let trimmed = xdg_config_home.trim();
        if !trimmed.is_empty() {
            return Ok(Path::new(trimmed).join("mise").join("config.toml"));
        }
    }

    let home = std::env::var("HOME")
        .map_err(|_| "HOME is not set; cannot find mise config path".to_string())?;
    Ok(Path::new(&home).join(".config").join("mise").join("config.toml"))
}

pub fn parse_tool_alias_toml(toml: &str) -> HashMap<String, String> {
    let Ok(doc) = toml.parse::<DocumentMut>() else {
        return HashMap::new();
    };
    let mut aliases = HashMap::new();
    if let Some(table) = doc.get(TOOL_ALIAS_SECTION).and_then(Item::as_table) {
        for (key, value) in table.iter() {
            if let Some(s) = value.as_str() {
                aliases.insert(key.to_string(), s.to_string());
            }
        }
    }
    aliases
}

pub fn update_tool_alias_toml(current: &str, plugin: &str, git_url: &str) -> Result<String, String> {
    let mut doc: DocumentMut = current
        .parse()
        .map_err(|error| format!("failed to parse mise config.toml: {error}"))?;
    let item = doc
        .entry(TOOL_ALIAS_SECTION)
        .or_insert(Item::Table(Table::new()));
    let table = item
        .as_table_mut()
        .ok_or_else(|| format!("[{TOOL_ALIAS_SECTION}] in mise config.toml is not a table"))?;
    table.insert(plugin, toml_edit::value(git_url));
    Ok(doc.to_string())
}

pub fn remove_tool_alias_toml(current: &str, plugin: &str) -> Result<String, String> {
    let mut doc: DocumentMut = current
        .parse()
        .map_err(|error| format!("failed to parse mise config.toml: {error}"))?;
    if let Some(table) = doc.get_mut(TOOL_ALIAS_SECTION).and_then(Item::as_table_mut) {
        table.remove(plugin);
    }
    Ok(doc.to_string())
}

fn read_config_or_empty(path: &Path) -> Result<String, String> {
    match std::fs::read_to_string(path) {
        Ok(content) => Ok(content),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(String::new()),
        Err(error) => Err(format!("failed to read {}: {error}", path.display())),
    }
}

pub fn read_user_tool_aliases() -> Result<HashMap<String, String>, String> {
    let path = get_mise_config_path()?;
    Ok(parse_tool_alias_toml(&read_config_or_empty(&path)?))
}

fn write_config(path: &Path, content: &str) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|error| format!("failed to create {}: {error}", parent.display()))?;
    }
    std::fs::write(path, content).map_err(|error| format!("failed to write {}: {error}", path.display()))
}

/// Returns the config path (used in user-facing log lines).
pub fn update_user_tool_alias(plugin: &str, git_url: &str) -> Result<String, String> {
    let path = get_mise_config_path()?;
    let next = update_tool_alias_toml(&read_config_or_empty(&path)?, plugin, git_url)?;
    write_config(&path, &next)?;
    Ok(path.display().to_string())
}

/// Returns the config path (used in user-facing log lines).
pub fn remove_user_tool_alias(plugin: &str) -> Result<String, String> {
    let path = get_mise_config_path()?;
    let next = remove_tool_alias_toml(&read_config_or_empty(&path)?, plugin)?;
    write_config(&path, &next)?;
    Ok(path.display().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = "# my mise config\n[tools]\nnode = \"22\" # pinned\n\n[tool_alias]\n\"node\" = \"https://old.example/node.git\"\n";

    #[test]
    fn parses_quoted_and_bare_keys() {
        let aliases = parse_tool_alias_toml(SAMPLE);
        assert_eq!(aliases.get("node").map(String::as_str), Some("https://old.example/node.git"));
        assert!(parse_tool_alias_toml("").is_empty());
        assert!(parse_tool_alias_toml("not toml [").is_empty());
    }

    #[test]
    fn update_replaces_existing_alias_and_preserves_everything_else() {
        let next = update_tool_alias_toml(SAMPLE, "node", "https://new.example/node.git").unwrap();
        assert_eq!(
            parse_tool_alias_toml(&next).get("node").map(String::as_str),
            Some("https://new.example/node.git")
        );
        assert!(next.contains("# my mise config"));
        assert!(next.contains("node = \"22\" # pinned"));
        assert!(!next.contains("old.example"));
    }

    #[test]
    fn update_creates_section_when_missing() {
        let next = update_tool_alias_toml("", "python", "https://example/py.git").unwrap();
        assert!(next.contains("[tool_alias]"));
        assert_eq!(
            parse_tool_alias_toml(&next).get("python").map(String::as_str),
            Some("https://example/py.git")
        );

        let with_other = update_tool_alias_toml("[tools]\nnode = \"22\"\n", "python", "https://example/py.git").unwrap();
        assert!(with_other.contains("[tools]"));
        assert!(parse_tool_alias_toml(&with_other).contains_key("python"));
    }

    #[test]
    fn remove_deletes_only_the_target_alias() {
        let two = update_tool_alias_toml(SAMPLE, "python", "https://example/py.git").unwrap();
        let next = remove_tool_alias_toml(&two, "node").unwrap();
        let aliases = parse_tool_alias_toml(&next);
        assert!(!aliases.contains_key("node"));
        assert!(aliases.contains_key("python"));
        assert!(next.contains("# my mise config"));
    }

    #[test]
    fn remove_without_section_is_a_no_op() {
        let input = "[tools]\nnode = \"22\"\n";
        assert_eq!(remove_tool_alias_toml(input, "node").unwrap(), input);
    }

    #[test]
    fn update_refuses_to_clobber_invalid_toml() {
        assert!(update_tool_alias_toml("not toml [", "node", "url").is_err());
    }
}
