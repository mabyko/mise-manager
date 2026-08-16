// Port of src/shared/version.ts. The TS copy stays alive for the frontend
// (core/utils.ts, core/miseStatus.ts) — keep the two implementations in sync.
// The mirrored test cases live in src/shared/version.test.ts.
use std::cmp::Ordering;

#[derive(Debug)]
struct ParsedVersion {
    raw: String,
    parts: Vec<u64>,
    is_pre_release: bool,
}

fn parse_version(raw: &str) -> Option<ParsedVersion> {
    let trimmed = raw.trim();
    let bytes = trimmed.as_bytes();
    if bytes.first().is_none_or(|b| !b.is_ascii_digit()) {
        return None;
    }

    // Equivalent of /^(\d+(?:\.\d+)*)(.*)$/
    let mut idx = 0;
    let mut parts: Vec<u64> = Vec::new();
    loop {
        let start = idx;
        while idx < bytes.len() && bytes[idx].is_ascii_digit() {
            idx += 1;
        }
        parts.push(trimmed[start..idx].parse().unwrap_or(u64::MAX));
        if idx + 1 < bytes.len() && bytes[idx] == b'.' && bytes[idx + 1].is_ascii_digit() {
            idx += 1;
        } else {
            break;
        }
    }

    let suffix = trimmed[idx..].trim();
    Some(ParsedVersion {
        raw: trimmed.to_string(),
        parts,
        is_pre_release: is_pre_release_suffix(suffix),
    })
}

fn is_pre_release_suffix(suffix: &str) -> bool {
    if suffix.is_empty() || suffix.starts_with('+') {
        return false;
    }
    if suffix.starts_with('-') {
        return true;
    }
    // TS checks a keyword pattern OR /[a-z]/i — any ASCII letter subsumes the keywords.
    suffix.chars().any(|c| c.is_ascii_alphabetic())
}

pub fn is_pre_release_version(version: &str) -> bool {
    match parse_version(version) {
        Some(parsed) => parsed.is_pre_release,
        None => version.contains('-') || version.chars().any(|c| c.is_ascii_alphabetic()),
    }
}

pub fn is_stable_version(plugin: &str, version: &str) -> bool {
    if plugin != "python" && plugin != "ruby" {
        return true;
    }
    !is_pre_release_version(version)
}

pub fn starts_with_digit(version: &str) -> bool {
    version.as_bytes().first().is_some_and(|b| b.is_ascii_digit())
}

// Approximation of localeCompare(undefined, {numeric: true, sensitivity: "base"}):
// digit runs compare numerically, everything else case-insensitively.
fn natural_compare(a: &str, b: &str) -> Ordering {
    let mut ac = a.chars().peekable();
    let mut bc = b.chars().peekable();
    loop {
        match (ac.peek().copied(), bc.peek().copied()) {
            (None, None) => return Ordering::Equal,
            (None, Some(_)) => return Ordering::Less,
            (Some(_), None) => return Ordering::Greater,
            (Some(x), Some(y)) if x.is_ascii_digit() && y.is_ascii_digit() => {
                let mut na = String::new();
                while let Some(&c) = ac.peek().filter(|c| c.is_ascii_digit()) {
                    na.push(c);
                    ac.next();
                }
                let mut nb = String::new();
                while let Some(&c) = bc.peek().filter(|c| c.is_ascii_digit()) {
                    nb.push(c);
                    bc.next();
                }
                let na = na.trim_start_matches('0');
                let nb = nb.trim_start_matches('0');
                let ord = na.len().cmp(&nb.len()).then_with(|| na.cmp(nb));
                if ord != Ordering::Equal {
                    return ord;
                }
            }
            (Some(x), Some(y)) => {
                let xl = x.to_ascii_lowercase();
                let yl = y.to_ascii_lowercase();
                if xl != yl {
                    return xl.cmp(&yl);
                }
                ac.next();
                bc.next();
            }
        }
    }
}

pub fn compare_versions(a: &str, b: &str) -> Ordering {
    let (pa, pb) = match (parse_version(a), parse_version(b)) {
        (Some(pa), Some(pb)) => (pa, pb),
        _ => return natural_compare(a, b),
    };

    let max = pa.parts.len().max(pb.parts.len());
    for i in 0..max {
        let x = pa.parts.get(i).copied().unwrap_or(0);
        let y = pb.parts.get(i).copied().unwrap_or(0);
        if x != y {
            return x.cmp(&y);
        }
    }

    if pa.is_pre_release != pb.is_pre_release {
        return if pa.is_pre_release {
            Ordering::Less
        } else {
            Ordering::Greater
        };
    }

    natural_compare(&pa.raw, &pb.raw)
}

pub fn get_major(version: &str) -> Option<u64> {
    parse_version(version).and_then(|p| p.parts.first().copied())
}

pub fn pick_latest<'a, I>(versions: I) -> Option<String>
where
    I: IntoIterator<Item = &'a str>,
{
    // max_by keeps the last of equal elements, matching TS sort().at(-1) on a stable sort.
    versions
        .into_iter()
        .max_by(|a, b| compare_versions(a, b))
        .map(str::to_string)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compares_numeric_parts_not_lexicographically() {
        assert_eq!(compare_versions("1.2.3", "1.2.10"), Ordering::Less);
        assert_eq!(compare_versions("1.10.0", "1.9.0"), Ordering::Greater);
        assert_eq!(compare_versions("2.0.0", "2.0.0"), Ordering::Equal);
    }

    #[test]
    fn missing_parts_count_as_zero_then_raw_tiebreak() {
        // parts equal after zero-padding → natural compare of raw strings
        assert_eq!(compare_versions("1.2", "1.2.0"), Ordering::Less);
    }

    #[test]
    fn pre_release_sorts_below_release_of_same_parts() {
        assert_eq!(compare_versions("2.0.0-rc.1", "2.0.0"), Ordering::Less);
        assert_eq!(compare_versions("2.0.0", "2.0.0-rc.1"), Ordering::Greater);
    }

    #[test]
    fn pre_release_detection() {
        assert!(is_pre_release_version("3.0.0-alpha"));
        assert!(is_pre_release_version("3.13.0a1"));
        assert!(is_pre_release_version("1.0.0rc2"));
        assert!(!is_pre_release_version("1.2.3"));
        assert!(!is_pre_release_version("1.2.3+build5"));
        // unparsable fallback: any '-' or letter counts as pre-release
        assert!(is_pre_release_version("nightly-2024"));
    }

    #[test]
    fn stable_filter_only_applies_to_python_and_ruby() {
        assert!(!is_stable_version("python", "3.13.0a1"));
        assert!(is_stable_version("python", "3.12.1"));
        assert!(!is_stable_version("ruby", "3.4.0-preview1"));
        assert!(is_stable_version("node", "20.0.0-nightly"));
    }

    #[test]
    fn major_extraction() {
        assert_eq!(get_major("10.1.2"), Some(10));
        assert_eq!(get_major("1"), Some(1));
        assert_eq!(get_major("v1.2"), None);
        assert_eq!(get_major("system"), None);
    }

    #[test]
    fn pick_latest_prefers_highest() {
        let versions = ["1.9.0", "1.10.0", "1.2.0"];
        assert_eq!(pick_latest(versions), Some("1.10.0".to_string()));
        assert_eq!(pick_latest([] as [&str; 0]), None);
    }

    #[test]
    fn non_semver_fallback_uses_natural_compare() {
        assert_eq!(compare_versions("temurin-21", "temurin-8"), Ordering::Greater);
        assert_eq!(compare_versions("Temurin-8", "temurin-8"), Ordering::Equal);
    }
}
