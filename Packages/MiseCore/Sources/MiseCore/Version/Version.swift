import Foundation

/// Version rules shared by the whole app. Port of src-tauri/src/version.rs / src/shared/version.ts.
public enum Version {
    struct Parsed {
        let raw: String
        let parts: [UInt64]
        let isPreRelease: Bool
    }

    /// Equivalent of /^(\d+(?:\.\d+)*)(.*)$/ on the trimmed string.
    static func parse(_ raw: String) -> Parsed? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = Array(trimmed.utf8)
        guard let first = bytes.first, first.isASCIIDigit else { return nil }

        var idx = 0
        var parts: [UInt64] = []
        while true {
            let start = idx
            while idx < bytes.count, bytes[idx].isASCIIDigit { idx += 1 }
            parts.append(UInt64(String(decoding: bytes[start..<idx], as: UTF8.self)) ?? .max)
            if idx + 1 < bytes.count, bytes[idx] == UInt8(ascii: "."), bytes[idx + 1].isASCIIDigit {
                idx += 1
            } else {
                break
            }
        }

        let suffix = String(decoding: bytes[idx...], as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Parsed(raw: trimmed, parts: parts, isPreRelease: isPreReleaseSuffix(suffix))
    }

    static func isPreReleaseSuffix(_ suffix: String) -> Bool {
        if suffix.isEmpty || suffix.hasPrefix("+") { return false }
        if suffix.hasPrefix("-") { return true }
        // Keywords (a/alpha/b/beta/rc/pre/preview/dev/test) are all subsumed by "any ASCII letter".
        return suffix.utf8.contains(where: \.isASCIILetter)
    }

    public static func isPreRelease(_ version: String) -> Bool {
        if let parsed = parse(version) { return parsed.isPreRelease }
        return version.contains("-") || version.utf8.contains(where: \.isASCIILetter)
    }

    /// Only python and ruby publish pre-releases that must be hidden by default.
    public static func isStable(plugin: String, version: String) -> Bool {
        guard plugin == "python" || plugin == "ruby" else { return true }
        return !isPreRelease(version)
    }

    public static func startsWithDigit(_ version: String) -> Bool {
        version.utf8.first?.isASCIIDigit ?? false
    }

    /// Approximation of localeCompare(undefined, {numeric: true, sensitivity: "base"}):
    /// digit runs compare numerically, everything else case-insensitively.
    static func naturalCompare(_ a: String, _ b: String) -> ComparisonResult {
        let ac = Array(a), bc = Array(b)
        var i = 0, j = 0
        while true {
            switch (i < ac.count ? ac[i] : nil, j < bc.count ? bc[j] : nil) {
            case (nil, nil):
                return .orderedSame
            case (nil, .some):
                return .orderedAscending
            case (.some, nil):
                return .orderedDescending
            case let (x?, y?) where x.isASCIIDigit && y.isASCIIDigit:
                var na = "", nb = ""
                while i < ac.count, ac[i].isASCIIDigit { na.append(ac[i]); i += 1 }
                while j < bc.count, bc[j].isASCIIDigit { nb.append(bc[j]); j += 1 }
                let ta = na.drop(while: { $0 == "0" }), tb = nb.drop(while: { $0 == "0" })
                if ta.count != tb.count { return ta.count < tb.count ? .orderedAscending : .orderedDescending }
                if ta != tb { return ta < tb ? .orderedAscending : .orderedDescending }
            case let (x?, y?):
                let xl = x.lowercased(), yl = y.lowercased()
                if xl != yl { return xl < yl ? .orderedAscending : .orderedDescending }
                i += 1
                j += 1
            }
        }
    }

    public static func compare(_ a: String, _ b: String) -> ComparisonResult {
        guard let pa = parse(a), let pb = parse(b) else { return naturalCompare(a, b) }
        for i in 0..<max(pa.parts.count, pb.parts.count) {
            let x = i < pa.parts.count ? pa.parts[i] : 0
            let y = i < pb.parts.count ? pb.parts[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        if pa.isPreRelease != pb.isPreRelease {
            return pa.isPreRelease ? .orderedAscending : .orderedDescending
        }
        return naturalCompare(pa.raw, pb.raw)
    }

    public static func major(of version: String) -> UInt64? {
        parse(version)?.parts.first
    }

    /// Highest version; of equal candidates the last one wins (matches TS sort().at(-1)).
    public static func pickLatest(_ versions: some Sequence<String>) -> String? {
        var best: String?
        for candidate in versions where best.map({ compare($0, candidate) != .orderedDescending }) ?? true {
            best = candidate
        }
        return best
    }
}

private extension UInt8 {
    var isASCIIDigit: Bool { (48...57).contains(self) }
    var isASCIILetter: Bool { (65...90).contains(self) || (97...122).contains(self) }
}

private extension Character {
    var isASCIIDigit: Bool { asciiValue.map { (48...57).contains($0) } ?? false }
}
