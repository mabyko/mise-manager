# Mise Manager SwiftUI 전환 계획서

- 작성일: 2026-09-11
- 대상: `mise-manager` 0.1.2 (Tauri 2 + Svelte 5 + Rust) → macOS 네이티브 (SwiftUI + AppKit, Swift 6)
- 상태: Phase 0–5 구현 완료(2026-09-11, §11 권장안 적용). 남은 것은 §10 수동 체크리스트 통과, Developer ID 서명·공증, `main` 머지.
- 구현이 이 문서와 다른 점: `State/`·`Features/`·`Rules/`와 기능 흐름 테스트는 앱 타깃이 아니라 `Packages/MiseCore`에 있다(UI 없이 `swift test`로 실행). `Series.swift`·`LogStore.swift`·`TrayRows`는 각각 `ToolStatus.swift`·`AppState`·`TrayPanelView.swift`에 흡수됐다. §5의 표시 이름·아이콘 분기는 `project.yml`의 구성별 설정에 있고 `Base.xcconfig`에는 번들 ID만 있다. `os.Logger`는 쓰지 않고 앱 내 작업 기록만 남긴다. 문구는 진행 라벨·상태 라벨만 `Strings.swift`에 모았고 화면 문장은 뷰에 있다. sh/brew 설치도 보강된 PATH로 실행한다. Debug 빌드에는 스크린샷·검증용 훅(`DebugHooks.swift`)이 있다. navigation·installs 렌더링 테스트 7개는 이식하지 않았다.

## 1. 결정 요약

Tauri를 택했던 이유(크로스플랫폼, 웹 UI 재사용)가 현재 요구와 맞지 않는다. 실제 사용은 macOS 메뉴바 앱이고, 남은 문제는 전부 macOS 통합(NSPanel, 투명 창의 private API, 상태 아이템 동작)에서 나온다. 네이티브로 옮기면 이 문제들이 정식 API로 풀리고, 웹뷰 두 개(메인·트레이)에 들어가는 메모리와 기동 시간이 사라진다.

바뀌는 것: 소스 전체(UI 3.4k줄, Rust 3.9k줄, 테스트 92개), 빌드 체인(bun/vite/cargo → Xcode), 배포 방식. 남는 것: 1024px 아이콘 마스터(`assets/icon.iconset`), README/CHANGELOG 구조, mise 명령 매핑, 버전 규칙, 테스트 케이스(명세로 이식), 한국어 UI 문구.

버리는 것: Windows 알파 지원, 개발용 디자인 프로토타입(variant A–G), 브라우저 프리뷰(rpcMock).

## 2. 목표와 비목표

목표

| 항목 | 기준 |
| --- | --- |
| 기능 동등성 | §10 체크리스트 전부 통과 |
| 메뉴바 UX | 비활성화 패널(NSPanel), 어느 디스플레이에서 눌러도 아이콘 아래, 바깥 클릭·Esc로 닫힘, 앱 활성화 없음 |
| 성능 | 콜드 기동 0.5초 이하, 유휴 메모리 40 MB 이하, 팝업 표시 100 ms 이하 (현재 Tauri: 웹뷰 2개, 유휴 100 MB 이상) |
| 안전성 | 검사(check)는 절대 설치하지 않음, 활성 전역 버전 삭제 거부, config.toml 형식 보존 |
| 배포 | Developer ID 서명 + 공증, App Sandbox 없음(mise/curl/brew 실행 필요) |

비목표

- App Store 배포(샌드박스에서 외부 CLI 실행 불가).
- Windows/Linux.
- 기존 설정 이전. 설정은 6개 키뿐이고 기본값이 안전하므로 첫 실행은 기본값으로 시작한다.
- 자동 업데이트(Sparkle). 필요해지면 Phase 5 이후 별도 작업.

## 3. 현재 시스템 인벤토리 (이식 대상)

### 3.1 백엔드 명령 23개

