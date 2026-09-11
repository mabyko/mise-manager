import MiseCore
import SwiftUI

struct InstallsTab: View {
    @Bindable var state: AppState

    private static let rowLimit = 200

    private struct InstalledRow: Identifiable {
        let plugin: String
        let userPluginInstalled: Bool
        let corePlugin: Bool
        let toolInstalled: Bool
        let userInfo: PluginDefinitionInfo?
        let isCustomUserUrl: Bool
        var id: String { plugin }
    }

    private var filtered: [String] {
        let query = state.pluginSearchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        return state.installCatalog.filter { query.isEmpty || $0.lowercased().contains(query) }
    }

    private var installedAll: [InstalledRow] {
        filtered.compactMap { plugin in
            let user = state.installedPluginNames.contains(plugin)
            let core = state.corePluginNames.contains(plugin)
            let tool = state.installedToolNames.contains(plugin)
            guard user || core || tool else { return nil }
            return InstalledRow(
                plugin: plugin, userPluginInstalled: user, corePlugin: core, toolInstalled: tool,
                userInfo: PluginSource.userPluginInfo(plugin, in: state.installedUserPluginInfos),
                isCustomUserUrl: user && PluginSource.isCustomUserURL(plugin, installed: state.installedUserPluginInfos, remote: state.remotePluginInfos))
        }
    }

    private var notInstalledAll: [(plugin: String, url: String?)] {
        filtered
            .filter { !state.installedPluginNames.contains($0) && !state.corePluginNames.contains($0) && !state.installedToolNames.contains($0) }
            .map { plugin in (plugin, state.remotePluginInfos.first { $0.name == plugin }?.url) }
    }

