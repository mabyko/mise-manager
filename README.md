# mise-manager

`mise-manager`는 `mise`로 관리되는 도구/플러그인을 데스크톱 UI에서 조회/설치/전역 전환/삭제하는 Electrobun 앱입니다.

## 버전
- App version: `0.1.0`
- 기준 시점: 2026-03-05 (KST)

## 현재 UX
- 탭:
  - `Updater`: 버전 상태 조회 및 Install/Use/Delete
  - `Logs`: 최근 작업 로그 + Clear Logs
  - `Extensions`: placeholder
- Updater 컬럼:
  - `Plugin`
  - `Installed Versions`
  - `Active (Global)`
  - `Same Major Latest`
  - `Release Latest`
  - `Pre-release Latest`
  - `Status`

## 동작 정책
- `Install`: `mise install -y <plugin>@<version>`
- `Use Global`: `mise use -g -y <plugin>@<version>`
- `Delete`: `mise uninstall -y <plugin>@<version>`
- Active(Global) 버전의 Delete는 비활성화
- `Install`/`Use`/`Delete` 후 해당 플러그인 상태를 재조회해 UI 동기화
- RPC timeout: 20분 (대형 설치 대응)

## 버전 계산 규칙
- 기준 버전: Active(Global) 우선, 없으면 설치 버전 최신
- `Same Major Latest`: 기준 버전과 같은 메이저의 최신
- `Release Latest`: 안정 버전 최신
- `Pre-release Latest` 표시 조건:
  - 프리릴리즈가 존재
  - 기준이 semver면 `pre-release > 기준`
  - 기준이 semver가 아니면 `pre-release >= release latest`
- `python`, `ruby`는 pre/dev/test 필터 적용

## 실행
```bash
bun install
bun run dev
```

## 회귀 체크리스트
1. Check Updates 시 진행률/행 상태가 정상 갱신된다.
2. Install 후 Installed Versions가 즉시 갱신된다.
3. Use Global 후 Active(Global)가 즉시 갱신된다.
4. Active(Global) 버전의 Delete가 비활성화된다.
5. Non-active Delete 클릭 시 확인 다이얼로그가 뜨고, 확인 시 삭제된다.
6. Logs 탭에 check/install/use/delete 로그가 누적되고 Clear Logs가 동작한다.

## 다음 단계 조사: Installs 탭
`Installs` 탭 구현 전, `mise` CLI 기준으로 아래 흐름이 유효함을 확인했습니다.

- 플러그인 검색:
  - `mise plugins ls-remote --only-names`
  - `mise plugins ls-remote --urls`
- 플러그인 설치/제거:
  - `mise plugins install <plugin> [-y]`
  - `mise plugins uninstall <plugin> [-y]`
  - 제거 시 완전 정리는 `--purge`
- 도구 버전 설치/제거:
  - `mise install <plugin>@<version> -y`
  - `mise uninstall <plugin>@<version> -y`

권장 설계(Installs 탭):
1. 상단 검색창 + remote plugin 목록(`plugins ls-remote` 기반)
2. 각 plugin 행에 `Install Plugin` / `Remove Plugin` 버튼
3. plugin 상세 패널에서 버전 검색(`ls-remote <plugin>`) + 버전 설치/삭제
4. 위험 액션(`Remove Plugin --purge`)은 별도 확인 다이얼로그

## 릴리즈 태그
```bash
git tag 0.1.0
git push origin 0.1.0
```