| 그룹 | 명령 | mise 호출 |
| --- | --- | --- |
| mise 본체 | getMiseVersion, getLatestMiseRelease, selfUpdateMise, checkMiseInstalled, installMiseSh, installMiseBrew, getPlatform | `mise --version`, `mise self-update -y --no-plugins`, `sh -c "curl https://mise.run \| sh"`, `brew install mise` |
| 도구 버전 | listInstalledPlugins, checkPluginUpdates, useGlobalPlugin, installPlugin, deletePluginVersion | `mise ls --installed --json`, `mise ls --global --json`, `mise ls-remote <tool> --json`, `mise use -g -y`, `mise install -y`, `mise uninstall -y` |
| 플러그인 정의 | listOutdatedPluginDefinitions, listInstalledPluginNames, listInstalledUserPluginInfos, listCorePluginNames, listInstalledToolNames, listRemotePluginNames, listRemotePluginInfos, updatePluginDefinition, installPluginDefinition, uninstallPluginDefinition | `mise plugins ls --user [--outdated\|--urls]`, `mise plugins ls --core`, `mise plugins ls-remote [--only-names\|--urls]`, `mise plugins update/install/uninstall` |
| 창/트레이 | showMainWindow, showTrayWindow, hideTrayWindow, quitApp, setTrayStatus | 없음 |

공통 규칙

- mise 경로: `MISE_BIN` → 보강된 PATH(`~/.local/bin`, `~/.mise/bin`, `~/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`)에서 첫 존재 파일 → `mise`. 절대경로만 캐시, 없으면 매번 재탐색(앱 내 설치 후 감지).
- 서브프로세스 stdout/stderr를 줄 단위로 스트리밍(`mise-output` 이벤트). 타임아웃 없음.
- 오류는 stderr 정리본 또는 지정한 대체 문구.
- 최신 릴리스: `https://mise.jdx.dev/VERSION` 우선, 실패 시 GitHub `releases/latest`의 `tag_name`. UA `mise-manager`, 20초.

### 3.2 순수 로직 (테스트가 명세)

| 모듈 | 내용 | 기존 테스트 |
| --- | --- | --- |
| Version | 숫자 파트 비교, 프리릴리스 판정(`a/alpha/b/beta/rc/pre/preview/dev/test`, 소문자), python/ruby만 안정판 필터, major 추출, 최신 선택, 비semver는 자연 정렬 | TS 8 + Rust 8 |
| UpdatePlanner (`plan_plugin_update`) | 원격 목록 → releaseLatest / preReleaseLatest / overallLatest / latestByMajor / sameMajorLatest, checkedVersions | Rust 6 |
| Catalog 파서 | ls-remote JSON(문자열/객체)·plain 폴백, plugins 테이블, `--outdated`의 "up to date" stderr 구분 | Rust 5 |
| ConfigEditor | `~/.config/mise/config.toml`(또는 `$XDG_CONFIG_HOME`)의 `[tool_alias]`만 수정, 주석·형식 보존, 잘못된 TOML이면 중단 | Rust 6 |
| 상태 규칙 | miseStatus 8단계 결정표, toolStatus 라벨 10종, updateSummary(items/errors/attention), 플러그인 URL 정규화 | vitest 24 |
| 기능 흐름 | updater(동시성 4, 성공/실패 후 재조회, 전역 전환 조건), installs(설치 계획 invalid/skip/install), updates(중복 검사 방지), runtime(트레이 액션 재검증) | vitest 31 |

### 3.3 화면

메인 창 1200×820(최소 720×560): 사이드바(검색, 업데이트 카운트, 설치된 도구 목록, 관리 메뉴, 설정) + 탭 6개(`updater`, `updates`, `mise`, `installs`, `logs`, `settings`) + 상태바(진행률, 실시간 출력 줄) + 다이얼로그 4개(삭제, major 전환, mise 업데이트, 플러그인 URL 3모드).

