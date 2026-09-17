import MiseCore
import SwiftUI

/// Menu-bar quick view (was TrayApp.svelte). Observes the same AppState as the main window.
struct TrayPanelView: View {
    var state: AppState
    let close: () -> Void
    @State private var onlyUpdates = false
    @State private var confirmingMiseUpdate = false
    @Environment(\.snapshotMode) private var snapshotMode

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
            Text("\(MiseStatus.normalizeVersionToken(state.miseVersion) ?? "현재 버전") → \(MiseStatus.normalizeVersionToken(state.miseLatestVersion) ?? "최신 버전")")
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

/// One tool: a summary row, its pending series/major updates with their actions, and on demand the
/// installed versions with global switching.
private struct TrayToolBlock: View {
    var state: AppState
    let tool: PluginRow
    let updates: [UpdateItem]
    let open: (ActiveTab, String?) -> Void
    @State private var expanded = false

    private var checking: Bool { state.toolActionsDisabled(tool.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() } } label: {
                HStack(spacing: 10) {
                    ToolGlyph(name: tool.name)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tool.name).bold()
                        Text("전역 \(tool.activeGlobalVersion ?? "미선택") · 설치 \(tool.installedVersions.count)개")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
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

            if expanded {
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
                    if tool.installedVersions.isEmpty { Text("설치된 버전이 없습니다.").font(.caption).foregroundStyle(.secondary) }
                    Button("앱에서 자세히 보기 →") { open(.updater, tool.name) }.buttonStyle(.link).font(.callout)
                }
                .padding(.leading, 38)
            }
        }
        .padding(.vertical, 2)
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

    @ViewBuilder private var status: some View {
        let label = ToolStatus.label(tool)
        switch tool.status {
        case .error: Pill(text: label, tint: .red)
        case .checking, .updating, .deleting: Pill(text: label)
        default:
            if !updates.isEmpty {
                Pill(text: "업데이트 \(updates.count)", tint: .orange)
            } else if label == Strings.ToolStatus.latestStable {
                Text("최신").font(.caption).foregroundStyle(.secondary)
            } else {
                Pill(text: label)
            }
        }
    }
}
