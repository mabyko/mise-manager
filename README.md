# mise-manager (PoC)

`mise-manager`는 `mise`로 관리되는 도구 버전을 데스크톱 UI에서 조회/설치/전역 전환/삭제하는 Electrobun 기반 PoC입니다.

## 기준 시점
- 문서/코드 기준: **2026-03-05 (KST)**
- 로컬 확인 버전:
  - `mise 2026.3.3`
  - `bun 1.3.10`
  - `electrobun 1.14.4`

## 현재 UX
- 탭 구성:
  - `Updater`: 플러그인 버전 관리
  - `Logs`: 작업 로그 전용 탭
  - `Extensions`: placeholder
- Updater 컬럼:
  - `Plugin`
  - `Installed Versions`
  - `Active (Global)`
  - `Same Major Latest`
  - `Release Latest`
  - `Pre-release Latest`
  - `Status`
- 상태/액션 정책:
  - `Install`: `mise install -y <plugin>@<version>`
  - `Use Global`: `mise use -g -y <plugin>@<version>`
  - `Delete`: `mise uninstall -y <plugin>@<version>`
  - Active(global) 버전의 `Delete`는 비활성화
  - `Install` 후에는 해당 플러그인 상태를 재조회해 UI 즉시 동기화
- 진행 상태 UX:
  - 전체 진행률
  - 현재 처리 플러그인 라벨
  - 행 상태 (`idle/checking/updating/done/error`)
- 로그 UX:
  - Logs 탭에서 최근 작업/오류 확인
  - `Clear Logs` 지원

## 버전 계산 규칙
- 검사 기준: `Active (Global)` 우선, 없으면 설치 버전 중 최신
- `Same Major Latest`: 검사 기준과 같은 메이저의 최신
- `Release Latest`: 안정 버전 최신 (pre-release 제외)
- `Pre-release Latest` 표시 조건:
  - pre-release가 존재해야 함
  - 기준 버전이 semver면 `pre-release > 기준 버전`
  - 기준 버전이 semver가 아니면 `pre-release >= release latest`
- `python`, `ruby`: pre/dev/test 계열 필터링

## 실행
```bash
bun install
bun run dev
```

HMR:
```bash
bun run dev:hmr
```

## 회귀 체크리스트
1. `Check Updates` 실행 시 각 행 상태와 진행률이 정상 갱신된다.
2. `Install` 실행 후 해당 플러그인의 `Installed Versions`가 즉시 갱신된다.
3. `Use Global` 실행 후 `Active (Global)`이 즉시 변경된다.
4. Active(global) 버전은 `Delete` 버튼이 비활성화된다.
5. Active가 아닌 설치 버전 `Delete` 시 확인 다이얼로그가 뜨고, 확인 시 삭제된다.
6. `Logs` 탭에서 install/use/delete/check 로그가 누적되고 `Clear Logs`가 동작한다.

## 릴리즈 최소 버전 정리
- 앱 버전: `0.1.0-poc`
- 반영 위치:
  - `package.json`
  - `electrobun.config.ts`
- 태그 권장:
```bash
git tag 0.1.0-poc
git push origin 0.1.0-poc
```

## 구조
```text
src/
  bun/
    index.ts
  mainview/
    main.ts
    style.css
    index.html
  shared/
    contracts.ts
    version.ts
```