메뉴바 팝업 440×620: 헤더(⚙), 탭 "내 도구 / 업데이트 N / ↻", 주의 배너, 도구별 계열 행 + 버전 전환, mise·플러그인 요약, 푸터(상태, 종료, 앱 열기). Esc로 닫힘.

메뉴바 아이콘: 템플릿 이미지(가로선 3개), 제목 `…`/`N`/`!`/빈값, 빨간 점 배지(검사 중엔 마지막 배지 유지), 툴팁 `Mise Manager · 업데이트 N개 · 상태`, 표시 여부 설정.

### 3.4 상태와 설정

- 앱 상태 47개 필드(도구 행, mise 버전/최신/오류/시각, 플러그인 카탈로그, 진행률, 다이얼로그 pending 값 등). 트레이에는 그중 24개만 공유.
- 설정 6개: `showMenuBarIcon`(true), `checkOnStartup`(true), `checkIntervalHours`(0 | 1 | 6 | 24), `theme`(system/light/dark), `showPrereleases`(false), `switchGlobalAfterUpdate`(false). 저장 실패 시 세션 한정 적용 안내.
- 로그: 메모리 150줄, 시각 접두어 `ko-KR` 24시간제.

## 4. 타깃 아키텍처

| 항목 | 선택 | 이유 |
| --- | --- | --- |
| 최소 macOS | 14 (Sonoma) | `@Observable`, `MenuBarExtra` 개선판, `NavigationSplitView` 안정. 개발 환경은 Xcode 26.6 / Swift 6.3 |
| UI | 메인 창: SwiftUI. 메뉴바: AppKit(`NSStatusItem` + `NSPanel` + `NSHostingView`) | SwiftUI `MenuBarExtra(.window)`는 닫힘·포커스 제어가 약해 네이티브 앱들도 AppKit로 내려감 |
| 상태 | 단일 `@Observable AppState` (현재 `state.svelte.ts`와 1:1) | 트레이 뷰가 같은 객체를 직접 관찰하므로 main↔tray 메시지 브리지(`runtime-message`) 전체가 사라짐 |
| 동시성 | `actor MiseCLI` + `AsyncStream<OutputLine>` | 스트리밍 출력, 취소, Swift 6 엄격 동시성 통과 |
| 모델 | `Codable` 구조체 (contracts.rs 그대로) | `mise --json` 파싱 |
| 네트워크 | `URLSession` | 의존성 0 |
| 설정 | `UserDefaults` + `@AppStorage` | 6개 키 |
| 로깅 | `os.Logger` (debug 빌드 콘솔) | tauri-plugin-log 대체 |
| 테스트 | Swift Testing (`@Test`) | XCTest보다 짧고 병렬 기본 |
| 외부 의존성 | 없음 | TOML 편집은 §7 참고 |

패키지 구조

```
MiseManager.xcodeproj
Packages/MiseCore/            # SwiftPM, UI 없음, 테스트 대부분 여기
  Sources/MiseCore/
    CLI/       MiseCLI.swift (actor), PathResolver.swift, OutputLine.swift
    Model/     PluginSummary, PluginUpdateInfo, PluginDefinitionInfo, UpdateResult, ...
    Version/   Version.swift (compare, prerelease, major, pickLatest)
    Planner/   UpdatePlanner.swift (plan_plugin_update), Series.swift (major별 계열)
    Catalog/   Parsers.swift
    Config/    ToolAliasEditor.swift
    Release/   ReleaseChecker.swift (VERSION → GitHub 폴백)
  Tests/MiseCoreTests/        # Rust 27 + version.ts 8 + utils 5 이식
MiseManager/                  # 앱 타깃
  App/         MiseManagerApp.swift, AppDelegate.swift
  State/       AppState.swift, Settings.swift, LogStore.swift
  Features/    Updater.swift, Installs.swift, MiseSelf.swift, Updates.swift
  Rules/       MiseStatus.swift, ToolStatus.swift, UpdateSummary.swift
  Views/       Main/ (Sidebar, UpdaterTab, UpdatesTab, MiseTab, InstallsTab, LogsTab, SettingsTab, StatusBar)
               Dialogs/ (Delete, MajorUpdate, MiseUpdate, PluginUrl)
               Tray/ (TrayPanelView, TrayRows)
  MenuBar/     StatusItemController.swift, BadgeView.swift, TrayPanel.swift (NSPanel), PanelPositioner.swift
  Resources/   Assets.xcassets (AppIcon, AppIcon-Dev, app-icon), Localizable.xcstrings(선택)
MiseManagerTests/             # 기능 흐름 vitest 31개 이식 (FakeCLI 사용)
Config/                       # Base.xcconfig(추적: 희생용 ID, Debug 표시 이름·아이콘 분기), Local.xcconfig(무시: 개인 ID·팀)
docs/, assets/, README*.md, CHANGELOG.md, LICENSE
```

