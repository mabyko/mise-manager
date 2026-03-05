# mise-manager

`mise-manager`는 `mise` 기반 런타임/도구를 데스크톱 UI에서 조회하고 관리하는 Electrobun 앱입니다.

## Version
- App: `0.1.0`
- Last updated: `2026-03-06` (KST)

## What It Does
- `Plugins Updater` 탭:
  - 설치된 버전 목록과 Active(Global) 버전을 한 화면에서 확인
  - `Same Major Latest`, `Release Latest`, `Pre-release Latest` 비교
  - 대상 버전에 대해 `Install` 또는 `Use Global` 실행
  - 설치된 개별 버전에 대해 `Use Global`/`Delete` 실행
- `Plugins Installs` 탭:
  - 원격 plugin definition 검색
  - 설치 상태를 `Plugin (User)`, `Plugin (Core)`, `Tool Installed` 배지로 표시
  - User plugin의 URL 표시 및 `Custom URL` 여부 판별
  - `Install Plugin`(선택적 Custom URL), `Edit Plugin`(URL 변경), `Remove Plugin`
  - Core plugin은 제거 비활성화
- `Logs` 탭:
  - check/install/use/delete/install-plugin/edit/remove-plugin 로그 확인
  - `Clear Logs` 지원

## Command Mapping
- Tool version install: `mise install -y <plugin>@<version>`
- Tool version use global: `mise use -g -y <plugin>@<version>`
- Tool version delete: `mise uninstall -y <plugin>@<version>`
- Plugin install: `mise plugins install -y <plugin> [git_url]`
- Plugin edit URL: `mise plugins install -y --force <plugin> <git_url>`
- Plugin remove: `mise plugins uninstall -y <plugin>`

## Data Sources
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
bun run dev
```

## Build
```bash
bunx vite build
```

## Regression Checklist
1. `Check Updates` 실행 시 전체 progress/행 상태가 갱신된다.
2. `Install` 후 Installed Versions가 즉시 반영된다.
3. `Use Global` 후 Active(Global)이 즉시 반영된다.
4. Active(Global) 버전 `Delete`는 비활성화된다.
5. Non-active `Delete`는 확인 모달 후 삭제된다.
6. Installs 탭에서 `Install Plugin` 시 URL 입력 모달이 동작한다.
7. User plugin에서 `Edit Plugin`으로 URL 변경(`--force`)이 동작한다.
8. Core plugin의 `Remove Plugin`은 비활성화된다.
9. Logs 탭에서 작업 로그 누적 및 `Clear Logs`가 동작한다.

## Documents
- Product requirements: [`PRD.md`](./PRD.md)
- Product planning: [`PLANNING.md`](./PLANNING.md)
- Development phases: [`DEVELOPMENT_STAGES.md`](./DEVELOPMENT_STAGES.md)
