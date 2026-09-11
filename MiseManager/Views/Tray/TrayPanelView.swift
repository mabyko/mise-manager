import MiseCore
import SwiftUI

/// Menu-bar quick view (was TrayApp.svelte). Observes the same AppState as the main window.
struct TrayPanelView: View {
    var state: AppState
    let close: () -> Void
    @State private var onlyUpdates = false
    @Environment(\.snapshotMode) private var snapshotMode

    private var summary: UpdateSummary { state.updateSummary }
    private var checking: Bool { state.busy || state.updateCheckRunning }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
            tabs.padding(.horizontal, 14).padding(.bottom, 10)
            Divider()
            if snapshotMode { content } else { ScrollView { content } }
            Divider()
            footer.padding(.horizontal, 14).padding(.vertical, 10)
        }
        .frame(width: TrayPanel.size.width, height: snapshotMode ? nil : TrayPanel.size.height)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("BrandIcon").resizable().frame(width: 18, height: 18)
            Text("Mise Manager").font(.headline)
            Spacer()
            Button { open(.settings) } label: { Image(systemName: "gearshape") }
                .buttonStyle(.plain).help("설정 열기").accessibilityLabel("설정 열기")
        }
    }

    private var tabs: some View {
        HStack {
            Picker("빠른 관리", selection: $onlyUpdates) {
                Text("내 도구").tag(false)
                Text("업데이트 \(checking ? "…" : "\(summary.items.count)")").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden()
            Button { Task { await state.run(.check) } } label: { Image(systemName: "arrow.clockwise") }
                .disabled(checking || !state.miseIsInstalled)
                .help("전체 업데이트 확인").accessibilityLabel("전체 업데이트 확인")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if summary.attention { attention }
            if onlyUpdates {
                UpdateList(state: state, items: summary.items)
                if summary.items.isEmpty {
                    Text(summary.attention ? "아직 확인된 업데이트가 없습니다." : "확인된 업데이트가 없습니다.").foregroundStyle(.secondary)
                }
            } else {
                tools
            }
            if let result = state.pluginUpdateResult { Text(result).font(.callout) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attention: some View {
        Button { open(.updates) } label: {
            Text(checking ? state.progressLabel
                 : summary.errors.isEmpty ? "미확인 항목 있음 · 앱에서 확인 →" : "일부 확인 실패 · 앱에서 확인 →")
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background((summary.errors.isEmpty ? Color.orange : Color.red).opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var tools: some View {
        if state.plugins.isEmpty {
            Text(state.toolsLoaded ? "설치된 도구가 없습니다." : "도구를 불러오는 중…").foregroundStyle(.secondary)
        }
        ForEach(state.plugins, id: \.name) { tool in toolSection(tool) }

        SectionLabel(text: "mise · 플러그인")
        let rest = summary.items.filter { $0.kind == .mise || $0.kind == .plugin }
        UpdateList(state: state, items: rest)
        if !rest.contains(where: { $0.kind == .mise }) {
            Button { open(.mise) } label: {
                HStack {
                    Text("mise").bold()
                    Text(state.miseVersion ?? "미확인").font(.callout.monospaced()).foregroundStyle(.secondary)
                    Spacer()
                    Text("관리 →").foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private func toolSection(_ tool: PluginRow) -> some View {
        let updates = summary.items.filter { $0.name == tool.name && ($0.kind == .series || $0.kind == .major) }
        if !updates.isEmpty { UpdateList(state: state, items: updates) }
        ForEach(ToolStatus.installedSeries(tool).filter { series in !updates.contains { $0.to == series.update } }, id: \.major) { series in
            HStack(spacing: 10) {
                ToolGlyph(name: tool.name)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(tool.name) \(series.major).x").bold()
                    Text(series.current).font(.callout.monospaced())
                }
                Spacer()
                Text(series.latest != nil ? "설치됨" : ToolStatus.label(tool)).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(tool.installedVersions, id: \.self) { version in
                    HStack {
                        Text(version).font(.callout.monospaced())
                        Spacer()
                        if tool.activeGlobalVersion == version {
                            Text("사용 중").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Button("전역으로 사용") { Task { await state.run(.use(name: tool.name, version: version)) } }
                                .controlSize(.small).disabled(checking)
                        }
                    }
                }
                Button("앱에서 자세히 보기 →") { open(.updater, name: tool.name) }.buttonStyle(.link)
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 6) {
                Text("\(tool.name) 버전 관리")
                Text("전역 \(tool.activeGlobalVersion ?? "미선택")").font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if checking { ProgressView().controlSize(.small) }
            Text(checking ? state.progressLabel : (state.toolsCheckedAt.map { "\($0) 도구 확인" } ?? "업데이트 확인 전"))
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            Button("종료") { NSApp.terminate(nil) }.buttonStyle(.link)
            Button("앱 열기 ↗") { open(.updates) }.buttonStyle(.link)
        }
    }

    private func open(_ tab: ActiveTab, name: String? = nil) {
        close()
        Task { await state.run(.open(tab: tab, name: name)) }
    }
}