## 5. 번들 ID·서명 가드레일

`apple-bundle-id-guardrails` 규칙을 그대로 따른다. App ID는 Apple 개발자 프로그램 전체에서 유일하고, 자동 서명이 한 번 등록해 버리면 되돌리기 어렵다.

원칙

- 정식 ID `com.mabyko.misemanager`는 조직 팀이 포털에 등록하기 전까지 어떤 활성 빌드·서명 설정에도 넣지 않는다. 문서와 주석은 예외.
- 추적 파일에는 희생용 ID `forked.misemanager.local`만 있고 `DEVELOPMENT_TEAM`은 없다. `project.pbxproj`도 마찬가지.
- 개인 ID는 Release `com.mabyko.misemanager.epilo9er`, Debug `com.mabyko.misemanager.epilo9er.dev`. Release 값이 지금 설치된 Tauri 앱과 같아서 교체 설치가 그대로 된다.
- Debug는 표시 이름 `Mise Manager Dev`로 나란히 설치한다. `UserDefaults` 도메인(`~/Library/Preferences/<bundle-id>.plist`)이 ID별로 갈리므로 개발 중 설정이 릴리스 설정을 덮지 않는다. 이 앱은 TCC 권한을 요구하지 않지만 같은 분리 원칙이 적용된다.

파일

```xcconfig
// Config/Base.xcconfig (추적)
MISEMANAGER_BUNDLE_ID = forked.misemanager.local
APP_DISPLAY_NAME = Mise Manager
APP_DISPLAY_NAME[config=Debug] = Mise Manager Dev
INFOPLIST_KEY_CFBundleDisplayName = $(APP_DISPLAY_NAME)
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
ASSETCATALOG_COMPILER_APPICON_NAME[config=Debug] = AppIcon-Dev
#include? "Local.xcconfig"

// Config/Local.xcconfig (git-ignored, 개발자별)
MISEMANAGER_BUNDLE_ID = com.mabyko.misemanager.epilo9er
MISEMANAGER_BUNDLE_ID[config=Debug] = com.mabyko.misemanager.epilo9er.dev
DEVELOPMENT_TEAM = <인증서 subject의 OU 값>
```

- 프로젝트 설정은 `PRODUCT_BUNDLE_IDENTIFIER = $(MISEMANAGER_BUNDLE_ID)`, `CODE_SIGN_STYLE = Automatic`. 설정 이름을 제품명으로 붙여 다른 xcconfig와 충돌하지 않게 한다.
- 팀 ID는 인증서 subject의 `OU`에서 읽는다. 인증서 이름 괄호 안 값(`HB5BHG995V`)은 팀 멤버 ID라 쓰면 안 된다. 현재 설치본 서명 기준 팀 ID는 `9XPNA8Q9C3`.

```sh
security find-certificate -c "Apple Development: epilo9er@icloud.com" -p | openssl x509 -noout -subject
```

- 워크트리와 CI에는 `Local.xcconfig`가 없어 희생용 ID로 빌드된다. 정상 동작이다. 개인 빌드가 필요하면 메인 체크아웃의 파일을 심링크한다.

