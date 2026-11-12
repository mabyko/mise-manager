import MiseCore
import SwiftUI

extension AppState {
    /// App-wide actions wait for every running command; tool controls use toolActionsDisabled.
    var actionsDisabled: Bool { busy || updateCheckRunning }
}

struct ToolGlyph: View {
    let name: String
    var body: some View {
        let tint = Self.tint(name)
        Text(ToolName.initials(name))
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
    }

    /// One stable colour per tool so rows can be told apart; red and orange stay reserved for status.
    static func tint(_ name: String) -> Color {
        let palette: [Color] = [.blue, .purple, .pink, .teal, .indigo, .green, .brown, .cyan, .mint]
        let hash = ToolName.short(name).unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 9973 }
        return palette[hash % palette.count]
    }
}

/// Tool name without its backend prefix; the backend (`http`, `npm`, …) follows as a quiet tag.
struct ToolTitle: View {
    let name: String
    var body: some View {
        HStack(spacing: 6) {
            Text(ToolName.short(name)).bold().lineLimit(1)
            if let backend = ToolName.backend(name) {
                Text(backend)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary.opacity(0.6), in: Capsule())
            }
        }
    }
}

/// What tells an installed version apart from its siblings: the global selection, an older patch
/// of the same major, and whether mise reports it as used.
struct VersionBadges: View {
    let version: InstalledVersion
    /// Other versions of the same major are installed, so "계열 최신" says something.
    let hasSiblings: Bool

    var body: some View {
        HStack(spacing: 6) {
            if version.isGlobal { Text("전역").bold().foregroundStyle(Color.accentColor) }
            if version.isSuperseded {
                Text("구버전").foregroundStyle(.orange).help("같은 계열에 더 새 버전이 설치되어 있습니다")
            } else if hasSiblings {
                Text("계열 최신").foregroundStyle(.secondary)
            }
            if !version.isGlobal, let unused = version.isUnused {
                Text(unused ? "미사용" : "사용 중")
                    .foregroundStyle(.secondary)
                    .help(DeleteCopy.note(unused))
            }
        }
        .font(.caption)
        .lineLimit(1)
        .fixedSize()
    }
}

/// Wording shared by the main window's delete dialog and the menu bar's inline confirmation.
enum DeleteCopy {
    static func title(_ name: String, _ versions: [String]) -> String {
        versions.count == 1 ? "\(name) \(versions[0]) 버전을 삭제할까요?" : "\(name) 구버전 \(versions.count)개를 삭제할까요?"
    }

    /// `unused` is mise's own answer (`ls --prunable`): true, false, or nil when it could not tell.
    static func note(_ unused: Bool?) -> String {
        switch unused {
        case true?: "mise가 추적하는 설정 파일과 실행 중인 프로세스가 사용하지 않습니다."
        case false?: "설정 파일이나 실행 중인 프로세스가 사용하고 있습니다."
        case nil: "프로젝트에서 사용하는 버전일 수 있습니다."
        }
    }

    static func size(_ bytes: Int64) -> String { bytes.formatted(.byteCount(style: .file)) }
}

struct Pill: View {
    let text: String
    var tint: Color = .secondary
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct Card<Content: View>: View {
    var tint: Color?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background((tint ?? Color.primary).opacity(tint == nil ? 0.05 : 0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ErrorCard<Actions: View>: View {
    let title: String
    var message: String?
    @ViewBuilder var actions: Actions
    var body: some View {
        Card(tint: .red) {
            Text(title).bold()
            if let message { Text(message).foregroundStyle(.secondary).textSelection(.enabled) }
            actions
        }
    }
}

extension ErrorCard where Actions == EmptyView {
    init(title: String, message: String? = nil) {
        self.init(title: title, message: message) { EmptyView() }
    }
}

struct SectionLabel: View {
    let text: String
    var detail: String?
    var body: some View {
        HStack(spacing: 6) {
            Text(text).font(.headline)
            if let detail { Text(detail).foregroundStyle(.secondary) }
        }
        .padding(.top, 6)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(.caption).textCase(.uppercase).foregroundStyle(.secondary) }
}

/// Scrollable page body with a comfortable reading width.
struct Page<Content: View>: View {
    @Environment(\.snapshotMode) private var snapshotMode
    @ViewBuilder var content: Content
    var body: some View {
        if snapshotMode {
            body_
        } else {
            ScrollView { body_ }
        }
    }
    private var body_: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Debug renders (ImageRenderer) can't draw AppKit-backed scroll views; pages lay out flat instead.
private struct SnapshotModeKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var snapshotMode: Bool {
        get { self[SnapshotModeKey.self] }
        set { self[SnapshotModeKey.self] = newValue }
    }
}
