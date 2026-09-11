import MiseCore
import SwiftUI

enum SidebarItem: Hashable {
    case updates, tool(String), mise, installs, logs, settings
}

struct Sidebar: View {
    @Bindable var state: AppState

    private var summary: UpdateSummary { state.updateSummary }
    private var tools: [PluginRow] {
        let query = state.toolSearchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        return state.plugins.filter { query.isEmpty || $0.name.lowercased().contains(query) }
    }
    private var selectedTool: String? { state.selectedToolName ?? state.plugins.first?.name }

    private var selection: Binding<SidebarItem?> {
        Binding {
            switch state.activeTab {
            case .updates: .updates
            case .updater: selectedTool.map(SidebarItem.tool)
            case .mise: .mise
            case .installs: .installs
            case .logs: .logs
            case .settings: .settings
            }
        } set: { item in
            switch item {
            case .updates: state.activeTab = .updates
            case .tool(let name):
                state.selectedToolName = name
                state.activeTab = .updater
            case .mise: Task { await state.run(.open(tab: .mise)) }
            case .installs: Task { await state.run(.open(tab: .installs)) }
            case .logs: Task { await state.run(.open(tab: .logs)) }
            case .settings: state.activeTab = .settings
            case nil: break
            }
        }
    }

    private var countBadge: String {
        if state.busy || state.updateCheckRunning { return "…" }
        if !summary.items.isEmpty { return "\(summary.items.count)" }
        return summary.attention ? "!" : "0"
    }

    var body: some View {
        List(selection: selection) {
            HStack(spacing: 8) {
                Image("BrandIcon").resizable().frame(width: 20, height: 20)
                Text("Mise Manager").font(.headline)
            }
            .selectionDisabled()
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 8, trailing: 8))

            Label("업데이트", systemImage: "arrow.down.circle")
                .badge(countBadge)
                .tag(SidebarItem.updates)

            Section("설치된 도구 \(state.plugins.count)") {
                ForEach(tools, id: \.name) { tool in
                    toolRow(tool).tag(SidebarItem.tool(tool.name))
                }
                if tools.isEmpty {
                    Text(state.toolSearchQuery.isEmpty ? (state.toolsLoaded ? "설치된 도구 없음" : "불러오는 중…") : "검색 결과가 없습니다.")
                        .foregroundStyle(.secondary)
                        .selectionDisabled()
                }
            }

            Section("관리") {
                Label("mise", systemImage: "shippingbox").badge(Text("버전 관리자")).tag(SidebarItem.mise)
                Label("플러그인 관리", systemImage: "puzzlepiece.extension").tag(SidebarItem.installs)
                    .selectionDisabled(!state.installsLoaded && (state.busy || state.updateCheckRunning))
                Label("작업 기록", systemImage: "doc.text").tag(SidebarItem.logs)
            }

            Section {
                Label("설정", systemImage: "gearshape").tag(SidebarItem.settings)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $state.toolSearchQuery, placement: .sidebar, prompt: "도구 검색")
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    }

    private func toolRow(_ tool: PluginRow) -> some View {
        let label = ToolStatus.label(tool)
        return HStack(spacing: 6) {
            Text(tool.name)
            Spacer(minLength: 4)
            if ToolStatus.hasUpdates(tool) {
                Circle().fill(.orange).frame(width: 7, height: 7).accessibilityLabel("업데이트 있음")
            } else if label != Strings.ToolStatus.latestStable {
                Text(label).font(.caption).foregroundStyle(tool.status == .error ? .red : .secondary)
            }
            Text(tool.activeGlobalVersion ?? "미선택").font(.caption.monospaced()).foregroundStyle(.secondary)
        }
        .accessibilityLabel("\(tool.name) \(tool.activeGlobalVersion ?? "전역 미선택") · \(label)")
    }
}