```sh
ln -s /Users/eugene/Codes/mabyko/mise-manager/Config/Local.xcconfig Config/Local.xcconfig
```

검증

- `git check-ignore Config/Local.xcconfig`가 무시됨을 출력.
- Debug와 Release 각각 `xcodebuild -showBuildSettings`에서 `PRODUCT_BUNDLE_IDENTIFIER`, `APP_DISPLAY_NAME`, `ASSETCATALOG_COMPILER_APPICON_NAME`이 서로 다른 값.
- 추적 파일(`project.pbxproj`, `*.xcconfig`, `*.plist`, `*.entitlements`, CI 설정)에서 `com.mabyko`와 `DEVELOPMENT_TEAM`을 검색해 활성 설정 0건. Xcode의 Signing & Capabilities UI를 만진 뒤에는 다시 검사한다.

조직 팀 인수 체크리스트

1. 정식 App ID 목록 확정. 이 앱은 확장·위젯이 없어 1개.
2. 조직 팀 포털 Identifiers에 등록.
3. 그 뒤에만 릴리스 설정에 정식 ID를 넣고, 개인 suffix ID는 로컬 개발용으로 유지.

`An App ID with Identifier … is not available`이 나오면 그 ID는 이미 어느 팀에 등록된 것이다. 소유 팀에서 삭제해 해제하고, 개인 팀이면 그 ID는 포기하고 다른 suffix를 쓴다.

## 6. 앱 아이콘

`apple-app-icon-generator` 워크플로를 따른다.

- 원본: `assets/icon.iconset/icon_512x512@2x.png`(1024×1024)가 릴리스 마스터. 편집 가능한 벡터 원본은 없으므로 기존 글리프와 색을 유지한 채 이 파일에서 파생한다.
- 변형 수: §5에서 Debug와 Release가 다른 번들 ID로 나란히 설치되므로 2종. `AppIcon`(릴리스)과 `AppIcon-Dev`. Dev는 마스터의 글리프와 구도를 유지하고 배지·틴트·테두리 중 하나만 더해 한눈에 구분되게 한다.
- 설치: `Assets.xcassets`의 두 `.appiconset`에 마스터에서 파생한 크기만 채운다. 크기별 개별 생성은 하지 않는다. 배선은 §5의 `ASSETCATALOG_COMPILER_APPICON_NAME` 분기.
- 메뉴바 아이콘은 앱 아이콘과 별개다. SF Symbol `line.3.horizontal` 템플릿을 쓰고 빨간 점 배지는 코드로 그린다(§3.3).
- 사이드바와 팝업 헤더의 브랜드 아이콘(현재 `app-icon.png` 128px)도 마스터에서 다시 뽑는다.
- 검증: Debug·Release 빌드 모두 asset catalog 경고 0건. 두 마스터와 16/32px 미리보기를 나란히 놓고 글리프 식별, Dev 표식 구분, 클리핑 없음을 확인한다.
- 정리: `src-tauri/icons/`의 Windows·Android·iOS 세트는 Phase 5에서 삭제한다. `icon.icns`는 Xcode가 생성하므로 필요 없다.

## 7. 구성요소 매핑

