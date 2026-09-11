/// Plugin URL normalisation and default-vs-custom classification. Port of src/mainview/core/utils.ts.
public enum PluginSource {
    static let schemePrefixes = ["https://", "http://", "git@", "ssh://", "asdf:", "vfox:"]

    /// `owner/repo[.git]` shorthand becomes a GitHub URL; anything with a scheme is left alone.
    public static func normalizeInstallURL(_ value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = raw.lowercased()
        if schemePrefixes.contains(where: lower.hasPrefix) { return raw }
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 2, parts.allSatisfy({ !$0.isEmpty && !$0.contains(where: \.isWhitespace) }) {
            return "https://github.com/\(raw)"
        }
        return raw
    }

    /// Aliases (`asdf:`, `vfox:`), `.git`, trailing slashes and case all collapse to one token.
    public static func normalizeSourceToken(_ value: String) -> String {
        var raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while raw.hasSuffix("/") { raw.removeLast() }
        if raw.lowercased().hasSuffix(".git") { raw.removeLast(4) }
        for scheme in ["https://", "http://"] where raw.hasPrefix(scheme) {
            return String(raw.dropFirst(scheme.count)).lowercased()
        }
        for alias in ["asdf:", "vfox:"] where raw.hasPrefix(alias) {
            let repo = String(raw.dropFirst(alias.count))
            if repo.hasPrefix("https://") || repo.hasPrefix("http://") { return normalizeSourceToken(repo) }
            return normalizeSourceToken("https://github.com/\(repo)")
        }
        return raw.lowercased()
    }

    public static func userPluginInfo(_ plugin: String, in installed: [PluginDefinitionInfo]) -> PluginDefinitionInfo? {
        installed.first { $0.name == plugin }
    }

    public static func remoteSourceTokens(_ plugin: String, in remote: [PluginDefinitionInfo]) -> [String] {
        remote.filter { $0.name == plugin }.compactMap(\.url)
    }

    public static func isDefaultURL(_ plugin: String, gitUrl: String?, remote: [PluginDefinitionInfo]) -> Bool {
        guard let gitUrl, !gitUrl.isEmpty else { return remote.contains { $0.name == plugin && $0.url == nil } }
        let token = normalizeSourceToken(gitUrl)
        return remoteSourceTokens(plugin, in: remote).contains { normalizeSourceToken($0) == token }
    }

    public static func isCustomUserURL(_ userInfo: PluginDefinitionInfo?, remote: [PluginDefinitionInfo]) -> Bool {
        guard let userInfo else { return false }
        if userInfo.source == "tool_alias" { return true }
        guard let url = userInfo.url, !url.isEmpty else { return false }
        if remoteSourceTokens(userInfo.name, in: remote).isEmpty { return true }
        return !isDefaultURL(userInfo.name, gitUrl: url, remote: remote)
    }

    public static func isCustomUserURL(
        _ plugin: String, installed: [PluginDefinitionInfo], remote: [PluginDefinitionInfo]
    ) -> Bool {
        isCustomUserURL(userPluginInfo(plugin, in: installed), remote: remote)
    }
}
