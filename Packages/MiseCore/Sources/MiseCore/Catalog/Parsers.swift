import Foundation

/// Pure parsers for mise output. Port of the parsing halves of mise.rs / catalog.rs.
enum Parsers {
    static func sanitizeVersion(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func dedupe(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }

    static func trimmedLines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func json(_ text: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(text.trimmingCharacters(in: .whitespacesAndNewlines).utf8))
    }

    /// `ls-remote --json` yields strings or `{version: …}` objects; plain lines are the fallback.
    static func parseRemoteVersions(_ stdout: String) -> [String] {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        if let entries = (try? json(trimmed)) as? [Any] {
            return entries.compactMap { entry in
                if let s = entry as? String { return sanitizeVersion(s) }
                if let obj = entry as? [String: Any], let v = obj["version"] as? String { return sanitizeVersion(v) }
                return nil
            }
        }
        return trimmedLines(trimmed)
    }

    /// `plugins ls --urls` rows: `name url`; a `*`-prefixed second column is a marker, not a URL.
    static func parsePluginInfoLines(_ stdout: String) -> [PluginDefinitionInfo] {
        trimmedLines(stdout).compactMap { line -> PluginDefinitionInfo? in
            let cols = line.split(whereSeparator: \.isWhitespace)
            guard let name = cols.first, !name.isEmpty else { return nil }
            let url = cols.dropFirst().first.map(String.init).flatMap { $0.hasPrefix("*") ? nil : $0 }
            return PluginDefinitionInfo(name: String(name), url: url)
        }
    }

    static func versions(fromEntry value: Any) -> [String] {
        guard let entries = value as? [Any] else { return [] }
        return entries.compactMap { (($0 as? [String: Any])?["version"] as? String).flatMap(sanitizeVersion) }
    }

    /// `ls --global --json`. Fails closed: unreadable data must never authorize a deletion.
    static func parseGlobalPlugins(_ stdout: String) throws -> [String: [String]] {
        let parsed: Any
        do { parsed = try json(stdout) } catch { throw MiseError("cannot parse global tool versions: \(error.localizedDescription)") }
        guard let entries = parsed as? [String: Any] else { throw MiseError("unexpected global tool JSON shape") }
        var result: [String: [String]] = [:]
        for (plugin, raw) in entries {
            guard let rows = raw as? [Any] else { throw MiseError("unexpected global version list") }
            if rows.contains(where: { ($0 as? [String: Any])?["version"] as? String == nil }) {
                throw MiseError("missing global tool version")
            }
            result[plugin] = versions(fromEntry: raw)
        }
        return result
    }

    /// `ls --installed --json`: tool → installed versions, newest first. Non-array values are skipped.
    static func parseInstalledPlugins(_ stdout: String) throws -> [String: [String]] {
        guard let parsed = try? json(stdout) else { throw MiseError("failed to parse JSON from 'mise ls --installed --json'") }
        guard let entries = parsed as? [String: Any] else { throw MiseError("unexpected installed tool JSON shape from mise") }
        var result: [String: [String]] = [:]
        for (plugin, raw) in entries where raw is [Any] {
            result[plugin] = dedupe(versions(fromEntry: raw)).sorted { Version.compare($0, $1) == .orderedDescending }
        }
        return result
    }

    /// `plugins ls --user --outdated`: an unreachable remote only warns on stderr, so anything on
    /// stderr other than mise's own "all up to date" line is treated as a failure.
    static func parseOutdatedPlugins(stdout: String, stderr: String) throws -> [String] {
        if stderr.split(separator: "\n").contains(where: { line in
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !t.isEmpty && t != "mise All plugins are up to date"
        }) {
            throw MiseError(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // Piped output is a headerless table: name, URL, ref, local SHA, remote SHA.
        return stdout.split(separator: "\n").compactMap { $0.split(whereSeparator: \.isWhitespace).first.map(String.init) }
    }
}
