import Foundation

// Port of src-tauri/src/contracts.rs / src/shared/contracts.ts.

public struct PluginSummary: Codable, Equatable, Sendable {
    public var name: String
    public var activeGlobalVersion: String?
    public var installedVersions: [String]

    public init(name: String, activeGlobalVersion: String? = nil, installedVersions: [String] = []) {
        self.name = name
        self.activeGlobalVersion = activeGlobalVersion
        self.installedVersions = installedVersions
    }
}

public struct PluginUpdateInfo: Codable, Equatable, Sendable {
    public var plugin: String
    public var baseVersion: String
    public var sameMajorLatest: String?
    public var latestByMajor: [String: String]
    public var releaseLatest: String?
    public var overallLatest: String?
    public var checkedVersions: Int
    public var error: String?

    public init(
        plugin: String, baseVersion: String, sameMajorLatest: String? = nil,
        latestByMajor: [String: String] = [:], releaseLatest: String? = nil,
        overallLatest: String? = nil, checkedVersions: Int = 0, error: String? = nil
    ) {
        self.plugin = plugin
        self.baseVersion = baseVersion
        self.sameMajorLatest = sameMajorLatest
        self.latestByMajor = latestByMajor
        self.releaseLatest = releaseLatest
        self.overallLatest = overallLatest
        self.checkedVersions = checkedVersions
        self.error = error
    }
}

public struct UpdateResult: Codable, Equatable, Sendable {
    public var plugin: String
    public var targetVersion: String
    public var stdout: String

    public init(plugin: String, targetVersion: String, stdout: String) {
        self.plugin = plugin
        self.targetVersion = targetVersion
        self.stdout = stdout
    }
}

public struct PluginInstallResult: Codable, Equatable, Sendable {
    public var plugin: String
    public var stdout: String

    public init(plugin: String, stdout: String) {
        self.plugin = plugin
        self.stdout = stdout
    }
}

public struct PluginDefinitionInfo: Codable, Equatable, Sendable {
    public var name: String
    public var url: String?
    /// "tool_alias" | "mise_user" for installed user plugins; nil for remote listings.
    public var source: String?

    public init(name: String, url: String? = nil, source: String? = nil) {
        self.name = name
        self.url = url
        self.source = source
    }
}

public struct MiseSelfUpdateResult: Codable, Equatable, Sendable {
    public var beforeVersion: String?
    public var afterVersion: String?
    public var stdout: String
    public var stderr: String

    public init(beforeVersion: String?, afterVersion: String?, stdout: String, stderr: String) {
        self.beforeVersion = beforeVersion
        self.afterVersion = afterVersion
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct MiseInstallResult: Codable, Equatable, Sendable {
    public var success: Bool
    public var stdout: String
    public var stderr: String

    public init(success: Bool, stdout: String, stderr: String) {
        self.success = success
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Every failure the UI shows is a plain message (Rust used `Result<_, String>`).
public struct MiseError: Error, Equatable, Sendable, CustomStringConvertible, LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
    public var errorDescription: String? { message }
}
