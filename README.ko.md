# Mise Manager

[English](./README.md) | **한국어**

[mise](https://mise.jdx.dev/)로 설치한 런타임, 도구, 플러그인을 조회하고 관리하는 데스크톱 GUI입니다.

앱에서 설치된 버전을 관리하고, macOS 메뉴바에서 업데이트를 확인하거나 전역 버전을 전환할 수 있습니다. 설치된 major 계열을 각각 추적하므로 Node 26과 Node 24를 함께 사용해도 각 계열의 최신 버전으로 업데이트할 수 있습니다. `mise` CLI를 대신 실행하며 명령의 실시간 출력도 앱 안에서 보여 줍니다.

## 지원 플랫폼

- [x] macOS — 지원 및 검증 완료
- [ ] Windows (Alpha) — 빌드와 실제 동작 검증 필요

현재 공식 지원 플랫폼은 macOS뿐입니다.

## 스크린샷

[![Node 26과 Node 24의 업데이트를 각각 보여 주는 Mise Manager 앱 창, 메뉴바 화면, 빨간 업데이트 배지](./docs/images/mise-manager-overview.png)](./docs/images/mise-manager-overview.png)

**앱 창:** 도구를 찾고, 설치된 각 major 계열의 업데이트를 확인하고, 전역 버전을 관리합니다. **메뉴바:** 빨간 배지와 개수로 mise·도구·플러그인의 업데이트 여부를 알려 줍니다. 작은 창을 열어 업데이트를 확인하고 새 버전을 설치하거나 사용할 버전을 전환합니다.

원본 크기로 보기: [앱 창](./docs/images/mise-manager-app.png) · [메뉴바 아이콘과 화면](./docs/images/mise-manager-menu-bar.png)

밝은 테마의 현재 앱 UI를 브라우저 미리보기에서 촬영했습니다. 표시된 도구와 버전은 샘플 데이터이며, 창 테두리와 메뉴바 아이콘은 소개용으로 배치했습니다.

## 주요 기능

- 검색 가능한 사이드바에서 설치된 도구를 바로 선택합니다. 상세 화면에서 설치된 각 major 계열과 최신 안정 버전을 확인하고 전역 버전을 선택합니다.
- 사이드바에서 **mise 관리**, **플러그인 관리**, **작업 기록**, **설정**을 엽니다.
- **업데이트**에서 도구의 각 버전 계열, mise, 외부 플러그인의 업데이트를 한 목록으로 확인합니다. 사이드바 배지와 macOS 메뉴바에 같은 업데이트 수가 표시됩니다. 업데이트가 있으면 메뉴바 아이콘에 빨간 점이 붙고, 남은 업데이트가 없으면 사라집니다. 확인하지 못했거나 확인에 실패한 항목도 별도로 보여 줍니다.
- 메뉴바 아이콘을 누르면 작은 창에서 도구 목록을 확인하고, 계열별 업데이트를 설치하거나 전역 버전을 선택할 수 있습니다. **설정 → 메뉴바 아이콘 표시**는 기본으로 켜져 있으며 앱을 다시 실행해도 선택을 유지합니다. mise 자체 업데이트와 새 major 설치는 앱 창에서 검토합니다. 메뉴바 아이콘을 숨겨도 앱 창을 닫으면 계속 실행됩니다. Dock에서 다시 열거나 앱 메뉴에서 종료할 수 있고, 아이콘이 보일 때는 우클릭 메뉴의 **Mise Manager 종료**로도 종료할 수 있습니다.
- 설치된 major 계열을 각각 추적합니다. 도구마다 원격 버전 목록을 한 번 조회해 Node 26과 Node 24의 최신 안정 버전을 따로 찾습니다.
- 도구 버전을 설치하고 전역 버전을 전환하거나 사용하지 않는 버전을 삭제합니다.
- 계열별 업데이트는 기존 설치 버전과 전역 기본값을 유지합니다. 설정에서 현재 전역 버전과 같은 major를 업데이트할 때 기본값도 전환하도록 선택할 수 있으며, 다른 major의 업데이트는 전역 기본값을 바꾸지 않습니다.
- 원격 플러그인 정의를 검색하고 custom Git URL을 포함한 사용자 플러그인을 설치·수정·제거합니다.
- mise의 플러그인 업데이트 명령으로 외부 플러그인 소스의 업데이트를 확인하고 적용합니다. Core plugin은 mise에 포함되며, 링크나 압축 파일로 설치한 플러그인은 Git 업데이트를 지원하지 않을 수 있습니다. 지원하지 않는 확인 방식이나 원격 조회 실패는 오류로 표시합니다.
- mise 자체를 업데이트하고 실시간 stdout/stderr와 작업 로그를 확인합니다.
- **설정**에서 앱을 열 때 업데이트 확인(기본 켜짐), 실행 중 1·6·24시간마다 확인(기본 꺼짐), 시스템·라이트·다크 테마, 프리릴리스 후보 표시를 선택합니다. 설정은 이 기기에 저장되며 업데이트를 자동으로 설치하지는 않습니다.

## 안전장치

- 전역 설정에 등록된 버전은 삭제할 수 없으며, 전역 설정을 읽지 못한 경우에도 삭제를 차단합니다.
- Core plugin은 앱에서 제거할 수 없습니다.
- 도구 버전 삭제, mise 자체 업데이트, major 버전 업데이트에는 확인 단계가 있습니다.
- 원클릭 업데이트 후에도 이전에 설치된 버전을 유지합니다.

## 요구사항

앱 사용:

- [mise](https://mise.jdx.dev/getting-started.html), 또는 mise를 찾지 못했을 때 표시되는 앱 내 설치 안내
- 릴리즈 확인과 원격 플러그인 정보를 위한 네트워크 연결

소스 빌드:

- [Bun](https://bun.sh/)
- Rust 1.77.2 이상
- 각 플랫폼에 맞는 [Tauri 시스템 요구사항](https://v2.tauri.app/start/prerequisites/)

## 시작하기

```bash
git clone https://github.com/mabyko/mise-manager.git
cd mise-manager
bun install
bun run dev
```

Tauri를 실행하지 않고 프런트엔드만 작업하려면 mock backend가 포함된 브라우저 UI를 실행합니다.

```bash
bun run ui:dev
```

기본 페이지를 먼저 연 뒤, 다른 탭에서 `http://localhost:5173/?surface=tray`를 열면 샘플 데이터로 앱과 동기화되는 메뉴바 UI를 미리 볼 수 있습니다.

## 빌드

```bash
bun run build
```

macOS에서 애플리케이션 bundle만 빌드하려면 다음 명령을 사용합니다.

```bash
bun run build -- --bundles app
```

빌드 결과는 `src-tauri/target/release/bundle/` 아래에 생성됩니다.

## 테스트

```bash
bunx vitest run
bun run ui:build

cd src-tauri
cargo test
cargo check
```

macOS에서는 `src-tauri/`에서 `cargo run --example tray_badge_check`를 실행해 배지 표시·숨김, 클릭 전달, 아이콘 재생성을 검사할 수 있습니다.

## 동작 방식

Mise Manager는 설치된 `mise` 실행 파일에 런타임과 플러그인 관리 작업을 위임합니다.

| 작업 | 명령 |
| --- | --- |
| mise 버전 확인 | `mise --version` |
| 설치·전역 도구 버전 조회 | `mise ls --installed --json`, `mise ls --global --json` |
| 사용 가능한 버전 확인 | `mise ls-remote <tool> --json` |
| 도구 버전 설치 | `mise install -y <tool>@<version>` |
| 전역 버전 선택 | `mise use -g -y <tool>@<version>` |
| 도구 버전 제거 | `mise uninstall -y <tool>@<version>` |
| 플러그인 정의 관리 | `mise plugins install`, `mise plugins uninstall` |
| 플러그인 소스 업데이트 확인 | `mise plugins ls --user --outdated` |
| 플러그인 하나의 소스 업데이트 | `mise plugins update <plugin>` |
| mise 업데이트 | `mise self-update -y --no-plugins` |

메인 웹뷰가 업데이트 확인과 변경 작업을 담당하고 현재 상태를 메뉴바 웹뷰에 전달합니다. 메뉴바 창에서 요청한 작업은 현재 상태에 맞는지 확인한 뒤 실행합니다. 지원되는 macOS 버전(14 이상)에서는 창이 숨겨져도 작업을 계속할 수 있도록 메인 웹뷰의 WebKit 백그라운드 실행 제한을 해제합니다.

플러그인을 업데이트하면 저장된 도구 버전 후보를 비웁니다. 전체 업데이트 확인을 다시 실행하면 최신 후보를 가져옵니다. 오래된 mise는 `--outdated`를 지원하지 않을 수 있습니다. 패키지 관리자로 설치해 자체 업데이트가 비활성화된 mise는 해당 패키지 관리자로 업데이트해야 합니다. 현재 버전 추적은 major 단위이므로 Python 3.11과 3.12는 같은 `3.x` 계열로 묶입니다. 임의의 minor 계열 추적과 프로젝트별 버전 고정은 지원하지 않습니다.

## 프로젝트 구조

| 경로 | 역할 |
| --- | --- |
| `src/mainview/` | Svelte 5 프런트엔드 |
| `src/shared/` | 프런트엔드·백엔드 계약과 공용 버전 로직 |
| `src-tauri/src/` | Rust command, mise 프로세스 연동, 설정 파일 편집 |
| `src-tauri/tauri.conf.json` | Tauri 애플리케이션·bundle 설정 |

## Bundle ID 안전장치

추적되는 Tauri 설정은 의도적으로 희생용 ID인 `forked.misemanager.local`을 사용합니다. 조직 또는 개인 서명 ID를 커밋하지 마세요.

개인 빌드가 필요하면 git에서 제외된 `src-tauri/tauri.local.conf.json`을 만듭니다.

```json
{
  "identifier": "<personal-bundle-id>"
}
```

다음처럼 명시적으로 적용합니다.

```bash
bun run dev -- --config src-tauri/tauri.local.conf.json
bun run build -- --config src-tauri/tauri.local.conf.json
```

## 기여하기

Issue와 pull request를 환영합니다. 변경 범위를 작게 유지하고, 동작이 바뀌면 테스트를 추가하고, 제출 전에 위의 프런트엔드·Rust 검사를 실행해 주세요.

주요 변경 내역은 [CHANGELOG.md](./CHANGELOG.md)에서 확인할 수 있습니다.

## 라이선스

Mise Manager는 [MIT 라이선스](./LICENSE)로 배포됩니다.
