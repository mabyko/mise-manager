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

### Fixed
- mise 미설치 안내의 공식 사이트 링크 오타 수정 (`getting-starting.html` → `getting-started.html`)

### Known
- 앱 자동 업데이트(구 Electrobun Updater 채널)는 이번 포팅 범위에서 제외 (`tauri-plugin-updater` 도입 시 별도 작업)
- mise 미설치 화면의 외부 링크(`target="_blank"`)는 `tauri-plugin-opener` 도입 전까지 동작하지 않을 수 있음

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
  - `README.md` 문서 역할/사용 가이드 강화
  - `PRD.md`, `PLANNING.md`, `DEVELOPMENT_STAGES.md` 최신 구조 반영

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