| 현재 | 전환 후 | 비고 |
| --- | --- | --- |
| `tauri::command` 23개 + `rpc.ts` Proxy | `MiseCore` 공개 함수 직접 호출 | IPC·직렬화 계층 제거 |
| `mise.rs` 프로세스 러너 + `mise-output` 이벤트 | `actor MiseCLI`, `AsyncStream` | GUI 앱은 PATH가 비어 있으므로 폴백 디렉터리 로직 그대로 이식 |
| `toml_edit` | 자체 `ToolAliasEditor` (줄 단위, `[tool_alias]` 섹션만) | Swift TOML 라이브러리는 형식 보존 불가. 기존 Rust 테스트 6개가 명세 |
| `reqwest` | `URLSession` | 20초 타임아웃, UA 유지 |
| `state.svelte.ts` `$state` | `@Observable final class AppState` | 필드 1:1 |
| `runtime.svelte.ts` (main↔tray 동기화, 액션 재검증) | 삭제. 트레이 뷰가 `AppState` 직접 사용. 액션 재검증 로직은 `Features`의 가드로 유지 | 코드 130줄 → 0 |
| `settings.svelte.ts` localStorage | `UserDefaults` | 키 이름 유지(`mise-manager.*`) |
| Svelte 컴포넌트 12개 | SwiftUI 뷰 | 문구·동작 동일, 레이아웃은 macOS HIG 기준 |
| `dialog.ts` `<dialog>` | `.sheet` / `.confirmationDialog` | |
| `inputShortcuts.ts` (Cmd+A 폴백) | 삭제 | 네이티브 텍스트 필드가 처리 |
| `App.svelte` 테마 `data-theme` | `.preferredColorScheme` | |
| 주기 검사 `setInterval` | `Timer` 또는 `Task.sleep` 루프 | 앱 상태 객체 소유 |
| `tray.rs` 상태 아이템·위치 계산 | `StatusItemController`, `PanelPositioner` | 커서 기준 디스플레이 선택 로직 유지(§8) |
| `tray/badge.rs` (objc2) | `BadgeView: NSView` | 거의 그대로 Swift로 |
| 트레이 아이콘 비트맵 | SF Symbol `line.3.horizontal` 템플릿 | 코드 생성 제거 |
| `tauri-plugin-opener` | `NSWorkspace.shared.open` | |
| vitest 65 + cargo test 27 | Swift Testing | 이름·의도 1:1 |
| bun/vite/cargo/`tauri build` | `xcodebuild`, `notarytool` | |

## 8. 리스크와 대응

| 리스크 | 영향 | 대응 |
| --- | --- | --- |
| config.toml 형식 보존 | 사용자의 주석·정렬이 깨지면 신뢰 상실 | 전체 파서 대신 `[tool_alias]` 섹션만 줄 단위로 편집. 잘못된 TOML이면 중단. 기존 6개 테스트 + 실제 config 샘플 회귀 |
| GUI 앱의 빈 PATH | mise를 못 찾음 | `PathResolver`에 폴백 디렉터리 + `MISE_BIN` 이식, 로그인 셸 실행은 하지 않음(느리고 부작용) |
| Swift 6 엄격 동시성과 `Process`/`Pipe` | 컴파일 오류·데드락 | `MiseCLI`를 actor로 격리, `readabilityHandler` 대신 `FileHandle.bytes.lines` 사용 |
| 상태 아이템 창이 화면 밖(Thaw 등 메뉴바 정리 앱, 노치 오버플로) | 팝업이 엉뚱한 화면에 표시 | Tauri에서 이미 검증한 규칙 이식: 클릭 시점 커서로 디스플레이 선택, 아이콘 좌표는 그 디스플레이 안에 있을 때만 사용 |
| macOS 26 Control Center 프록시 클릭 | `statusItem.menu`가 있으면 팝업 위에 메뉴가 겹침 | 메뉴 없이 `button.action`만 사용, 종료·열기는 팝업 안에 |
| 공증 없는 배포 | Gatekeeper 경고 | Developer ID 인증서 필요(현재 키체인엔 Apple Development만 있음). 없으면 로컬 설치용 서명으로 Phase 5까지 진행 |
| 한국어·영어 혼재 문구 | 이식 중 누락 | `Strings.swift` enum으로 모으고, 영어로 남아 있던 진행 라벨(`Checking updates` 등)은 한국어로 통일 |
| 두 번째 재작성 피로 | 중도 포기 시 유지보수 대상 2개 | Tauri 최종본 태그 고정, Phase 1–2(코어·로직)를 먼저 끝내 UI 이전에 테스트로 동등성 확보 |

