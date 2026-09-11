import MiseCore
import SwiftUI

struct UpdaterTab: View {
    var state: AppState

    private var selected: PluginRow? { state.plugins.first { $0.name == state.selectedToolName } ?? state.plugins.first }
    private var summary: UpdateSummary { state.updateSummary }

    var body: some View {
        Page {
            if !summary.items.isEmpty || summary.attention { notice }
            if let error = state.toolsError {
                ErrorCard(title: "도구 목록을 불러오지 못했습니다.", message: error) {
                    Button("다시 시도") { Task { await state.reloadAndCheckTools() } }.disabled(state.actionsDisabled)
                }
            }
            if let tool = selected {
                ToolDetail(state: state, tool: tool)
            } else {
                Card {
                    Text(state.toolsLoaded ? "설치된 도구가 없습니다." : "도구를 불러오는 중입니다.").font(.title3.bold())
                    Text(state.toolsLoaded ? "mise로 도구를 설치하면 여기에 표시됩니다." : "설치된 도구를 확인하고 있습니다.").foregroundStyle(.secondary)
                    Button("목록 새로고침") { Task { await state.reloadAndCheckTools() } }.disabled(state.actionsDisabled)
                }
            }
        }
        .navigationTitle(selected?.name ?? "내 도구")
        .navigationSubtitle("설치된 버전 관리")
        .toolbar {
            ToolbarItem {
                Button(state.updateCheckRunning ? "전체 확인 중…" : "업데이트 확인") { Task { await state.checkAllUpdates() } }
                    .disabled(state.actionsDisabled || !state.miseIsInstalled)
            }
        }
    }