    var body: some View {
        let installed = installedAll
        let notInstalled = notInstalledAll
        Page {
            updatesPanel
            if let error = state.installsError {
                ErrorCard(title: "플러그인 목록을 불러오지 못했습니다.", message: error) {
                    Button("다시 시도") { Task { await state.reloadPluginDefinitions() } }.disabled(state.busy)
                }
            }
            Text("설치 가능한 플러그인 \(state.remotePluginNames.count)개 · 내장 \(state.corePluginNames.count)개 · 외부 \(state.installedPluginNames.count)개")
                .font(.callout).foregroundStyle(.secondary)

            SectionLabel(text: "사용 가능한 플러그인")
            Card {
                tableHeader("플러그인", "상태", "관리")
                if installed.isEmpty { Text("설치된 항목이 없습니다.").foregroundStyle(.secondary) }
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(installed.prefix(Self.rowLimit)) { installedRow($0); Divider() }
                }
                if installed.count > Self.rowLimit { hidden(installed.count - Self.rowLimit) }
            }

            SectionLabel(text: "설치 가능한 플러그인")
            Card {
                tableHeader("플러그인", "Source", "관리")
                if notInstalled.isEmpty {
                    HStack {
                        Text("검색 결과가 없습니다.").foregroundStyle(.secondary)
                        Button("사용자 플러그인 추가") { state.openCustomPluginDialog() }.controlSize(.small).disabled(state.busy)
                    }
                }
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(notInstalled.prefix(Self.rowLimit), id: \.plugin) { availableRow($0.plugin, $0.url); Divider() }
                }
                if notInstalled.count > Self.rowLimit { hidden(notInstalled.count - Self.rowLimit) }
            }
        }
        .navigationTitle("플러그인 관리")
        .navigationSubtitle("도구를 설치하는 데 사용하는 플러그인 정의를 관리합니다")
        .toolbar {
            ToolbarItemGroup {
                TextField("플러그인 검색", text: $state.pluginSearchQuery, prompt: Text("플러그인 이름으로 검색"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button("사용자 플러그인 추가") { state.openCustomPluginDialog() }.disabled(state.busy)
                Button { Task { await state.reloadPluginDefinitions() } } label: { Image(systemName: "arrow.clockwise") }
                    .help("목록 새로고침")
                    .disabled(state.busy)
            }
        }
    }

    private var updatesPanel: some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("플러그인 업데이트").font(.headline)
                    Text("플러그인의 설치 스크립트와 버전 정보를 갱신합니다. 도구 버전은 별도로 설치합니다.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("플러그인 업데이트 확인") { Task { await state.checkPluginDefinitionUpdates() } }
                    .disabled(state.busy || !state.miseIsInstalled)
            }
            Text(state.pluginUpdatesCheckedAt.map { "마지막 확인 \($0)" } ?? "아직 확인하지 않았습니다.").font(.callout).foregroundStyle(.secondary)
            if let error = state.pluginUpdatesError {
                ErrorCard(title: "확인 실패: \(error)", message: "mise를 최신 버전으로 업데이트한 뒤 다시 확인하세요. 네트워크 오류는 연결 상태를 확인해 주세요.")
            } else if state.pluginUpdatesCheckedAt != nil, state.outdatedPluginNames.isEmpty {
                Text("mise가 보고한 외부 플러그인 업데이트가 없습니다.")
            }
            ForEach(state.outdatedPluginNames, id: \.self) { plugin in
                HStack {
                    Text(plugin).bold()
                    Spacer()
                    Button("\(plugin) 업데이트") { Task { await state.updatePluginDefinition(plugin) } }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.busy || state.pluginUpdatesError != nil)
                }
            }
            if let result = state.pluginUpdateResult { Text(result) }
            Text("내장 플러그인은 mise와 함께 업데이트됩니다. 로컬 연결·압축 파일로 설치한 플러그인은 Git 업데이트 대상에서 제외될 수 있습니다.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func tableHeader(_ a: String, _ b: String, _ c: String) -> some View {
        HStack {
            Text(a).frame(width: 160, alignment: .leading)
            Text(b)
            Spacer()
            Text(c)
        }
        .font(.caption).foregroundStyle(.secondary)
    }

    private func hidden(_ count: Int) -> some View {
        Text("+\(count)개 더 있음 — 검색으로 좁혀보세요.").foregroundStyle(.secondary).padding(.top, 6)
    }

    private func installedRow(_ row: InstalledRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(row.plugin).bold().frame(width: 160, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if row.userPluginInstalled { Pill(text: "외부 플러그인", tint: .accentColor) }
                    if row.corePlugin { Pill(text: "mise 내장") }
                    if row.toolInstalled { Pill(text: "도구 설치됨", tint: .green) }
                }
                if row.userPluginInstalled {
                    HStack(spacing: 6) {
                        Text(row.userInfo?.url == nil ? "URL" : (row.isCustomUserUrl ? "Custom URL" : "Default URL"))
                            .font(.caption.bold()).foregroundStyle(row.isCustomUserUrl ? .orange : .secondary)
                        Text(row.userInfo?.url ?? "N/A").font(.caption.monospaced()).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle).help(row.userInfo?.url ?? "")
                    }
                }
            }
            Spacer()
            if row.userPluginInstalled {
                Button("URL 수정") { state.openEditPluginDialog(row.plugin) }.disabled(state.busy || row.corePlugin)
                Button("플러그인 제거") { Task { await state.uninstallPluginDefinition(row.plugin) } }
                    .help("User plugin definition 제거").disabled(state.busy)
            } else {
                Text(row.corePlugin ? "Core — 제거 불가" : "Tool only").font(.caption).foregroundStyle(.secondary)
            }
        }
        .controlSize(.small)
        .padding(.vertical, 8)
    }

    private func availableRow(_ plugin: String, _ url: String?) -> some View {
        HStack(spacing: 12) {
            Text(plugin).bold().frame(width: 160, alignment: .leading)
            Text(url ?? "registry").font(.caption.monospaced()).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle).help(url ?? "")
            Spacer()
            Button("플러그인 설치") { state.openInstallPluginDialog(plugin) }.disabled(state.busy)
        }
        .controlSize(.small)
        .padding(.vertical, 8)
    }
}
