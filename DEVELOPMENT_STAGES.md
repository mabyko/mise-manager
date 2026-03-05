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

## Stage 5 - 문서/릴리즈 정리 (진행 중)
- README 최신 UX 기준 정리
- PRD/기획/개발단계 문서 정리
- 회귀 체크리스트 유지/보강

## 다음 작업 제안
1. Installs URL 입력값 유효성 검사(형식/스킴)
2. Custom URL 판별 규칙 테스트 케이스 추가
3. 핵심 유즈케이스 e2e 스모크 스크립트 작성
4. 0.1.0 태그/릴리즈 노트 확정
