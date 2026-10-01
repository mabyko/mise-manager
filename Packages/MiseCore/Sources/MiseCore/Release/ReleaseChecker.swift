import Foundation

public struct MiseRelease: Equatable, Sendable, Identifiable {
    public let version: String
    public let publishedAt: Date
    public var id: String { version }

    public init(version: String, publishedAt: Date) {
        self.version = version
        self.publishedAt = publishedAt
    }
}

public struct MiseReleasePolicy: Equatable, Sendable {
    public let eligibleVersion: String
    public let minimumAge: String
}

/// The same stable-release publication index mise self-update uses; no GitHub API quota.
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

    public static func miseReleases() async throws -> [MiseRelease] {
        try parseIndex(await text("https://mise.jdx.dev/releases.tsv"))
    }

    static func parseIndex(_ text: String) throws -> [MiseRelease] {
        var releases: [MiseRelease] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count == 2,
                  fields[0].wholeMatch(of: /v?\d+\.\d+\.\d+/) != nil,
                  let timestamp = Double(fields[1]), timestamp.isFinite, timestamp >= 0 else {
                throw MiseError("mise 릴리스의 버전 또는 공개 시각을 확인하지 못했습니다.")
            }
            let version = String(fields[0].hasPrefix("v") ? fields[0].dropFirst() : fields[0])
            guard !releases.contains(where: { $0.version == version }) else { continue }
            releases.append(MiseRelease(version: version, publishedAt: Date(timeIntervalSince1970: timestamp)))
        }
        guard !releases.isEmpty else { throw MiseError("mise 릴리스 목록이 비어 있습니다.") }
        return releases.sorted { Version.compare($0.version, $1.version) == .orderedDescending }
    }
}
