# mise-manager 기획서 (0.1.0 기준)

## 1. 프로젝트 개요
`mise-manager`는 `mise` 기반 개발 도구를 데스크톱 UI에서 관리하기 위한 앱이다.  
0.1.0에서는 실사용 가능한 설치/업데이트 관리 흐름과 `mise` 본체 버전 관리 흐름을 함께 제공한다.

## 2. 핵심 가치
- 여러 도구의 설치/전역 사용 상태를 한 번에 파악
- 업데이트 의사결정을 분기(같은 메이저/릴리즈/프리릴리즈)
- 설치/전환/삭제 작업을 클릭 중심으로 실행
- plugin definition의 기본 소스와 custom URL 상태 시각화
- `mise` 본체(Current vs Latest) 상태를 직관적으로 확인하고 안전하게 self-update 실행

## 3. 사용자
- `mise` 기반으로 여러 언어 런타임/도구를 운영하는 개발자
- CLI 작업량을 줄이고 상태 확인 시간을 단축하고 싶은 사용자

## 4. 화면 구조
1. `Mise Version`
2. `Plugin Installs`
3. `Plugins Updater`
4. `Logs`

기본 진입 탭은 `Plugins Updater`, 탭/헤더/진행률은 상단 고정 구조를 사용한다.

## 5. 기능 기획
### 5.1 Mise Version
- 데이터:
  - Current: `mise --version`
  - Latest: GitHub latest release(`tag_name`)
- 표시:
  - 요약 카드(Current / Latest / Status)
  - Status Guide(상태 설명)
  - Latest 확인 시각
  - 업데이트 실행 결과(stdout/stderr)
- 액션:
  - Reload Current
  - Check Latest
  - Update Mise(확인 모달)
- 제약:
  - 상태 기반 `Update Mise` 버튼 제어
  - 업데이트 완료 후 재시작/리로드 안내

### 5.2 Plugins Updater
- 컬럼:
  - Plugin
  - Installed Versions
  - Active (Global)
  - Same Major Latest
  - Release Latest
  - Pre-release Latest
  - Status
- 액션:
  - 대상 컬럼: Install
  - 설치 버전 단위: Use Global, Delete
- 제약:
  - Active(Global) 버전 Delete 금지
  - Delete 전 확인 모달 필수

### 5.3 Plugin Installs
- 데이터 소스:
  - remote plugin definitions
  - user plugins
  - core plugins
  - installed tools
- 표시:
  - Installed / Not Installed 표 분리
  - 상태 배지: Plugin(User), Plugin(Core), Tool Installed
  - User plugin URL + Custom URL 여부
- 액션:
  - Installed: Edit Plugin, Remove Plugin
  - Not Installed: Install Plugin
- 제약:
  - Core plugin Remove 비활성화
  - Install/Edit 시 URL 입력 모달 제공

### 5.4 Logs
- 작업 성공/실패를 시계열로 기록
- 사용자가 직접 Clear 가능

## 6. 버전 정책
- 기준 버전: Active(Global) 우선, 없으면 설치 버전 최신
- Same Major Latest: 기준 버전과 같은 major 중 최신
- Release Latest: 안정 버전 최신
- Pre-release Latest: 조건부 표시
  - pre-release 존재
  - 기준 semver인 경우: pre-release > 기준
  - 기준 non-semver인 경우: pre-release >= release latest
- python/ruby는 pre/dev/test 계열 제외

## 7. 운영 정책
- 느린 작업은 progress 및 상태로 사용자에게 명확히 전달
- 오류 메시지는 숨기지 않고 로그에 원문 중심으로 기록
- 작업 완료 후 즉시 재조회하여 UI와 실제 상태를 동기화

## 8. 차기 우선순위(초안)
1. `Mise Version` 상태 시각 표현(컬러/배지/아이콘) 고도화
2. Installs URL 입력값 유효성 검사(형식/스킴)
3. 핵심 유즈케이스 e2e 회귀 자동화
4. 릴리즈/패키징 플로우 확정
