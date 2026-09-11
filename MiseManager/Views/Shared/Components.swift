import MiseCore
import SwiftUI

extension AppState {
    /// Every mutating control is off while a command runs or a full check is in flight.
    var actionsDisabled: Bool { busy || updateCheckRunning }
}

struct ToolGlyph: View {
    let name: String
    var body: some View {
        Text(name.prefix(2))
            .font(.caption.weight(.bold))
            .frame(width: 28, height: 28)
            .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
    }
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
