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
    private var groups: [InstalledVersionGroup] { ToolStatus.versionGroups(tool) }
    private var cleanup: [String] { ToolStatus.cleanupCandidates(tool) }
    private var update: ToolUpdate? { ToolStatus.update(tool) }
    private var disabled: Bool { state.toolActionsDisabled(tool.name) }
    private var candidates: [String] { ToolStatus.otherCandidates(tool, includePrerelease: state.settings.showPrereleases) }

    var body: some View {
        HStack(spacing: 10) {
            ToolGlyph(name: tool.name)
            Text(tool.name).font(.title2.bold())
            Pill(text: label, tint: tool.status == .error ? .red : .secondary)
        }

        Card {
            Eyebrow(text: "현재 전역 버전")
            Text(tool.activeGlobalVersion ?? "미선택").font(.title3.monospaced().bold())
        }

        statusNote

        HStack(alignment: .firstTextBaseline) {
            SectionLabel(text: "설치된 버전", detail: "· \(tool.installedVersions.count)")
            Spacer()
            if !cleanup.isEmpty {
                Button("구버전 \(cleanup.count)개 정리…") { state.requestCleanup(tool.name) }
                    .controlSize(.small).disabled(disabled)
                    .help("같은 계열에 더 새 버전이 설치된 버전을 한 번에 삭제합니다. 전역 버전과 사용 중으로 확인된 버전은 제외합니다")
            }
        }
        Text(series.isEmpty
             ? (tool.installedVersions.contains(where: Version.isLinelessRuntime) ? "업데이트를 확인할 수 없는 버전이 설치되어 있습니다." : "채널 버전만 있어 계열을 비교할 수 없습니다.")
             : "계열마다 새 버전을 확인합니다. 같은 계열에 더 새 버전이 설치된 버전은 구버전으로 표시합니다.")
            .foregroundStyle(.secondary)
        if tool.installedVersions.isEmpty {
            Text("설치된 버전이 없습니다.").foregroundStyle(.secondary)
        } else {
            ForEach(groups) { groupCard($0) }
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
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("\(state.toolOperations[tool.name] ?? label) · 작업 결과가 자동으로 반영됩니다.") }
                .foregroundStyle(.secondary)
        case .done where label == Strings.ToolStatus.latestStable:
            Text("현재 확인된 안정 버전 업데이트가 없습니다.").bold()
        case .done where tool.baseVersion.map(Version.isLinelessRuntime) == true:
            Text("이 버전의 업데이트를 확인할 수 없습니다.").foregroundStyle(.secondary)
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

    /// One major line: its update state on top, then every installed version of that line.
    private func groupCard(_ group: InstalledVersionGroup) -> some View {
        Card {
            if let series = series.first(where: { $0.line == group.line }) {
                seriesHeader(series)
            } else if groups.count > 1 {
                Text("기타 버전").font(.headline)
            }
            ForEach(group.versions) { version in
                Divider()
                installedRow(version, hasSiblings: group.hasSiblings)
            }
        }
    }

    private func seriesHeader(_ series: InstalledSeries) -> some View {
        let switches = series.update.map { state.seriesUpdateSwitchesGlobal(tool, $0) } ?? false
        return HStack(spacing: 14) {
            Text("\(series.line).x").font(.headline.monospaced()).lineLimit(1).fixedSize().frame(minWidth: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                if let update = series.update {
                    HStack(spacing: 6) {
                        Text(series.current)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        Text(update).bold()
                    }
                    .font(.body.monospaced()).lineLimit(1).truncationMode(.middle)
                }
                Text(series.update != nil
                     ? (switches ? "설치 후 전역 기본값 전환" : "설치만 · 전역 기본값 유지")
                     : (series.latest != nil ? "확인된 업데이트 없음" : (tool.status == .done ? Strings.ToolStatus.noComparison : label)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let update = series.update {
                Button(switches ? "설치·전역 전환" : "설치") { Task { await state.updateInstalledSeries(tool.name, update) } }
                    .disabled(disabled)
            }
        }
    }

    private func installedRow(_ item: InstalledVersion, hasSiblings: Bool) -> some View {
        HStack(spacing: 10) {
            Text(item.version).font(.body.monospaced()).lineLimit(1).truncationMode(.middle)
            VersionBadges(version: item, hasSiblings: hasSiblings)
            Spacer()
            if let size = state.diskSize(tool, [item.version]) {
                Text(DeleteCopy.size(size)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if !item.isGlobal {
                Button("전역으로 사용") { Task { await state.useInstalledVersion(tool.name, item.version) } }.disabled(disabled)
                Button("삭제…", role: .destructive) { state.requestDelete(tool.name, item.version) }
                    .disabled(disabled)
                    .accessibilityLabel("\(tool.name) \(item.version) 삭제")
            }
        }
        .controlSize(.small)
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
            Text(version == tool.overallLatest && version != tool.releaseLatest ? "프리릴리스" : "릴리스 후보").font(.caption).foregroundStyle(.secondary)
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