## 9. 단계별 계획

예상 공수는 한 명이 집중 작업할 때 기준이다. 병렬로 하면 Phase 2와 4는 Phase 1 뒤에 동시에 갈 수 있다.

| Phase | 산출물 | 완료 기준 | 공수 |
| --- | --- | --- | --- |
| 0. 준비 | `v0.1.2-tauri` 태그, `swiftui` 브랜치, Xcode 프로젝트 골격, §5의 `Config/Base.xcconfig`와 무시되는 `Local.xcconfig`, §6의 `AppIcon`/`AppIcon-Dev` 세트, `xcodebuild test` 스크립트 | `Local.xcconfig` 없이 희생용 ID로 빌드되고, 있으면 Debug/Release가 다른 ID·이름·아이콘으로 나란히 설치된다. 테스트 타깃이 돈다 | 1일 |
| 1. 코어 | `MiseCore` 전 모듈 | Rust 27 + TS 13개 테스트 이식 통과. 실제 mise로 `ls --json` 파싱·스트리밍 확인 | 2–3일 |
| 2. 상태·기능 | `AppState`, `Features`, `Rules` | vitest 31개(updater/installs/updates/runtime/miseStatus/toolStatus) 이식 통과. `FakeCLI`로 실행 | 2–3일 |
| 3. 메인 창 | 사이드바, 탭 6개, 다이얼로그 4개, 상태바, 설정 | §10 체크리스트의 메인 창 항목 수동 통과. 다크/라이트/시스템 테마 | 3–4일 |
| 4. 메뉴바 | `StatusItemController`, 배지, `TrayPanel`, 팝업 뷰 | 두 디스플레이 모두 아이콘 아래 표시, 앱 비활성 상태 유지, 바깥 클릭·Esc 닫힘, 배지 규칙 4종, 표시 설정 | 2일 |
| 5. 마감·배포 | 서명·공증, DMG, README/CHANGELOG, Tauri 소스·불필요 아이콘 세트 제거, 번들 ID 감사(§5 검증), 0.2.0 | `main`에 머지, 이전 앱 제거 후 새 앱으로 일주일 사용, 추적 파일에 조직 네임스페이스·팀 ID 없음 | 1–2일 |

합계 11–15 작업일. 달력 기준 2–3주.

Phase 5의 삭제 목록: `src/`, `src-tauri/`, `package.json`, `bun.lock`, `node_modules/`, `dist/`, `vite.config.ts`, `vitest.config.ts`, `tsconfig.json`. `src-tauri/icons/icon.icns`는 `Assets.xcassets`로 옮긴 뒤 삭제.

## 10. 기능 동등성 체크리스트

메인 창

- [ ] 시작 시 mise 설치 여부 확인, 미설치면 mise 탭으로 이동하고 sh/Homebrew 설치 제공(설치 후 2초 뒤 재확인)
- [ ] 시작 시 검사(설정), 주기 검사 0/1/6/24시간
- [ ] 사이드바 검색이 탭 전환·업데이트 후에도 유지
- [ ] 업데이트 카운트 배지: 검사 중 `…`, 개수, 미확인 `!`
- [ ] 도구 상세: 계열 카드(설치 / 설치+전환), 설치된 버전(전역 사용 / 삭제), 새 major 안내, 프리릴리스 후보(설정)
- [ ] 활성 전역 버전은 삭제 버튼 없음, 백엔드도 거부
- [ ] 계열 업데이트는 기본 설치만, `switchGlobalAfterUpdate`일 때만 전환. 다른 major의 전역은 건드리지 않음
- [ ] 설치 실패 시 전환 중단, 전환 실패 시 설치본은 남김, 성공/실패 후 mise 재조회
- [ ] 업데이트 모아보기: 계열/major/mise/플러그인 항목, 오류 목록, 주의 배너
- [ ] mise 탭: 현재/최신/상태 카드, 8단계 상태 문구, self-update 확인 다이얼로그, 결과 Before/After/STDOUT/STDERR, 재시작 필요 표시
- [ ] 플러그인 관리: 설치됨/사용 가능 테이블, 검색, 사용자 플러그인 추가(URL), URL 수정(`--force`), 제거, 소스 업데이트 확인·적용, 200행 제한
- [ ] `owner/repo` 축약 → GitHub URL, 원격 기본 URL과 같으면 tool_alias 제거
- [ ] 작업 기록 150줄, 지우기
- [ ] 설정 6개 저장·복원, 잘못된 값은 기본값
- [ ] 실시간 서브프로세스 출력 줄 표시
- [ ] 닫기 버튼은 숨김, Dock 클릭으로 다시 표시

