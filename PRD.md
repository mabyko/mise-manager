# PRD - mise-manager 0.1.0

## 1. Product Summary
- Product: `mise-manager`
- Type: macOS desktop app (Electrobun)
- Goal: `mise` 사용자가 버전 상태 확인, 업데이트 판단, 설치/전역 전환/삭제를 UI로 빠르게 수행하도록 지원
- Baseline date: `2026-03-06` (KST)

## 2. Target Users
- `mise`로 node/python/ruby/bun/rust 등 다중 도구를 관리하는 개발자
- CLI는 익숙하지만 버전 비교와 반복 작업을 시각적으로 처리하고 싶은 사용자

## 3. Problem Statement
- 다수 플러그인의 현재/최신 상태를 한번에 파악하기 어렵다.
- 메이저 업데이트 리스크 때문에 업그레이드 의사결정이 번거롭다.
- 원격 조회 및 설치 작업이 길어질 때 진행 상태가 불명확하다.
- plugin definition 관리(기본 소스 vs custom URL)가 CLI에서는 추적이 불편하다.

## 4. Product Goals
- 설치된 도구 버전과 업데이트 후보를 명확히 분리하여 표시한다.
- 안전한 업데이트 경로(같은 major)와 최신 경로(release/pre-release)를 동시에 제공한다.
- 설치/전역전환/삭제 후 UI를 즉시 동기화한다.
- plugin definition 설치/수정/제거를 UI에서 관리한다.

## 5. Scope (0.1.0)
### In Scope
- `Plugins Updater` 탭
  - Installed Versions / Active(Global) / Same Major Latest / Release Latest / Pre-release Latest / Status
  - 액션: Install, Use Global, Delete(설치 버전 단위)
  - Delete 확인 모달
  - Check Updates 진행률 + 행별 상태
- `Plugins Installs` 탭
  - plugin 검색
  - Installed / Not Installed 분리 표
  - 상태 배지: Plugin(User), Plugin(Core), Tool Installed
  - User plugin URL 표시, custom URL 판별
  - 액션:
    - Installed: Edit Plugin, Remove Plugin
    - Not Installed: Install Plugin
  - Install/Edit URL 입력 모달
  - Core plugin 제거 비활성화
- `Logs` 탭
  - 최근 작업 로그 조회 및 Clear Logs

### Out of Scope (0.1.0)
- 자동 스케줄 점검
- 정책 프리셋(보수적/표준/최신)
- 롤백 자동화
- 팀 정책 파일(.mise-manager policy) 적용

## 6. Functional Requirements
- FR-01: 앱 시작 시 설치된 plugin/tool 상태를 로드한다.
- FR-02: Check Updates 실행 시 병렬 처리로 최신 정보를 계산한다.
- FR-03: 사용자는 대상 버전에 대해 Install 또는 Use Global을 선택할 수 있다.
- FR-04: Active(Global) 버전은 Delete 불가해야 한다.
- FR-05: Installs 탭에서 plugin definition을 설치할 수 있어야 한다.
- FR-06: Installs 탭에서 User plugin URL을 수정할 수 있어야 한다.
- FR-07: User plugin이 remote source와 다르면 Custom URL로 표시한다.
- FR-08: Core plugin은 Remove Plugin이 비활성화되어야 한다.
- FR-09: 오류는 사용자에게 텍스트로 표시되고 로그에 기록된다.

## 7. Non-Functional Requirements
- NFR-01: macOS에서 실행 가능해야 한다.
- NFR-02: 장시간 작업 중 UI가 응답 상태를 유지해야 한다.
- NFR-03: RPC timeout은 대형 설치에 대응 가능해야 한다(20분).
- NFR-04: 데이터 파싱 실패/명령 실패 시 원인 메시지가 노출되어야 한다.

## 8. UX Principles
- 상태와 액션을 같은 행에서 확인 가능해야 한다.
- 불가능한 액션은 비활성화로 사전 차단한다.
- 위험 액션(Delete)은 확인 모달을 거친다.
- 탭 상단 고정 헤더에서 맥락(설명/검색/진행률)을 유지한다.

## 9. Success Criteria
- SC-01: `mise` 연동 명령이 정상 실행되고 UI와 동기화된다.
- SC-02: 업데이트 후보 계산(major/release/pre-release)이 기대대로 표시된다.
- SC-03: Install/Use/Delete/Plugin Install/Edit/Remove가 로그와 상태에 반영된다.
- SC-04: 회귀 체크리스트 항목이 모두 통과한다.

## 10. Risks
- R-01: `mise` 출력 포맷 변경 시 파서 회귀 가능성
- R-02: remote source 토큰 규칙 차이로 custom URL 판별 오탐 가능성
- R-03: 네트워크/원격 저장소 상태에 따라 조회/설치 지연 가능성
