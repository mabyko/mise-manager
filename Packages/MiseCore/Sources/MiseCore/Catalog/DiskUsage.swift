import Foundation

public enum DiskUsage {
    /// Allocated bytes of the regular files under a directory; nil when nothing could be read.
    /// The directory itself may be a symlink, links inside it are not followed.
    public static func size(of path: String) -> Int64? {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey]
        let root = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys)) else { return nil }
        var total: Int64 = 0
        for case let url as URL in files {
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total > 0 ? total : nil
    }
}
