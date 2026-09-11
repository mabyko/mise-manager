import MiseCore
import SwiftUI

struct LogsTab: View {
    var state: AppState

    var body: some View {
        Page {
            Text(state.logs.isEmpty ? "로그가 없습니다." : state.logs.joined(separator: "\n"))
                .font(.callout.monospaced())
                .textSelection(.enabled)
        }
        .navigationTitle("작업 기록")
        .navigationSubtitle("버전 확인과 실행 결과를 확인합니다")
        .toolbar {
            ToolbarItem { Button("기록 지우기") { state.clearLogs() }.disabled(state.logs.isEmpty) }
        }
    }
}
