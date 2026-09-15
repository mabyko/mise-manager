import MiseCore
import SwiftUI

extension View {
    /// The four confirmations: delete (alert-style), major update, mise self-update, plugin URL.
    func appDialogs(_ state: AppState) -> some View {
        modifier(AppDialogs(state: state))
    }
}

private struct AppDialogs: ViewModifier {
    @Bindable var state: AppState

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "설치된 버전을 삭제할까요?",
                isPresented: presented(\.pendingDelete),
                titleVisibility: .visible,
                presenting: state.pendingDelete
            ) { pending in
                Button("삭제", role: .destructive) { Task { await state.deleteInstalledVersion(pending.pluginName, pending.version) } }.disabled(state.busy)
                Button("취소", role: .cancel) { state.pendingDelete = nil }
            } message: { pending in
                Text("\(pending.pluginName)@\(pending.version)\n이 버전을 로컬에서 제거합니다. 프로젝트에서 사용 중인지 확인해 주세요. 다시 사용하려면 재설치해야 합니다.")
            }
            .sheet(isPresented: presented(\.pendingMajorUpdate)) { MajorUpdateSheet(state: state) }
            .sheet(isPresented: $state.pendingMiseUpdateConfirm) { MiseUpdateSheet(state: state) }
            .sheet(isPresented: presented(\.pendingPluginUrlDialog)) { PluginUrlSheet(state: state) }
    }

    private func presented<T>(_ keyPath: ReferenceWritableKeyPath<AppState, T?>) -> Binding<Bool> {
        Binding { state[keyPath: keyPath] != nil } set: { if !$0 { state[keyPath: keyPath] = nil } }
    }
}

private struct SheetFrame<Content: View>: View {
    let eyebrow: String?
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let eyebrow { Eyebrow(text: eyebrow) }
            Text(title).font(.title3.bold())
            content
        }
        .padding(20)
        .frame(width: 460)
    }
}

private struct MajorUpdateSheet: View {
    var state: AppState
    var body: some View {
        let pending = state.pendingMajorUpdate
        SheetFrame(eyebrow: "새 major · 호환성 확인 필요", title: "\(pending?.pluginName ?? "")의 새 major로 전환할까요?") {
            Text("\(pending?.fromVersion ?? "전역 미선택") → \(pending?.targetVersion ?? "")").font(.body.monospaced())
            Text("설치 후 전역 버전을 전환합니다. 프로젝트가 새 major를 지원하는지 확인하세요. 프로젝트별 mise 설정이 있으면 그 설정이 우선합니다.")
            Text("기존 버전은 보관됩니다. 내 도구에서 이전 버전을 다시 선택할 수 있습니다.")
            HStack {
                Spacer()
                Button("취소") { state.pendingMajorUpdate = nil }.keyboardShortcut(.cancelAction)
                Button("설치 후 전역 전환") { Task { await state.confirmMajorUpdate() } }
                    .disabled(state.busy)
            }
        }
    }
}

private struct MiseUpdateSheet: View {
    var state: AppState
    var body: some View {
        SheetFrame(eyebrow: "mise 자체 업데이트", title: "mise를 업데이트할까요?") {
            Text("\(MiseStatus.normalizeVersionToken(state.miseVersion) ?? "현재 버전") → \(MiseStatus.normalizeVersionToken(state.miseLatestVersion) ?? "최신 버전")")
                .font(.body.monospaced())
            Text("mise 실행 파일을 업데이트합니다. 설치된 도구와 전역 버전 설정은 변경하지 않습니다. Homebrew 등 패키지 관리자로 설치한 경우 해당 패키지 관리자로 업데이트해야 할 수 있습니다.")
            HStack {
                Spacer()
                Button("취소") { state.cancelMiseUpdateDialog() }.keyboardShortcut(.cancelAction)
                Button("mise 업데이트") { Task { await state.confirmMiseSelfUpdate() } }
                    .disabled(state.busy)
            }
        }
    }
}

private struct PluginUrlSheet: View {
    @Bindable var state: AppState

    private var dialog: PluginUrlDialog? { state.pendingPluginUrlDialog }
    private var isEdit: Bool { if case .edit = dialog { true } else { false } }
    private var isCustom: Bool { dialog == .customInstall }

    var body: some View {
        SheetFrame(eyebrow: nil, title: isCustom ? "사용자 플러그인 추가" : isEdit ? "플러그인 URL 수정" : "플러그인 추가") {
            if let name = dialog?.pluginName { Text("Plugin: ").bold() + Text(name) }
            Text(isCustom ? "목록에 없는 plugin definition을 이름과 Git URL로 설치합니다."
                 : isEdit ? "새 URL로 plugin definition을 재설치합니다(--force)."
                 : "비워두면 기본 registry source로 설치합니다.")
                .foregroundStyle(.secondary)
            if isCustom {
                TextField("플러그인 이름", text: $state.pendingPluginNameValue, prompt: Text("Plugin name"))
            }
            TextField("Git URL", text: $state.pendingPluginUrlValue,
                      prompt: Text(isCustom ? "https://github.com/owner/repo.git" : "https://github.com/owner/repo.git (optional)"))
                .onSubmit { submit() }
            HStack {
                Spacer()
                Button("취소") { state.closePluginUrlDialog() }.keyboardShortcut(.cancelAction)
                Button(isEdit ? "URL 저장" : "설치") { submit() }.keyboardShortcut(.defaultAction).disabled(state.busy)
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private func submit() {
        guard !state.busy else { return }
        Task { await state.submitPluginUrlDialog() }
    }
}
