# Changelog

이 프로젝트의 주요 변경 사항을 기록합니다.

## [Unreleased] - Tauri 2 + Svelte 5 포팅 (2026-08-16)

### Changed
- 데스크톱 셸을 Electrobun에서 **Tauri 2**로 전면 포팅:
  - `src/bun/**`(Bun 프로세스)을 Rust `#[tauri::command]` 20개로 재작성 (`src-tauri/src/`)
  - mise 실행 PATH 보강/`MISE_BIN` 오버라이드 로직 유지, 실행 파일 절대경로는 startup에 1회 해석해 캐시
  - `~/.config/mise/config.toml`의 `[tool_alias]` 편집을 `toml_edit` 기반으로 전환 (주석/포맷 보존, 잘못된 TOML이면 덮어쓰기 대신 중단)
  - GitHub latest release 조회는 `reqwest`로 수행
- 프런트엔드를 바닐라 TS 수동 렌더링에서 **Svelte 5(runes)** 컴포넌트로 재작성:
  - `render/`·`events.ts`·`inputState.ts`의 수동 innerHTML 재렌더/이벤트 위임/입력값 복원 체계 제거 (`$state` 반응성과 `bind:value`가 대체)
  - 검색 입력 포커스 복원 해크 불필요해짐
- 테스트 러너를 `bun:test`에서 **vitest**(+happy-dom)로 전환, Rust 백엔드는 `cargo test`
- Vite 6 → 8 업그레이드
- 버전 비교 로직(`shared/version.ts`)은 프런트/백엔드 양쪽에서 사용되어 Rust(`version.rs`)와 TS에 중복 유지 — 동일한 미러 테스트로 드리프트 방지

### UI Redesign (시안 A — Sidebar Native)
- 탭 스트립을 **좌측 사이드바 내비게이션**으로 전환 (macOS 설정 스타일). 좁은 창(≤1020px)에서는 64px 아이콘 레일로 접히고, 사이드바 하단에 mise 버전·업데이트 배지 상주
- **Overview 화면 신설** (기본 화면): Mise Runtime/Plugins/Updates Available 스탯 카드 + Available Updates 리스트 + Recent Activity
- **Available Updates 규칙**: same-major 후보가 `Update to X` 주 버튼(설치 + Use Global 전환, 이전 버전 유지), major 후보는 `Update to Y (major)…` 보조 버튼으로 확인 모달 경유. pre-release는 Overview에서 제외 (Updater 탭 전용)
- 상단 헤더/진행률 바를 **하단 상태바**로 대체 — busy 스피너 + 라이브 mise 출력 + 실제 % 표시
- 팔레트를 시안 A 기준으로 교체 (라이트/다크 토큰 모두), 860px 이하에서 카드 스택 + 버튼 라벨 압축

### UI
- **진짜 진행률**: mise 서브프로세스 출력을 라인 단위로 스트리밍(`mise-output` 이벤트)해 진행 라벨 아래에 실시간 표시. 실제 계산 가능한 %(플러그인 체크 N/M)만 숫자로 표시하고, 그 외 busy 상태는 indeterminate 애니메이션 바로 전환 — 조작된 퍼센트 제거
- **다크 모드**: `prefers-color-scheme` 기반 다크 팔레트 추가 (구조 색상 토큰화)
- 고정 헤더를 `position: sticky`로 전환 — 하드코딩된 본문 여백(250px/300px) 제거, 헤더 높이 변화에 따른 겹침/공백 해소
- 모달 키보드 UX: Esc 닫기(전체), Enter 제출(URL 입력 모달), 열릴 때 입력 필드 autofocus. 파괴적 확인 모달(Delete/Update)은 의도적으로 Enter 미적용
- Installs 목록 200개 초과 시 "+N개 더 있음 — 검색으로 좁혀보세요" 안내 표시
- busy 중에도 무해한 컨트롤(플러그인 검색, Clear Logs)은 활성 유지
- 외부 링크를 `tauri-plugin-opener` 기반 버튼으로 교체 (기본 브라우저로 열림)
- 창 최소 크기 720x560 설정, 폰트 스택에 `system-ui` 폴백 추가, `:focus-visible` 포커스 링 추가

### Fixed
- mise 미설치 안내의 공식 사이트 링크 오타 수정 (`getting-starting.html` → `getting-started.html`)

### Known
- 앱 자동 업데이트(구 Electrobun Updater 채널)는 이번 포팅 범위에서 제외 (`tauri-plugin-updater` 도입 시 별도 작업)

## [0.1.0] - 2026-03-06

### Added
- `Mise Version` 탭:
  - Current(local) / Latest(GitHub latest release) / Status 요약 카드
  - `Status Guide` 설명 영역
  - `Reload Current`, `Check Latest`, `Update Mise` 액션
  - `Update Mise` 확인 모달 및 실행 결과(stdout/stderr) 표시
  - Latest 확인 시각 표시
- `Plugins Updater` 탭:
  - Installed Versions / Active(Global) / Same Major Latest / Release Latest / Pre-release Latest / Status 컬럼
  - `Install`, `Use Global`, `Delete` 액션
  - Delete 확인 모달
  - Check Updates 진행률 및 행 상태 표시
- `Plugin Installs` 탭:
  - plugin 검색
  - Installed / Not Installed 분리 표
  - 상태 배지(`Plugin (User)`, `Plugin (Core)`, `Tool Installed`) 및 툴팁
  - User plugin URL 표시
  - `Install Plugin` 시 Custom URL 입력 모달
  - `Edit Plugin` 버튼으로 URL 수정(`--force`)
- `Logs` 탭:
  - 작업 로그 조회 및 `Clear Logs`
- 문서:
  - 프로젝트 문서와 사용 가이드를 당시 최신 구조에 맞춰 정리

### Changed
- 아키텍처 리팩토링:
  - `mainview/main.ts`, `bun/index.ts` 단일 파일 구조를 기능 모듈 구조로 분리
  - `mainview`: `features/*`, `core/*`, `render/*`, `events.ts`
  - `bun`: `services/*`, `rpc/handlers.ts`, `app/mainViewUrl.ts`
- 이벤트 처리 구조 개선:
  - if-chain에서 액션 디스패처 맵 기반으로 전환
- 탭/네이밍 정리:
  - `extensions` -> `installs`
  - `Mise Version` 탭 추가
- Updater UX 조정:
  - Same Major / Release / Pre-release 컬럼의 `Use Global` 제거
  - 대상 컬럼은 `Install` 중심 동작
- Mise UX 개선:
  - 상태 기반 `Update Mise` 버튼 활성/비활성 제어
  - 상태 라벨 + 설명 텍스트 + 버튼 비활성 사유(툴팁) 제공
  - 앱 시작 기본 탭을 `Mise Version`으로 전환
- Updater 진입 UX 개선:
  - `Plugins Updater` 탭 최초 진입 시 `reload + Check Updates` 1회 자동 실행

### Fixed
- `bun dev` 실행 시 RPC transport 관련 오류 수정
- 설치 후 Installed Versions 즉시 미갱신 문제 수정
- 검색 입력 시 포커스 이탈 문제 수정
- Delete 취소/모달 동작 회귀 수정
- Active/global과 target 동일 시 Install 버튼 비활성화 로직 보완

### Security / Safety
- Active(Global) 버전 삭제 방지
- Core plugin Remove 비활성화
- 위험 액션(Delete, Mise Update)에 확인 단계 적용
- 상태 미충족 시 Mise Update 실행 차단
