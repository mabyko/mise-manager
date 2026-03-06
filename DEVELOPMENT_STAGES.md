# 개발 단계 문서 - mise-manager 0.1.0

## 기준
- 문서 기준일: `2026-03-06` (KST)
- 현재 릴리즈 타깃: `0.1.0`

## Stage 0 - Bootstrapping (완료)
- Electrobun 프로젝트 생성
- Bun/Vite 개발 체인 구성
- 기본 탭/레이아웃 골격 구성

## Stage 1 - Updater PoC (완료)
- `mise list`/`mise ls-remote` 기반 버전 조회
- Same Major / Latest 비교 및 액션 연결
- Check Updates 진행률 표시
- 오류 로그 표시

## Stage 2 - Updater 고도화 (완료)
- Installed Versions 다중 표시
- Install / Use Global / Delete 분리
- Delete 확인 모달 적용
- Active(global) 보호(삭제 비활성화)
- release/pre-release 분리 정책 반영
- Check Updates 병렬 처리(동시성 4)

## Stage 3 - Installs 탭 구현 (완료)
- plugin 검색 및 Installed/Not Installed 분리 표시
- source 집계:
  - remote plugin definitions
  - user plugins
  - core plugins
  - installed tools
- 상태 배지 및 툴팁 개선
- Core plugin 제거 비활성화

## Stage 4 - Plugin URL 관리 (완료)
- `Install Plugin` 시 custom URL 입력 지원
- `Edit Plugin`으로 URL 수정 지원(`--force`)
- User plugin URL 노출
- remote source 대비 `Custom URL` 판별 표시

## Stage 5 - 기능별 리팩토링 (완료)
- `mainview/main.ts`, `bun/index.ts` 단일 파일 과밀 해소
- 기능 모듈 분리:
  - `mainview`: `features/*`, `core/*`, `render/*`, `events.ts`
  - `bun`: `services/*`, `rpc/handlers.ts`, `app/mainViewUrl.ts`
- 이벤트 디스패처 맵 기반으로 액션 라우팅 구조화
- 탭 네이밍 정리: `extensions` -> `installs`

## Stage 6 - Mise Version 탭 추가 (완료)
- `Mise Version` 탭 신설
- 기본 활성 탭을 `Mise Version`으로 전환
- `Current`(local) / `Latest`(GitHub) / `Status` 요약 카드 제공
- `mise self-update -y` 실행 플로우(확인 모달 + 결과 로그)
- 상태 설명(`Status Guide`) 노출
- 상태 기반 `Update Mise` 버튼 활성/비활성 제어
- `Plugins Updater` 탭 최초 진입 시 `reload + Check Updates` 1회 자동 실행

## Stage 7 - 문서/릴리즈 정리 (진행 중)
- README에 문서 역할/사용 가이드 강화
- PRD/Planning/Stages/Changelog 최신 UX 기준 동기화
- 회귀 체크리스트 유지/보강

## 다음 작업 제안
1. `Mise Version` 상태 배지 컬러 체계(성공/경고/오류) 시각 강화
2. GitHub API rate-limit/네트워크 오류 메시지 세분화
3. 핵심 유즈케이스 e2e 스모크 스크립트 작성
4. 0.1.0 태그/릴리즈 노트 확정
