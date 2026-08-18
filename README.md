# mise-manager

`mise-manager`는 `mise` 기반 런타임/도구를 데스크톱 UI에서 조회하고 관리하는 Tauri 2 앱입니다.
프런트엔드는 Svelte 5(runes) + Vite, 백엔드는 Rust Tauri 커맨드로 구성됩니다.

## Version
- App: `0.1.2`
- Last updated: `2026-08-16` (KST)

## What It Does
- 좌측 사이드바 내비게이션 (좁은 창에서는 아이콘 레일로 축소)
- 앱 시작 기본 화면: `Overview`
- `Overview` 화면:
  - Mise Runtime / Plugins / Updates Available 요약 카드
  - `Available Updates`: same-major 후보는 `Update to X`(설치 + Use Global 전환) 원클릭, major 후보는 확인 모달 경유, pre-release 제외
  - 체크 실패 플러그인 `Retry`, 최근 로그 5줄 + 전체 로그 이동
- `Mise Version` 탭:
  - `Current`(local `mise --version`) / `Latest`(GitHub latest release) 비교
  - 상태(`Update Available`, `Up-to-date`, `Check Failed`, `Updated (Reload Needed)` 등) 표시
  - 상태 설명(`Status Guide`) 및 최신 확인 시각 표시
  - 상태 기반 `Update Mise` 버튼 활성/비활성 제어
  - `mise self-update -y` 실행 확인 모달 + 실행 결과(stdout/stderr) 표시
- `Plugins Updater` 탭:
  - 설치된 버전 목록과 Active(Global) 버전을 한 화면에서 확인
  - 탭 최초 진입 시 `reload + Check Updates` 1회 자동 실행
  - `Same Major Latest`, `Release Latest`, `Pre-release Latest` 비교
  - 대상 버전에 대해 `Install` 실행
  - 설치된 개별 버전에 대해 `Use Global`/`Delete` 실행
- `Plugin Installs` 탭:
  - 원격 plugin definition 검색
  - 설치 상태를 `Plugin (User)`, `Plugin (Core)`, `Tool Installed` 배지로 표시
  - User plugin의 URL 표시 및 `Custom URL` 여부 판별
  - `Install Plugin`(선택적 Custom URL), `Edit Plugin`(URL 변경), `Remove Plugin`
  - Core plugin은 제거 비활성화
- `Logs` 탭:
  - check/install/use/delete/install-plugin/edit/remove-plugin/self-update 로그 확인
  - `Clear Logs` 지원

## Command Mapping
- Mise version: `mise --version`
- Mise self update: `mise self-update -y`
- Tool version install: `mise install -y <plugin>@<version>`
- Tool version use global: `mise use -g -y <plugin>@<version>`
- Tool version delete: `mise uninstall -y <plugin>@<version>`
- Plugin install: `mise plugins install -y <plugin> [git_url]`
- Plugin edit URL: `mise plugins install -y --force <plugin> <git_url>`
- Plugin remove: `mise plugins uninstall -y <plugin>`

## Data Sources
- Current mise version: `mise --version`
- Latest mise release: `https://mise.jdx.dev/VERSION` (fallback: `https://api.github.com/repos/jdx/mise/releases/latest`)
- Installed tool versions: `mise ls --installed --json`
- Active global versions: `mise ls --global --json`
- Installed user plugins: `mise plugins ls --user`, `mise plugins ls --user --urls`
- Core plugins: `mise plugins ls --core`
- Remote plugin definitions: `mise plugins ls-remote --only-names`, `mise plugins ls-remote --urls`
- Version candidates: `mise ls-remote <plugin> --json`

## Update Rules
- Check base: `Active(Global)` 우선, 없으면 installed 최신 버전
- `Same Major Latest`: base와 같은 major의 최신
- `Release Latest`: 안정 버전 최신
- `Pre-release Latest`: 아래 조건 모두 충족 시 표시
  - pre-release 후보 존재
  - base가 semver면 `pre-release > base`
  - base가 semver가 아니면 `pre-release >= release latest`
