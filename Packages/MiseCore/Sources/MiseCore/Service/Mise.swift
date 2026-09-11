import Foundation

/// The 20 mise operations the UI calls (was 20 `tauri::command`s). Pure parsing lives in
/// `Parsers`; this type only sequences subprocess calls. Inject a fake `CommandRunner` in tests.
public struct Mise: Sendable {
    public let runner: any CommandRunner
    /// mise config.toml to edit for tool_alias; nil resolves the user's real one.
    public let configPath: String?

    public init(runner: any CommandRunner, configPath: String? = nil) {
        self.runner = runner
        self.configPath = configPath
    }

    func aliasPath() throws -> String { try configPath ?? ToolAliasEditor.configPath() }

    static func errOr(_ stderr: String, _ fallback: String) -> String {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// Non-zero exit becomes a user-facing error (stderr, or the fallback when stderr is empty).
    func runOK(_ args: [String], fallback: String) async throws -> CommandResult {
        let result = try await runner.runMise(args)
        guard result.exitCode == 0 else { throw MiseError(Self.errOr(result.stderr, fallback)) }
        return result
    }

    func lines(_ args: [String], fallback: String) async throws -> [String] {
        Parsers.trimmedLines(try await runOK(args, fallback: fallback).stdout)
    }

    // MARK: mise itself

    public func version() async throws -> String? {
        try await lines(["--version"], fallback: "failed to run 'mise --version'").first
    }

    public func isInstalled() async -> Bool {
        (try? await version()) != nil
    }

    public func selfUpdate() async throws -> MiseSelfUpdateResult {
        let before = (try? await version()) ?? nil
        let result = try await runOK(
            ["self-update", "-y", "--no-plugins"],
            fallback: "mise self-update failed; package-manager installations must be updated through their package manager"
        )
        let after = (try? await version()) ?? before
        return MiseSelfUpdateResult(
            beforeVersion: before, afterVersion: after,
            stdout: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func installMise(_ program: String, _ args: [String]) async throws -> MiseInstallResult {
        let result = try await runner.runShell(program, args)
        return MiseInstallResult(
            success: result.exitCode == 0,
            stdout: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    public func installViaSh() async throws -> MiseInstallResult {
        try await installMise("sh", ["-c", "curl https://mise.run | sh"])
    }

    public func installViaBrew() async throws -> MiseInstallResult {
        try await installMise("brew", ["install", "mise"])
    }

    // MARK: Tool versions

    /// Not exposed to the UI directly; guards deletion and fills active versions.
    func globalPlugins() async throws -> [String: [String]] {
        try Parsers.parseGlobalPlugins(
            try await runOK(["ls", "--global", "--json"], fallback: "cannot read global tool versions").stdout)
    }

    public func installedPlugins() async throws -> [PluginSummary] {
        let installed = try Parsers.parseInstalledPlugins(
            try await runOK(["ls", "--installed", "--json"], fallback: "failed to run 'mise ls --installed --json'").stdout)
        let globals = try await globalPlugins()
        var summaries = installed.compactMap { plugin, versions -> PluginSummary? in
            versions.isEmpty ? nil
                : PluginSummary(name: plugin, activeGlobalVersion: globals[plugin]?.first, installedVersions: versions)
        }
        for (plugin, versions) in globals where installed[plugin]?.isEmpty != false && !versions.isEmpty {
            summaries.append(PluginSummary(name: plugin, activeGlobalVersion: versions.first, installedVersions: []))
        }
        return summaries.sorted { $0.name < $1.name }
    }

    public func checkPluginUpdates(plugin: String, baseVersion: String, includeChannels: Bool) async throws -> PluginUpdateInfo {
        let remote = try await runner.runMise(["ls-remote", plugin, "--json"])
        guard remote.exitCode == 0 else {
            return PluginUpdateInfo(
                plugin: plugin, baseVersion: baseVersion,
                error: Self.errOr(remote.stderr, "failed to fetch remote versions for \(plugin)"))
        }
        return UpdatePlanner.plan(plugin: plugin, baseVersion: baseVersion, includeChannels: includeChannels, remoteStdout: remote.stdout)
    }

    func toolCommand(_ args: [String], plugin: String, version: String, fallback: String) async throws -> UpdateResult {
        let result = try await runOK(args, fallback: fallback)
        return UpdateResult(plugin: plugin, targetVersion: version, stdout: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public func useGlobal(plugin: String, version: String) async throws -> UpdateResult {
        let spec = "\(plugin)@\(version)"
        return try await toolCommand(["use", "-g", "-y", spec], plugin: plugin, version: version, fallback: "failed to set global version for \(spec)")
    }

    public func install(plugin: String, version: String) async throws -> UpdateResult {
        let spec = "\(plugin)@\(version)"
        return try await toolCommand(["install", "-y", spec], plugin: plugin, version: version, fallback: "failed to install \(spec)")
    }

    /// Refuses to remove a version that is currently the global selection.
    public func deleteVersion(plugin: String, version: String) async throws -> UpdateResult {
        if try await globalPlugins()[plugin]?.contains(version) == true {
            throw MiseError("cannot delete active global version")
        }
        let spec = "\(plugin)@\(version)"
        return try await toolCommand(["uninstall", "-y", spec], plugin: plugin, version: version, fallback: "failed to uninstall \(spec)")
    }

    // MARK: Plugin definitions

    public func outdatedPluginDefinitions() async throws -> [String] {
        let result = try await runOK(
            ["plugins", "ls", "--user", "--outdated"],
            fallback: "cannot check plugin updates; this mise version may not support --outdated")
        return try Parsers.parseOutdatedPlugins(stdout: result.stdout, stderr: result.stderr)
    }

    public func installedPluginNames() async throws -> [String] {
        try await lines(["plugins", "ls", "--user"], fallback: "failed to run 'mise plugins ls --user'").sorted()
    }

    public func installedUserPluginInfos() async throws -> [PluginDefinitionInfo] {
        let result = try await runOK(["plugins", "ls", "--user", "--urls"], fallback: "failed to run 'mise plugins ls --user --urls'")
        let aliases = try ToolAliasEditor.readUserAliases(at: try aliasPath())
        return Parsers.parsePluginInfoLines(result.stdout).map { info in
            var info = info
            if let alias = aliases[info.name] {
                info.url = alias
                info.source = "tool_alias"
            } else {
                info.source = "mise_user"
            }
            return info
        }.sorted { $0.name < $1.name }
    }

    public func corePluginNames() async throws -> [String] {
        try await lines(["plugins", "ls", "--core"], fallback: "failed to run 'mise plugins ls --core'").sorted()
    }

    public func installedToolNames() async throws -> [String] {
        let result = try await runOK(["ls", "--installed", "--json"], fallback: "failed to run 'mise ls --installed --json'")
        guard let entries = (try? Parsers.json(result.stdout)) as? [String: Any] else {
            throw MiseError("failed to parse JSON from 'mise ls --installed --json'")
        }
        return entries.keys.sorted()
    }

    public func remotePluginNames() async throws -> [String] {
        Parsers.dedupe(try await lines(["plugins", "ls-remote", "--only-names"], fallback: "failed to run 'mise plugins ls-remote --only-names'")).sorted()
    }

    public func remotePluginInfos() async throws -> [PluginDefinitionInfo] {
        let result = try await runOK(["plugins", "ls-remote", "--urls"], fallback: "failed to run 'mise plugins ls-remote --urls'")
        return Parsers.parsePluginInfoLines(result.stdout).sorted { $0.name < $1.name }
    }

    public func updatePluginDefinition(_ plugin: String) async throws -> PluginInstallResult {
        // Empty input to `plugins update` means ALL plugins; require one installed name.
        if plugin.isEmpty || plugin.hasPrefix("-") || plugin.contains("#") { throw MiseError("invalid plugin name") }
        let installed = try await lines(["plugins", "ls", "--user"], fallback: "cannot read installed plugins")
        guard installed.contains(plugin) else {
            throw MiseError("only installed external plugins can be updated; update mise for core plugins")
        }
        let result = try await runOK(["plugins", "update", plugin], fallback: "plugin update failed")
        return PluginInstallResult(plugin: plugin, stdout: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public func installPluginDefinition(
        plugin: String, gitUrl: String? = nil, force: Bool = false, removeToolAlias: Bool = false
    ) async throws -> PluginInstallResult {
        var args = ["plugins", "install", "-y"]
        if force { args.append("--force") }
        args.append(plugin)
        let url = gitUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url, !url.isEmpty { args.append(url) }

        let result = try await runOK(args, fallback: "failed to install plugin '\(plugin)'")
        var stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        func append(_ extra: String) { stdout = stdout.isEmpty ? extra : stdout + "\n" + extra }

        if let url, !url.isEmpty {
            append("Updated tool_alias in \(try ToolAliasEditor.updateUserAlias(at: try aliasPath(), plugin: plugin, gitUrl: url)).")
        } else if removeToolAlias {
            append("Removed tool_alias from \(try ToolAliasEditor.removeUserAlias(at: try aliasPath(), plugin: plugin)).")
        }
        return PluginInstallResult(plugin: plugin, stdout: stdout)
    }

    public func uninstallPluginDefinition(_ plugin: String) async throws -> PluginInstallResult {
        let result = try await runOK(["plugins", "uninstall", "-y", plugin], fallback: "failed to uninstall plugin '\(plugin)'")
        return PluginInstallResult(plugin: plugin, stdout: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
