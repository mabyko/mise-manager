import MiseCore
import SwiftUI

struct StatusBar: View {
    var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            if state.busy {
                ProgressView().controlSize(.small)
            } else {
                Circle().fill(.green).frame(width: 8, height: 8)
            }
            Text(state.progressLabel)
            if state.busy, !state.liveOutputLine.isEmpty {
                Text(state.liveOutputLine)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(state.liveOutputLine)
            }
            if state.busy, let progress = state.progress {
                ProgressView(value: progress, total: 100).frame(width: 120)
                Text("\(Int(progress.rounded()))%").monospacedDigit()
            }
            Spacer()
            Button("작업 기록 →") { state.activeTab = .logs }.buttonStyle(.link)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
