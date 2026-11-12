/// Display parts of a mise tool name such as `node`, `http:tla2tools` or `npm:@antfu/ni`.
public enum ToolName {
    /// Backend prefix (`http`, `npm`, …); nil for registry short names.
    public static func backend(_ name: String) -> String? {
        guard let colon = name.firstIndex(of: ":"), colon != name.startIndex else { return nil }
        return String(name[..<colon])
    }

    /// The name without its backend prefix.
    public static func short(_ name: String) -> String {
        guard let colon = name.firstIndex(of: ":"), colon != name.startIndex else { return name }
        let rest = String(name[name.index(after: colon)...])
        return rest.isEmpty ? name : rest
    }

    /// Two letters for the tool's badge, taken from the last path component of the short name.
    public static func initials(_ name: String) -> String {
        let leaf = short(name).split(separator: "/").last.map(String.init) ?? name
        let letters = leaf.filter { $0.isLetter || $0.isNumber }
        return String((letters.isEmpty ? name : letters).prefix(2))
    }
}