- `python`, `ruby`는 pre/dev/test 계열 필터 적용
- Check Updates는 동시성 4로 병렬 실행

## Run
```bash
bun install
bun run dev   # tauri dev (Vite HMR 포함)
```

## Build
```bash
bun run build   # tauri build (.app/.dmg)
```

## Test
```bash
bunx vitest run             # frontend
cargo test                  # backend (src-tauri/ 에서)
```

### Build in Codex vs Local Terminal
- Codex(샌드박스)에서는 `hdiutil`이 막혀 있어 `tauri build`의 DMG 번들 단계가 실패할 수 있습니다.
- Codex에서는 아래까지만 검증하세요:
  - `bun run ui:build`
  - `cargo check` / `cargo test` (`src-tauri/`)
- 실제 릴리즈 빌드는 로컬 터미널(일반 Terminal/iTerm)에서 실행하세요:
  - `bun run build`

## Regression Checklist
1. 앱 시작 시 기본 화면이 `Overview`이고, Current/Latest 조회 + `reload + Check Updates`가 1회 자동 수행된다.
2. `Overview`의 `Update to X`는 설치 후 Use Global까지 전환하고, major 후보는 확인 모달을 거친다.
3. `Plugins Updater` 탭 최초 진입 시(Overview에서 이미 수행되지 않았다면) `reload + Check Updates`가 1회 자동 수행된다.
4. 상태가 `Update Available`일 때만 `Update Mise` 버튼이 활성화된다.
5. `Update Mise` 실행 후 결과 로그(`Before/After`, stdout/stderr)가 보인다.
6. `Plugins Updater`의 `Updates` 열은 실제 존재하는 후보만 종류 태그(same major/release/pre-release)와 함께 나열하고 `Install` 버튼만 제공한다. Active와 같은 버전은 표시하지 않고, 후보가 없으면 `Up to date ✓`를 표시한다.
7. 설치된 버전 row의 `Use Global`/`Delete`가 정상 동작한다.
8. Active(Global) 버전 `Delete`는 비활성화된다.
9. Installs 탭에서 `Install Plugin` URL 입력 모달이 동작한다.
10. User plugin에서 `Edit Plugin` URL 변경(`--force`)이 동작한다.
11. Core plugin의 `Remove Plugin`은 비활성화된다.
12. Logs 탭에서 작업 로그 누적 및 `Clear Logs`가 동작한다.

## Documents
- [`PRD.md`](./PRD.md): 제품 요구사항 문서
  - 목적: 왜 만드는지, 누가 쓰는지, 0.1.0 범위/요구사항/성공기준을 정의
  - 갱신 시점: 기능 범위 변경, 요구사항 추가/제거, 리스크 변경 시
- [`PLANNING.md`](./PLANNING.md): 실행 계획/기획 문서
  - 목적: 화면 구조, 기능 흐름, 우선순위, 다음 작업 계획을 정리
  - 갱신 시점: UX 구조 변경, 우선순위 재조정, 신규 작업 제안 시
- [`DEVELOPMENT_STAGES.md`](./DEVELOPMENT_STAGES.md): 개발 단계 추적
  - 목적: Stage 단위로 무엇이 완료/진행 중인지 이력 관리
  - 갱신 시점: 단계 완료, 신규 단계 시작, 단계 목표 수정 시
- [`CHANGELOG.md`](./CHANGELOG.md): 릴리즈 변경 이력
  - 목적: Added/Changed/Fixed/Safety 관점에서 사용자 영향 변경사항 기록
  - 갱신 시점: 기능 배포/수정 완료 시점(사용자 관점으로 요약)

문서 사용 가이드:
1. 제품 의도와 범위 확인은 `PRD.md`를 먼저 본다.
2. 현재 구현 방향과 우선순위는 `PLANNING.md`에서 본다.
3. 진행 상태는 `DEVELOPMENT_STAGES.md`에서 본다.
4. 실제 반영된 변경 내역은 `CHANGELOG.md`에서 확인한다.
