import MiseCore
import SwiftUI

/// Pending updates as rows with one action each. Shared by the updates tab and the menu bar panel.
struct UpdateList: View {
    var state: AppState
    let items: [UpdateItem]
    var onMiseUpdate: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            ForEach(items) { row($0) }
        }
    }

    private func row(_ item: UpdateItem) -> some View {
        let switches = item.kind == .series && (state.plugin(item.name).map { state.seriesUpdateSwitchesGlobal($0, item.to) } ?? false)
        let hint: String = switch item.kind {
        case .series: switches ? "설치 후 전역 전환" : "설치만 · 전역 유지"
        case .major: "호환성 확인 필요 · 앱에서 검토"
        case .mise: onMiseUpdate == nil ? "앱에서 확인 후 업데이트" : "메뉴바에서 확인 후 업데이트"
        case .plugin: "플러그인 소스 갱신"
        }
        let action: String = switch item.kind {
        case .series: switches ? "설치·전환" : "설치"
        case .plugin: "업데이트"
        case .major: "검토…"
        case .mise: onMiseUpdate == nil ? "검토…" : "업데이트"
        }
        return HStack(spacing: 12) {
            ToolGlyph(name: item.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).bold()
                HStack(spacing: 4) {
                    Text(item.from)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    Text(item.to).bold()
                }
                .font(.callout.monospaced())
                Text(hint).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action) {
                if item.kind == .mise, let onMiseUpdate { onMiseUpdate() }
                else { Task { await state.run(.apply(id: item.id)) } }
            }
                .controlSize(.small)
                .disabled(item.kind == .series || item.kind == .major
                          ? state.toolActionsDisabled(item.name) : state.actionsDisabled)
                .accessibilityLabel("\(item.label) \(item.to) \(action)")
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}
