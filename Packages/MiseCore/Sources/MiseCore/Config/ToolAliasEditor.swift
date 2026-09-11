import Foundation

/// Edits only the `[tool_alias]` section of the user's mise config.toml, line by line, so every
/// other byte (comments, ordering, other sections) survives untouched. Replaces toml_edit.
// ponytail: line-level TOML sanity check, not a parser. Rejects obviously broken input
// (unterminated headers, stray text) so a bad file is never rewritten blind.
public enum ToolAliasEditor {
    static let section = "tool_alias"

    public static func configPath(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> String {
        if let xdg = environment["XDG_CONFIG_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !xdg.isEmpty {
            return xdg + "/mise/config.toml"
        }
        guard let home = environment["HOME"] else { throw MiseError("HOME is not set; cannot find mise config path") }
        return home + "/.config/mise/config.toml"
    }

    // MARK: Pure text operations

    /// `[tool_alias]` entries with string values. Unparseable input yields an empty map.
    public static func parse(_ toml: String) -> [String: String] {
        guard let lines = try? validated(toml), let range = sectionRange(lines) else { return [:] }
        var aliases: [String: String] = [:]
        for line in lines[range] {
            if let (key, raw) = keyValue(line), let value = stringValue(raw) { aliases[key] = value }
        }
        return aliases
    }

    public static func update(_ current: String, plugin: String, gitUrl: String) throws -> String {
        var lines = try validated(current)
        let entry = "\(formatKey(plugin)) = \(quote(gitUrl))"
        guard let range = sectionRange(lines) else {
            var text = current
            if !text.isEmpty {
                if !text.hasSuffix("\n") { text += "\n" }
                text += "\n"
            }
            return text + "[\(section)]\n\(entry)\n"
        }
        if let index = lines[range].firstIndex(where: { keyValue($0)?.key == plugin }) {
            let keyText = lines[index].prefix { $0 != "=" }.trimmingCharacters(in: .whitespaces)
            lines[index] = "\(keyText) = \(quote(gitUrl))"
        } else {
            let last = lines[range].lastIndex { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? range.lowerBound
            lines.insert(entry, at: last + 1)
        }
        return lines.joined(separator: "\n")
    }

    public static func remove(_ current: String, plugin: String) throws -> String {
        var lines = try validated(current)
        guard let range = sectionRange(lines) else { return current }
        for index in range.reversed() where keyValue(lines[index])?.key == plugin {
            lines.remove(at: index)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: File operations (return the path for user-facing log lines)

    public static func readUserAliases(at path: String) throws -> [String: String] {
        parse(try readOrEmpty(path))
    }

    public static func updateUserAlias(at path: String, plugin: String, gitUrl: String) throws -> String {
        try write(try update(try readOrEmpty(path), plugin: plugin, gitUrl: gitUrl), to: path)
        return path
    }

    public static func removeUserAlias(at path: String, plugin: String) throws -> String {
        try write(try remove(try readOrEmpty(path), plugin: plugin), to: path)
        return path
    }

    static func readOrEmpty(_ path: String) throws -> String {
        guard FileManager.default.fileExists(atPath: path) else { return "" }
        do { return try String(contentsOfFile: path, encoding: .utf8) } catch { throw MiseError("failed to read \(path): \(error.localizedDescription)") }
    }

    static func write(_ content: String, to path: String) throws {
        let dir = (path as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch { throw MiseError("failed to write \(path): \(error.localizedDescription)") }
    }

    // MARK: Line helpers

    /// Splits into lines and rejects text that cannot be TOML. Multi-line values are tracked by
    /// bracket depth and triple quotes so their continuation lines pass.
    static func validated(_ toml: String) throws -> [String] {
        let lines = toml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var depth = 0
        var inMultiline = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inMultiline || depth > 0 {
                if trimmed.components(separatedBy: "\"\"\"").count % 2 == 0 { inMultiline.toggle() }
                if !inMultiline { depth += bracketDelta(line) }
                continue
            }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let code = stripComment(trimmed)
            if code.hasPrefix("[") {
                guard code.hasSuffix("]"), code.count > 2 else { throw MiseError("failed to parse mise config.toml: bad header '\(trimmed)'") }
                continue
            }
            guard keyValue(line) != nil else { throw MiseError("failed to parse mise config.toml: unexpected line '\(trimmed)'") }
            if line.components(separatedBy: "\"\"\"").count % 2 == 0 { inMultiline = true } else { depth += bracketDelta(line) }
        }
        guard depth <= 0, !inMultiline else { throw MiseError("failed to parse mise config.toml: unterminated value") }
        return lines
    }

    static func sectionRange(_ lines: [String]) -> Range<Int>? {
        guard let start = lines.firstIndex(where: { line in
            let code = stripComment(line.trimmingCharacters(in: .whitespaces))
            guard code.hasPrefix("[") && code.hasSuffix("]") && !code.hasPrefix("[[") else { return false }
            let name = code.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
            return name == section || name == "\"\(section)\"" || name == "'\(section)'"
        }) else { return nil }
        let next = lines[(start + 1)...].firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") } ?? lines.count
        return (start + 1)..<next
    }

    /// `key = value` split on the first `=` outside quotes; comments stripped from the value.
    static func keyValue(_ line: String) -> (key: String, value: String)? {
        var quote: Character?
        for (offset, ch) in line.enumerated() {
            if let q = quote { if ch == q { quote = nil }; continue }
            if ch == "\"" || ch == "'" { quote = ch; continue }
            if ch == "#" { return nil }
            if ch == "=" {
                let keyText = line.prefix(offset).trimmingCharacters(in: .whitespaces)
                let valueText = stripComment(String(line.dropFirst(offset + 1))).trimmingCharacters(in: .whitespaces)
                guard let key = stringValue(keyText) ?? (keyText.isEmpty ? nil : keyText), !valueText.isEmpty else { return nil }
                return (key, valueText)
            }
        }
        return nil
    }

    static func stripComment(_ text: String) -> String {
        var quote: Character?
        for (offset, ch) in text.enumerated() {
            if let q = quote { if ch == q { quote = nil }; continue }
            if ch == "\"" || ch == "'" { quote = ch; continue }
            if ch == "#" { return String(text.prefix(offset)).trimmingCharacters(in: .whitespaces) }
        }
        return text
    }

    static func bracketDelta(_ line: String) -> Int {
        var depth = 0
        var quote: Character?
        for ch in stripComment(line) {
            if let q = quote { if ch == q { quote = nil }; continue }
            switch ch {
            case "\"", "'": quote = ch
            case "[", "{": depth += 1
            case "]", "}": depth -= 1
            default: break
            }
        }
        return depth
    }

    /// Basic (`"…"`, with escapes) or literal (`'…'`) string; nil for anything else.
    static func stringValue(_ raw: String) -> String? {
        guard raw.count >= 2, let first = raw.first, first == raw.last, first == "\"" || first == "'" else { return nil }
        let body = raw.dropFirst().dropLast()
        if first == "'" { return String(body) }
        var out = ""
        var iterator = body.makeIterator()
        while let ch = iterator.next() {
            guard ch == "\\", let next = iterator.next() else { out.append(ch); continue }
            switch next {
            case "n": out.append("\n")
            case "t": out.append("\t")
            case "r": out.append("\r")
            default: out.append(next)
            }
        }
        return out
    }

    static func formatKey(_ key: String) -> String {
        let bare = !key.isEmpty && key.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
        return bare ? key : quote(key)
    }

    static func quote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