    private var notice: some View {
        Button { state.activeTab = .updates } label: {
            HStack {
                Circle().fill(summary.errors.isEmpty ? Color.green : Color.red).frame(width: 8, height: 8)
                Text(summary.items.isEmpty
                     ? (state.updateCheckRunning ? "업데이트를 확인하고 있어요" : "아직 확인하지 못한 항목이 있어요")
                     : "업데이트 \(summary.items.count)개를 확인했어요")
                Spacer()
                Text("모아 보기 →").foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ToolDetail: View {
    var state: AppState
    let tool: PluginRow

    private var label: String { ToolStatus.label(tool) }
    private var series: [InstalledSeries] { ToolStatus.installedSeries(tool) }
    private var update: ToolUpdate? { ToolStatus.update(tool) }
    private var disabled: Bool { state.actionsDisabled }
    private var candidates: [String] {
        var seen = Set<String>()
        return [tool.sameMajorLatest, tool.releaseLatest, state.settings.showPrereleases ? tool.overallLatest : nil]
            .compactMap { $0 }
            .filter { $0 != tool.activeGlobalVersion && seen.insert($0).inserted }
    }

    var body: some View {
        HStack(spacing: 10) {
            ToolGlyph(name: tool.name)
            Text(tool.name).font(.title2.bold())
            Pill(text: label, tint: tool.status == .error ? .red : .secondary)
        }

        Card {
            Eyebrow(text: "현재 전역 버전")
            HStack(spacing: 10) {
                Text(tool.activeGlobalVersion ?? "미선택").font(.title3.monospaced().bold())
                if tool.activeGlobalVersion != nil { Pill(text: "사용 중", tint: .accentColor) }
            }
        }

        statusNote

        SectionLabel(text: "버전 계열")
        Text("설치된 계열마다 새 버전을 확인합니다. 이전 버전은 그대로 남습니다.").foregroundStyle(.secondary)
        if series.isEmpty {
            Text("숫자 버전이 없어 major 계열을 비교할 수 없습니다.").foregroundStyle(.secondary)
        } else {
            ForEach(series, id: \.major) { seriesCard($0) }
        }

        SectionLabel(text: "설치된 버전", detail: "· \(tool.installedVersions.count)")
        if tool.installedVersions.isEmpty {
            Text("설치된 버전이 없습니다.").foregroundStyle(.secondary)
        } else {
            ForEach(tool.installedVersions, id: \.self) { installedRow($0) }
        }

        if let major = update?.major { majorNotice(major) }

        DisclosureGroup(state.settings.showPrereleases ? "다른 버전 및 프리릴리스" : "다른 버전") {
            VStack(alignment: .leading, spacing: 8) {
                Text("설치는 전역 버전을 바꾸지 않습니다. 설치 후 목록에서 전역 버전을 선택할 수 있습니다.").foregroundStyle(.secondary)
                if candidates.isEmpty {
                    Text("확인된 다른 후보가 없습니다.").foregroundStyle(.secondary)
                } else {
                    ForEach(candidates, id: \.self) { candidateRow($0) }
                }
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder private var statusNote: some View {
        switch tool.status {
        case .error:
            ErrorCard(title: "도구 정보를 확인하지 못했습니다.", message: tool.error) {
                Button("다시 확인") { Task { await state.retryCheck(tool.name) } }.disabled(disabled)
            }
        case .checking, .updating, .deleting:
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("\(label) · 작업 결과가 자동으로 반영됩니다.") }
                .foregroundStyle(.secondary)
        case .done where label == Strings.ToolStatus.latestStable:
            Text("현재 확인된 안정 버전 업데이트가 없습니다.").bold()
        case .done where label == Strings.ToolStatus.channel:
            Card {
                Text("채널 버전을 사용 중입니다.").bold()
                Text("숫자 버전과 직접 비교할 수 없습니다. 아래 후보를 확인해 주세요.").foregroundStyle(.secondary)
            }
        case .idle, .skipped:
            Text("\(label) · 업데이트 확인으로 버전 정보를 조회하세요.").foregroundStyle(.secondary)
        case .done:
            EmptyView()
        }
    }

    private func seriesCard(_ series: InstalledSeries) -> some View {
        let switches = series.update.map { state.seriesUpdateSwitchesGlobal(tool, $0) } ?? false
        return Card {
            HStack(spacing: 14) {
                Text("\(series.major).x").font(.headline.monospaced()).frame(width: 56, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(series.current)
                        if let update = series.update {
                            Image(systemName: "arrow.right").foregroundStyle(.secondary)
                            Text(update).bold()
                        }
                    }
                    .font(.body.monospaced())
                    Text(series.update != nil
                         ? (switches ? "설치 후 전역 기본값 전환" : "설치만 · 전역 기본값 유지")
                         : (series.latest != nil ? "확인된 업데이트 없음" : label))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let update = series.update {
                    Button(switches ? "설치·전역 전환" : "설치") { Task { await state.updateInstalledSeries(tool.name, update) } }
                        .disabled(disabled)
                }
            }
        }
    }

    @ViewBuilder private func installedRow(_ version: String) -> some View {
        HStack {
            Text(version).font(.body.monospaced())
            Spacer()
            if version == tool.activeGlobalVersion {
                Pill(text: "사용 중 · 삭제 불가")
            } else {
                Button("전역으로 사용") { Task { await state.useInstalledVersion(tool.name, version) } }.disabled(disabled)
                Button("삭제…", role: .destructive) { state.requestDelete(tool.name, version) }
                    .disabled(disabled)
                    .accessibilityLabel("\(tool.name) \(version) 삭제")
            }
        }
        .controlSize(.small)
        .padding(.vertical, 4)
        Divider()
    }

    private func majorNotice(_ major: String) -> some View {
        Card(tint: .accentColor) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) { Pill(text: "새 major", tint: .accentColor); Text(major).font(.headline.monospaced()) }
                    Text("호환성 확인이 필요한 별도 업데이트입니다.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("변경 검토…") { state.requestMajorUpdate(tool.name, major) }.disabled(disabled)
                if !tool.installedVersions.contains(major) {
                    Button("설치만") { Task { await state.installVersion(tool.name, major) } }.buttonStyle(.link).disabled(disabled)
                }
            }
        }
    }

    private func candidateRow(_ version: String) -> some View {
        HStack {
            Text(version).font(.body.monospaced().bold())
            Text(Version.isPreRelease(version) ? "프리릴리스" : "릴리스 후보").font(.caption).foregroundStyle(.secondary)
            Spacer()
            if tool.installedVersions.contains(version) {
                Pill(text: "설치됨")
            } else {
                Button("설치") { Task { await state.installVersion(tool.name, version) } }
                    .controlSize(.small)
                    .disabled(disabled || tool.status != .done)
            }
        }
    }
}
