# Mise Manager

[English](./README.md) | **한국어**

[mise](https://mise.jdx.dev/)로 설치한 런타임, 도구, 플러그인을 조회하고 관리하는 데스크톱 GUI입니다.

Mise Manager는 `mise` CLI 위에 집중된 인터페이스를 제공합니다. 명령을 모두 외우지 않아도 설치된 버전과 전역 선택 상태를 확인하고, 업데이트를 검사하고, 자주 쓰는 관리 작업을 실행할 수 있습니다. 명령의 실시간 출력도 앱 안에서 확인할 수 있습니다.

## 지원 플랫폼

- [x] macOS — 지원 및 검증 완료
- [ ] Windows (Alpha) — 빌드와 실제 동작 검증 필요

현재 공식 지원 플랫폼은 macOS뿐입니다.

## 스크린샷

밝은 테마의 실제 앱 UI를 브라우저 미리보기에서 촬영했습니다. 표시된 도구와 버전은 샘플 데이터입니다. 스크린샷을 누르면 원본 크기로 볼 수 있습니다.

| 요약 | 내 도구 | 플러그인 관리 |
| :---: | :---: | :---: |
| <a href="./docs/images/mise-manager-overview.png"><img src="./docs/images/mise-manager-overview.png" alt="Mise Manager Overview" width="260"></a> | <a href="./docs/images/mise-manager-my-tools.png"><img src="./docs/images/mise-manager-my-tools.png" alt="Mise Manager 내 도구 화면" width="260"></a> | <a href="./docs/images/mise-manager-plugin-installs.png"><img src="./docs/images/mise-manager-plugin-installs.png" alt="Mise Manager 플러그인 관리 화면" width="260"></a> |

## 주요 기능

- **요약**에서 도구 업데이트, 확인이 필요한 상태, 최근 작업을 한눈에 확인하고, 별도 카드에서 mise 자체를 업데이트합니다.
- **내 도구**에서 이름 검색과 업데이트 필터로 도구를 찾고, 목록 옆 상세 화면에서 현재 전역 버전과 변경 내용을 확인합니다.
- 설치된 각 도구의 같은 major 최신 버전, 최신 안정 버전, pre-release 후보를 비교합니다.
- 도구 버전을 설치하고 전역 버전을 전환하거나 사용하지 않는 버전을 삭제합니다.
- 이전 버전을 롤백용으로 유지하면서 한 번에 도구를 업데이트합니다.
- 원격 플러그인 정의를 검색하고 custom Git URL을 포함한 사용자 플러그인을 설치·수정·제거합니다.
- mise 자체를 업데이트하고 실시간 stdout/stderr와 작업 로그를 확인합니다.
- 라이트·다크 색상과 반응형 레이아웃을 지원합니다.

## 안전장치

- 활성 전역 버전은 삭제할 수 없습니다.
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
| mise 업데이트 | `mise self-update -y` |

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
