import MiseCore
import SwiftUI

/// Menu-bar quick view (was TrayApp.svelte). Observes the same AppState as the main window.
struct TrayPanelView: View {
    var state: AppState
    let close: () -> Void
    @State private var onlyUpdates = false
    @State private var confirmingMiseUpdate = false
    @Environment(\.snapshotMode) private var snapshotMode
    @Environment(\.openWindow) private var openWindow

    private var summary: UpdateSummary { state.updateSummary }
    private var checking: Bool { state.busy || state.updateCheckRunning }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
            tabs.padding(.horizontal, 14).padding(.bottom, 10)
            Divider()
            if confirmingMiseUpdate {
                miseUpdateConfirmation.padding(14)
                Divider()
            }
            if snapshotMode { content } else { ScrollView { content } }
            Divider()
            footer.padding(.horizontal, 14).padding(.vertical, 10)
        }
        .frame(width: TrayPanel.size.width, height: snapshotMode ? nil : TrayPanel.size.height)
        // A login launch closes the main window before it appears, so the tray installs the opener too.
        .onAppear { MainWindow.installOpener(state, openWindow) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("BrandIcon").resizable().frame(width: 18, height: 18)
            Text("Mise Manager").font(.headline)
            Spacer()
            // Quit lives here, away from the footer's "open app" link it used to sit beside.
            Menu {
                Button("설정 열기") { open(.settings) }
                Divider()
                Button("Mise Manager 종료") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("설정 및 종료").accessibilityLabel("설정 및 종료")
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
            if let error = state.miseSelfUpdateError {
                Text("mise 업데이트 실패: \(error)").font(.callout).foregroundStyle(.red)
            }
            if summary.attention { attention }
            if onlyUpdates {
                UpdateList(state: state, items: summary.items, onMiseUpdate: requestMiseUpdate)
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
        miseCard
        if state.plugins.isEmpty {
            Text(state.toolsLoaded ? "설치된 도구가 없습니다." : "도구를 불러오는 중…").foregroundStyle(.secondary)
        }
        ForEach(state.plugins, id: \.name) { tool in
            TrayToolBlock(
                state: state, tool: tool,
                updates: summary.items.filter { $0.name == tool.name && ($0.kind == .series || $0.kind == .major) },
                open: open)
        }
    }

    /// mise itself first: short version, status, and the plugin-update count.
    private var miseCard: some View {
        let status = state.miseStatus
        let (text, tint) = Self.miseStatusText(status.key)
        let outdated = state.outdatedPluginNames.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button { open(.mise) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "shippingbox.fill")
                            .frame(width: 28, height: 28)
                            .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("mise").bold()
                            Text(MiseStatus.normalizeVersionToken(state.miseVersion) ?? state.miseVersion ?? "미확인")
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let tint { Pill(text: text, tint: tint) } else { Text(text).font(.caption).foregroundStyle(.secondary) }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("mise 자세히 보기")
                if status.canUpdate {
                    Button("업데이트", action: requestMiseUpdate)
                        .controlSize(.small).disabled(state.actionsDisabled)
                        .accessibilityLabel("mise 업데이트")
                }
            }
            if !state.misePendingReleases.isEmpty {
                Button { open(.updates) } label: {
                    Text("새 릴리스 \(state.misePendingReleases.count)개 대기 · 정책 \(state.miseMinimumReleaseAge)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("대기 중인 mise 릴리스 보기")
            }
            if outdated > 0 {
                Button { open(.updates) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "puzzlepiece.extension")
                        Text("플러그인 업데이트 \(outdated)개")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .font(.callout)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if state.pluginUpdatesError != nil {
                Text("플러그인 확인 실패 · 앱에서 확인").font(.caption).foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func requestMiseUpdate() {
        guard !state.actionsDisabled, state.miseStatus.canUpdate else { return }
        confirmingMiseUpdate = true
    }

    private var miseUpdateConfirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("mise를 업데이트할까요?").font(.headline)
            Text("\(MiseStatus.normalizeVersionToken(state.miseVersion) ?? "현재 버전") → \(MiseStatus.normalizeVersionToken(state.miseEligibleVersion) ?? "업데이트 후보")")
                .font(.callout.monospaced())
            Text("설치된 도구와 전역 버전 설정은 유지합니다.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("취소") { confirmingMiseUpdate = false }
                Button("업데이트 실행") {
                    confirmingMiseUpdate = false
                    Task { await state.confirmMiseSelfUpdate() }
                }
                .disabled(state.actionsDisabled || !state.miseStatus.canUpdate)
                .accessibilityLabel("mise 업데이트 실행")
            }
        }
    }

    static func miseStatusText(_ key: MiseStatusKey) -> (String, Color?) {
        switch key {
        case .upToDate: ("최신", nil)
        case .updateAvailable: ("업데이트 가능", .orange)
        case .releaseWaiting: ("새 릴리스 대기", .orange)
        case .checkFailed: ("확인 실패", .red)
        case .loading: ("확인 중", nil)
        case .updating: ("업데이트 중", nil)
        case .notChecked: ("비교 불가", nil)
        case .aheadOrCustom: ("커스텀 빌드", nil)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if checking { ProgressView().controlSize(.small) }
            footerStatus.font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            Button("앱 열기 ↗") { open(.updates) }.buttonStyle(.link)
        }
    }

    /// Progress while busy, otherwise how long ago the tools were checked (exact time on hover).
    @ViewBuilder private var footerStatus: some View {
        if checking {
            Text(state.progressLabel)
        } else if let date = state.toolsCheckedDate {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(context.date.timeIntervalSince(date) < 60 ? "방금 확인"
                     : "\(date.formatted(.relative(presentation: .numeric).locale(Locale(identifier: "ko_KR")))) 확인")
            }
            .help(state.toolsCheckedAt ?? "")
        } else {
            Text("업데이트 확인 전")
        }
    }

    private func open(_ tab: ActiveTab, name: String? = nil) {
        close()
        Task { await state.run(.open(tab: tab, name: name)) }
    }
}

/// One tool: a summary row, its pending series/major updates with their actions, and on demand the
/// installed versions by major line with global switching and confirmed deletion.
private struct TrayToolBlock: View {
    var state: AppState
    let tool: PluginRow
    let updates: [UpdateItem]
    let open: (ActiveTab, String?) -> Void
    @State private var expanded = false
    /// Versions awaiting the inline delete confirmation: one row's version, or a whole clean-up.
    @State private var deleting: [String] = []

    private var checking: Bool { state.toolActionsDisabled(tool.name) }
    private var groups: [InstalledVersionGroup] { ToolStatus.versionGroups(tool) }
    private var cleanup: [String] { ToolStatus.cleanupCandidates(tool) }
    private var superseded: Int { groups.flatMap(\.versions).filter(\.isSuperseded).count }
    /// Re-validated on every render: a version that vanished or became global is never deleted.
    private var pendingDelete: [String] {
        deleting.filter { tool.installedVersions.contains($0) && $0 != tool.activeGlobalVersion }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                deleting = []
                withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    ToolGlyph(name: tool.name)
                    VStack(alignment: .leading, spacing: 2) {
                        ToolTitle(name: tool.name)
                        summaryLine
                    }
                    Spacer()
                    status
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(tool.name) \(ToolStatus.label(tool))")

            // One compact line per pending update, under the tool it belongs to.
            ForEach(updates) { item in updateLine(item) }

            if let operation = state.toolOperations[tool.name] {
                Text(operation).font(.caption).foregroundStyle(.secondary).padding(.leading, 38)
            }

            if expanded { versions }
        }
        .padding(.vertical, 2)
    }

    private var summaryLine: some View {
        HStack(spacing: 4) {
            if let global = tool.activeGlobalVersion {
                Text("전역 \(global)").lineLimit(1).truncationMode(.middle)
            } else {
                Text("전역 미선택").foregroundStyle(.orange)
            }
            Text("· 설치 \(tool.installedVersions.count)개")
            if superseded > 0 { Text("· 구버전 \(superseded)개") }
        }
        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
    }

    /// The installed versions in their own inset panel, so they never read as the next tool's rows.
    private var versions: some View {
        let showSeries = groups.contains { $0.major != nil }
        return VStack(alignment: .leading, spacing: 8) {
            if tool.installedVersions.isEmpty {
                Text("설치된 버전이 없습니다.").font(.caption).foregroundStyle(.secondary)
            } else if tool.installedVersions.contains(where: { $0 != tool.activeGlobalVersion }) {
                Text("전역으로 쓸 버전을 선택하세요").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(group.versions.enumerated()), id: \.element.id) { index, item in
                        versionRow(
                            item, series: showSeries ? (index == 0 ? group.major.map { "\($0).x" } ?? "기타" : "") : nil,
                            hasSiblings: group.hasSiblings)
                    }
                }
            }
            if !pendingDelete.isEmpty { deleteConfirmation(pendingDelete) }
            HStack {
                if !cleanup.isEmpty {
                    Button("구버전 \(cleanup.count)개 정리…") { deleting = cleanup }
                        .controlSize(.small).disabled(checking)
                        .help("같은 계열에 더 새 버전이 설치된, 사용하지 않는 버전을 한 번에 삭제합니다")
                }
                Spacer()
                Button("앱에서 자세히 보기 →") { open(.updater, tool.name) }.buttonStyle(.link).font(.callout)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .padding(.leading, 38)
    }

    /// A radio row: the global version is the selected one, any other switches on click.
    private func versionRow(_ item: InstalledVersion, series: String?, hasSiblings: Bool) -> some View {
        HStack(spacing: 8) {
            if let series {
                Text(series).font(.caption.monospaced().bold()).foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .leading)
            }
            Button {
                guard !item.isGlobal else { return }
                Task { await state.run(.use(name: tool.name, version: item.version)) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: item.isGlobal ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(item.isGlobal ? Color.accentColor : .secondary)
                    Text(item.version).font(.callout.monospaced()).lineLimit(1).truncationMode(.middle)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(checking && !item.isGlobal)
            .help(item.isGlobal ? "현재 전역 버전" : "\(tool.name) \(item.version)을 전역으로 사용")
            .accessibilityLabel(item.isGlobal ? "\(tool.name) \(item.version) 전역 사용 중" : "\(tool.name) \(item.version) 전역으로 사용")
            VersionBadges(version: item, hasSiblings: hasSiblings)
            Spacer(minLength: 4)
            if let size = state.diskSize(tool, [item.version]) {
                Text(DeleteCopy.size(size)).font(.caption.monospacedDigit()).foregroundStyle(.tertiary).fixedSize()
            }
            Button { deleting = [item.version] } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .disabled(checking || item.isGlobal)
                .opacity(item.isGlobal ? 0 : 1)
                .help("\(tool.name) \(item.version) 삭제")
                .accessibilityLabel("\(tool.name) \(item.version) 삭제")
                .accessibilityHidden(item.isGlobal)
        }
    }

    private func deleteConfirmation(_ versions: [String]) -> some View {
        let unused = ToolStatus.isUnused(tool, versions)
        return VStack(alignment: .leading, spacing: 6) {
            Text(DeleteCopy.title(tool.name, versions)).font(.callout.bold())
            if versions.count > 1 { Text(versions.joined(separator: ", ")).font(.caption.monospaced()) }
            Text(DeleteCopy.note(unused)).font(.caption).foregroundStyle(unused == false ? .orange : .secondary)
            HStack {
                if let size = state.diskSize(tool, versions) {
                    Text("\(DeleteCopy.size(size)) 확보").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("취소") { deleting = [] }
                Button(versions.count == 1 ? "삭제" : "\(versions.count)개 삭제", role: .destructive) {
                    deleting = []
                    Task { await state.deleteInstalledVersions(tool.name, versions) }
                }
                .disabled(checking)
                .accessibilityLabel("\(tool.name) \(versions.joined(separator: ", ")) 삭제 실행")
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func updateLine(_ item: UpdateItem) -> some View {
        let switches = item.kind == .series && state.seriesUpdateSwitchesGlobal(tool, item.to)
        let series = item.kind == .major ? "새 major" : Version.major(of: item.to).map { "\($0).x" } ?? ""
        let action = item.kind == .major ? "검토…" : (switches ? "설치·전환" : "설치")
        let hint = item.kind == .major ? "호환성 확인이 필요해 앱에서 검토합니다"
            : (switches ? "설치 후 전역 기본값을 이 버전으로 전환합니다" : "설치만 하고 전역 기본값은 유지합니다")
        return HStack(spacing: 8) {
            Text(series).font(.caption.bold()).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
            HStack(spacing: 4) {
                Text(item.from)
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                Text(item.to).bold()
            }
            .font(.callout.monospaced())
            Spacer()
            Button(action) { Task { await state.run(.apply(id: item.id)) } }
                .controlSize(.small)
                .disabled(checking)
                .help(hint)
                .accessibilityLabel("\(tool.name) \(series) \(item.to) \(action)")
        }
        .padding(.leading, 38)
    }

    /// Pills only for states that need attention; everything else stays quiet text.
    @ViewBuilder private var status: some View {
        let label = ToolStatus.label(tool)
        switch tool.status {
        case .error: Pill(text: label, tint: .red)
        default:
            if !updates.isEmpty, tool.status == .done {
                Pill(text: "업데이트 \(updates.count)", tint: .orange)
            } else {
                Text(label == Strings.ToolStatus.latestStable ? "최신" : label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
