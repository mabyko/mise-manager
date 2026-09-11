import Foundation

/// GUI apps don't inherit the shell PATH, so mise is looked up in the usual install
/// locations instead of running a login shell (slow, side effects).
public enum PathResolver {
    static let fallbackBinDirs = [
        ".local/bin", ".mise/bin", "bin",
        "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
    ]

    static var home: String? { ProcessInfo.processInfo.environment["HOME"] }

    static func expandHome(_ value: String) -> String {
        if let home, value.hasPrefix("~/") { return home + value.dropFirst(1) }
        return value
    }

    /// Current PATH entries followed by the fallback dirs, deduplicated, colon-joined.
    public static func augmentedPATH(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        var dirs: [String] = []
        for dir in (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        where !dir.isEmpty && !dirs.contains(dir) {
            dirs.append(dir)
        }
        let home = environment["HOME"]
        for dir in fallbackBinDirs {
            let resolved = dir.hasPrefix("/") ? dir : (home.map { $0 + "/" + dir } ?? dir)
            if !dirs.contains(resolved) { dirs.append(resolved) }
        }
        return dirs.joined(separator: ":")
    }

    /// `MISE_BIN` → first `<dir>/mise` on the augmented PATH → bare "mise".
    public static func resolveMiseExecutable(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        if let bin = environment["MISE_BIN"]?.trimmingCharacters(in: .whitespacesAndNewlines), !bin.isEmpty {
            return expandHome(bin)
        }
        for dir in augmentedPATH(environment: environment).split(separator: ":") where !dir.isEmpty {
            let candidate = String(dir) + "/mise"
            if FileManager.default.fileExists(atPath: candidate) { return candidate }
        }
        return "mise"
    }
}
