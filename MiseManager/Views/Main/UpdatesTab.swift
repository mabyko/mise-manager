import MiseCore
import SwiftUI

struct UpdatesTab: View {
    var state: AppState
    private var summary: UpdateSummary { state.updateSummary }

    var body: some View {
        Page {
            if !summary.errors.isEmpty {
                ErrorCard(title: "일부 항목을 확인하지 못했습니다.") {
                    ForEach(summary.errors, id: \.self) { Text("• \($0)").foregroundStyle(.secondary).textSelection(.enabled) }
                }
            } else if summary.attention {
                Text(state.updateCheckRunning ? "최신 버전을 확인하고 있습니다." : "미확인 항목이 있습니다. 업데이트 확인을 눌러 주세요.")
                    .foregroundStyle(.secondary)
            }
            UpdateList(state: state, items: summary.items)
            if summary.items.isEmpty, !summary.attention, !state.busy {
                Card {
                    Text("확인된 업데이트가 없습니다.").font(.title3.bold())
                    Text("설치된 모든 버전 계열을 확인했습니다.").foregroundStyle(.secondary)
                }
            }
            if !summary.items.isEmpty {
                Text("각 계열의 새 버전을 따로 설치할 수 있습니다. 전역 전환 여부는 항목에 표시됩니다.").font(.callout).foregroundStyle(.secondary)
            }
            if let result = state.pluginUpdateResult { Text(result) }
        }
        .navigationTitle("업데이트 \(summary.items.count)")
        .navigationSubtitle("도구 · mise · 플러그인")
        .toolbar {
            ToolbarItem {
                Button(state.updateCheckRunning ? "전체 확인 중…" : "업데이트 확인") { Task { await state.run(.check) } }
                    .disabled(state.actionsDisabled || !state.miseIsInstalled)
            }
        }
    }
}
