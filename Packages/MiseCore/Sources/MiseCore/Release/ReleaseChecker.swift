import Foundation

/// mise isn't in its own registry, so the latest release comes from https://mise.jdx.dev/VERSION
/// (what install.sh reads; no API quota) with the GitHub Releases API as fallback.
public enum ReleaseChecker {
    static func text(_ url: String) async throws -> String {
        var request = URLRequest(url: URL(string: url)!, timeoutInterval: 20)
        request.setValue("mise-manager", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw MiseError("\(url) returned status \(http.statusCode)")
        }
        return String(decoding: data, as: UTF8.self)
    }

    public static func latestMiseRelease() async throws -> String? {
        var tag: String
        do {
            tag = try await text("https://mise.jdx.dev/VERSION")
        } catch let versionError {
            let body: String
            do {
                body = try await text("https://api.github.com/repos/jdx/mise/releases/latest")
            } catch let apiError {
                throw MiseError("\(versionError.localizedDescription); \(apiError.localizedDescription)")
            }
            let json = try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]
            tag = json?["tag_name"] as? String ?? ""
        }
        tag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        return tag.isEmpty ? nil : tag
    }
}
