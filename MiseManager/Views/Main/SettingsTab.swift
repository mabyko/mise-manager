import MiseCore
import ServiceManagement
import SwiftUI

struct SettingsTab: View {
    var state: AppState
    @Bindable private var settings: MiseCore.Settings
    /// The system is the source of truth (System Settings › General › Login Items can change it too).
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    init(state: AppState) {
        self.state = state
        settings = state.settings
    }

    var body: some View {
        Form {
            Section("업데이트 확인") {
                Toggle(isOn: $settings.checkOnStartup) {
                    Text("앱을 열 때 확인")
                    Text("mise, 설치된 도구의 각 major 계열, 외부 플러그인을 확인합니다.")
                }
                Picker(selection: $settings.checkIntervalHours) {
                    Text("수동으로만").tag(0)
                    Text("1시간마다").tag(1)
                    Text("6시간마다").tag(6)
                    Text("24시간마다").tag(24)
                } label: {
                    Text("자동 확인 주기")
                    Text("앱이 실행 중이면 창을 닫아도 확인합니다. 설치는 직접 선택합니다.")
                }
            }
            Section {
                Toggle(isOn: $settings.switchGlobalAfterUpdate) {
                    Text("업데이트 후 전역 기본값 전환")
                    Text("현재 전역 버전과 같은 major를 업데이트할 때만 전환합니다. 다른 계열과 프로젝트 설정은 유지합니다.")
                }
                Toggle(isOn: $settings.showPrereleases) {
                    Text("프리릴리스 후보 표시")
                    Text("정식 출시 전 버전은 별도 후보로 표시합니다.")
                }
            } header: {
                Text("도구 버전")
            } footer: {
                Text("기존 버전은 항상 보존합니다. 예를 들어 Node 26과 24가 설치되어 있으면 26.x와 24.x의 최신 안정 버전을 각각 확인합니다. 설치만 한 버전은 도구 목록에서 전역으로 선택하거나 프로젝트 설정에 지정할 수 있습니다.")
            }
            Section {
                Toggle(isOn: $launchAtLogin) {
                    Text("로그인 시 시작")
                    Text("창 없이 메뉴바에만 올라옵니다. 시스템 설정 › 일반 › 로그인 항목에서도 바꿀 수 있습니다.")
                }
                .onChange(of: launchAtLogin) { _, on in
                    do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                    catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                }
                Toggle(isOn: $settings.showMenuBarIcon) {
                    Text("메뉴바 아이콘 표시")
                    Text("메뉴바에서 도구와 업데이트를 빠르게 확인합니다.")
                }
                LabeledContent {
                    Button("메뉴바 창 열기") { state.showTray() }.disabled(!settings.showMenuBarIcon)
                } label: {
                    Text("메뉴바 빠른 관리")
                    Text("작은 창에서 도구와 업데이트를 확인합니다.")
                }
                Picker(selection: $settings.theme) {
                    Text("시스템 설정").tag(Theme.system)
                    Text("라이트").tag(Theme.light)
                    Text("다크").tag(Theme.dark)
                } label: {
                    Text("테마")
                    Text("시스템 설정을 따르거나 직접 선택하세요.")
                }
            } header: {
                Text("화면")
            } footer: {
                Text(settings.showMenuBarIcon
                     ? "창을 닫으면 Dock에서는 사라지고 메뉴바에서 계속 실행됩니다. 메뉴바 창에서 다시 열거나 종료할 수 있습니다."
                     : "메뉴바 아이콘이 없으면 Dock 아이콘을 유지합니다. 창을 닫아도 앱은 계속 실행되며 Dock에서 다시 열거나 앱 메뉴의 종료를 선택할 수 있습니다.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("설정")
        .navigationSubtitle("변경 사항은 이 기기에 자동으로 저장됩니다")
    }
}
