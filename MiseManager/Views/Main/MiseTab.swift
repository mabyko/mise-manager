import MiseCore
import SwiftUI

struct MiseTab: View {
    var state: AppState
    @Environment(\.openURL) private var openURL

    private let officialURL = URL(string: "https://mise.jdx.dev/getting-started.html")!
    private var status: MiseStatusSnapshot { state.miseStatus }
    private var current: String {
        if let error = state.miseCurrentError { return "Error: \(error)" }
        return state.miseLoaded ? (state.miseVersion ?? "Unknown") : "Not loaded"
    }
    private var latest: String {
        if let error = state.miseLatestError { return "Error: \(error)" }
        return state.miseLatestLoaded ? (state.miseLatestVersion ?? "Unknown") : "Not checked"
    }

    var body: some View {
        Page {
            if state.miseInstalledChecked, !state.miseIsInstalled { installPanel }

            Text("버전 상태").font(.title3.bold())
            Text("현재 설치된 mise 버전과 공식 최신 릴리스를 비교합니다. 외부 플러그인 업데이트는 플러그인 관리에서 따로 선택합니다. Homebrew 등 패키지 관리자로 설치해 자체 업데이트를 지원하지 않는 경우에는 해당 패키지 관리자로 업데이트하세요.")
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                summaryCard("현재 버전", current, "local: mise --version")
                summaryCard("최신 릴리스", latest, "공식 최신 릴리스")
                summaryCard("상태", status.label, state.miseLatestCheckedAt ?? "Not checked")
            }
            Card {
                Text("상태 안내: ").bold() + Text(status.description)
            }
            if !state.miseLastResult.isEmpty { resultCard(state.miseLastResult) }
        }
        .navigationTitle("mise 관리")
        .navigationSubtitle("mise 자체 버전과 설치 상태, 실행 기록")
        .toolbar {
            ToolbarItemGroup {
                Button("현재 버전 확인") { Task { await state.reloadMiseVersion() } }.disabled(state.busy)
                Button("최신 버전 확인") { Task { await state.checkLatestMiseRelease() } }.disabled(state.busy)
                Button("mise 업데이트…") { state.openMiseUpdateDialog() }
                    .help(status.buttonHint)
                    .disabled(state.busy || !status.canUpdate)
            }
        }
    }

    private var installPanel: some View {
        Card(tint: .orange) {
            Text("mise를 찾지 못했습니다").font(.title3.bold())
            Text("mise가 설치되어 있지 않습니다. 아래 방법 중 하나로 설치할 수 있습니다.").foregroundStyle(.secondary)
            if state.miseInstalling {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Installing mise...").bold() }
                if !state.miseLastResult.isEmpty { resultCard(state.miseLastResult) }
            } else {
                HStack {
                    Button("Quick Install (sh)") { Task { await state.startMiseInstall(.sh) } }.buttonStyle(.borderedProminent)
                    Button("Homebrew Install") { Task { await state.startMiseInstall(.brew) } }.buttonStyle(.borderedProminent)
                    Button("공식 설치 안내") { openURL(officialURL) }
                }
                .disabled(state.busy)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Install (sh): ").bold() + Text("curl https://mise.run | sh").font(.body.monospaced())
                    Text("Homebrew: ").bold() + Text("brew install mise").font(.body.monospaced())
                }
                .font(.callout)
            }
        }
    }

    private func summaryCard(_ title: String, _ value: String, _ hint: String) -> some View {
        Card {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).textSelection(.enabled)
            Text(hint).font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func resultCard(_ text: String) -> some View {
        Card {
            Text(text).font(.callout.monospaced()).textSelection(.enabled)
        }
    }
}
