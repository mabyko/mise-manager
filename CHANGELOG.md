# Changelog

이 프로젝트의 주요 변경 사항을 기록합니다.

## [0.1.0] - 2026-03-06

### Added
- `Plugins Updater` 탭:
  - Installed Versions / Active(Global) / Same Major Latest / Release Latest / Pre-release Latest / Status 컬럼
  - `Install`, `Use Global`, `Delete` 액션
  - Delete 확인 모달
  - Check Updates 진행률 및 행 상태 표시
- `Plugins Installs` 탭:
  - plugin 검색
  - Installed / Not Installed 분리 표
  - 상태 배지(`Plugin (User)`, `Plugin (Core)`, `Tool Installed`) 및 툴팁
  - User plugin URL 표시
  - `Install Plugin` 시 Custom URL 입력 모달
  - `Edit Plugin` 버튼으로 URL 수정(`--force`)
- `Logs` 탭:
  - 작업 로그 조회 및 `Clear Logs`
- 문서:
  - `PRD.md`
  - `PLANNING.md`
  - `DEVELOPMENT_STAGES.md`
  - 최신 `README.md`

### Changed
- 버전 정책 정교화:
  - Same Major / Release / Pre-release 분리
  - pre-release 노출 조건 적용
  - python/ruby pre/dev/test 필터 적용
- Installs 데이터 소스 정리:
  - `mise plugins ls-remote --only-names/--urls`
  - `mise plugins ls --user --urls`
  - `mise plugins ls --core`
  - `mise ls --installed --json`
- UI 구조 개선:
  - 고정 header + global progress 구조
  - 탭 맥락 정보(제목/설명/액션) 고정
- 성능 개선:
  - Check Updates 병렬 처리(동시성 4)

### Fixed
- `bun dev` 실행 시 RPC transport 관련 오류 수정
- 설치 후 Installed Versions 즉시 미갱신 문제 수정
- 검색 입력 시 포커스 이탈 문제 수정
- Delete 취소/모달 동작 회귀 수정
- Active/global과 target 동일 시 Install 버튼 비활성화 로직 보완

### Security / Safety
- Active(Global) 버전 삭제 방지
- Core plugin Remove 비활성화
- 위험 액션(Delete)에 확인 단계 추가