메뉴바

- [ ] 아이콘 표시 설정 즉시 반영
- [ ] 제목 `…`/`N`/`!`/빈값, 툴팁 문구, 빨간 점(검사 중엔 유지)
- [ ] 내장·외장 어느 화면에서 눌러도 그 화면의 아이콘 아래
- [ ] 앱을 활성화하지 않음(메인 창이 딸려 올라오지 않음)
- [ ] 바깥 클릭·Esc로 닫힘, 전체화면 앱 위에서도 표시
- [ ] 내 도구/업데이트 탭, 새로고침, 계열 업데이트·전역 전환 실행, 결과 반영
- [ ] 앱 열기(해당 탭으로), 종료

빌드·배포

- [ ] `Local.xcconfig` 없이 희생용 ID, 있으면 개인 ID로 해석
- [ ] Debug(`Mise Manager Dev`, `AppIcon-Dev`)와 Release가 나란히 설치되고 설정 도메인이 분리됨
- [ ] 추적 파일 감사: 활성 설정에 `com.mabyko`·`DEVELOPMENT_TEAM` 없음
- [ ] 두 아이콘 세트 모두 asset catalog 경고 0건

안전

- [ ] 검사 경로에서 설치 명령 호출 없음(테스트로 고정)
- [ ] 동시 작업 차단(busy 중 액션 무시)
- [ ] config.toml 주석·형식 보존, 잘못된 TOML은 수정 거부

## 11. 결정 필요 사항

| 항목 | 권장 | 대안 |
| --- | --- | --- |
| 최소 macOS | 14 | 15로 올리면 `@Entry`, 새 `Tab` API 사용 가능. 사용자 층이 본인 위주면 15도 무방 |
| 배포 | Developer ID + 공증 | 당분간 로컬 서명만. Developer ID 인증서 발급이 선행 |
| 번들 ID | §5 그대로: 추적 `forked.misemanager.local`, 개인 `com.mabyko.misemanager.epilo9er`(Debug는 `.dev`) | 조직 팀 등록(§5 인수 체크리스트) 뒤 정식 ID를 릴리스 설정에 |
| 저장소 | 같은 저장소, `swiftui` 브랜치에서 교체 후 `main` 머지 | 새 저장소(히스토리 단절) |
| 자동 업데이트 | 보류 | Sparkle 2 |
| UI 언어 | 한국어 고정, 문구는 한 파일에 모음 | String Catalog로 영어 추가 |
| 진행 라벨 언어 | 전부 한국어로 통일 | 현행 유지(영어 혼재) |

## 12. 성능 검증 방법

| 지표 | 목표 | 측정 |
| --- | --- | --- |
| 콜드 기동(아이콘 표시까지) | 0.5초 이하 | `os_signpost` + Instruments App Launch |
| 유휴 메모리 | 40 MB 이하 | Activity Monitor 실제 메모리, 10분 유휴 후 |
| 팝업 표시 지연 | 100 ms 이하 | 클릭 → `orderFront` 신호 사이 시간 |
| 전체 검사(도구 10개) | Tauri와 동등 이상 | 동일 mise 상태에서 비교 |

Tauri 현재값은 Phase 0에서 같은 방법으로 먼저 측정해 기준선으로 기록한다.
