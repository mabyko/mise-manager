# Mise Manager

**English** | [한국어](./README.ko.md)

A native macOS app for browsing and managing runtimes, tools, and plugins with [mise](https://mise.jdx.dev/).

Manage installed versions in the app, or check updates and switch global versions from the menu bar. Mise Manager tracks each installed major separately, so Node 26 and Node 24 can both stay up to date. It runs the `mise` CLI for you and keeps command output visible in the app.

## Platform Support

- macOS 14 (Sonoma) or newer, Apple silicon and Intel.

Version 0.2.0 replaced the Tauri/Svelte app with SwiftUI and AppKit. The last Tauri build is tagged `v0.1.2-tauri`.

## Screenshots

[![Mise Manager app window, menu-bar panel, and red update badge showing separate updates for Node 26 and Node 24](./docs/images/mise-manager-overview.png)](./docs/images/mise-manager-overview.png)

**App window:** browse tools, review updates for each installed major, and manage global versions. **Menu bar:** the red badge and count show available mise, tool, and plugin updates. Open the compact panel to check updates, install a new version, or switch versions.

View full size: [App window](./docs/images/mise-manager-app.png) · [Menu-bar icon and panel](./docs/images/mise-manager-menu-bar.png)

Captured from the native app (light theme) with sample data. The menu-bar strip is arranged for presentation.

## Features

- Select installed tools directly from the searchable sidebar. The detail pane shows each installed major, its latest stable version, and global version controls.
- Open **mise**, **Plugin Management**, **Logs**, or **Settings** from the sidebar.
- **Updates** collects tool-series, mise, and external-plugin updates in one list. Its sidebar badge and the macOS menu bar share the same count. A red dot on the menu-bar icon stays visible while updates are available and clears when none remain; unknown and failed checks remain visible separately.
- Click the menu-bar icon for a compact tool list, per-series installs, and global version selection. The panel opens under the icon on whichever display you click, without activating the app, and closes on an outside click or Esc. **Settings → 메뉴바 아이콘 표시** controls its visibility (on by default, saved across restarts). mise and new-major updates open the main window for review. The app is a menu-bar app: the Dock icon appears only while the main window is open. Closing the window keeps the app running in the menu bar; reopen it from the panel or by launching the app again, and quit from the app menu or the panel. **Settings → 로그인 시 시작** registers it as a login item so it comes up in the menu bar only.
- Track every installed major independently: Node 26 and Node 24 each get their own latest stable candidate from one remote lookup per tool.
- Install tool versions, switch the global version, or remove unused versions.
- Install a series update while keeping previous versions and the global default. Settings can enable switching the default when updating its current major; updates to other majors never switch it.
- Browse remote plugin definitions and install, edit, or remove user plugins, including custom Git URLs.
- Check and update external plugin source using mise's native plugin update commands. Core plugins ship with mise; linked or archive plugins may not support Git updates. Unsupported checks and remote failures are shown as errors.
- Update mise itself and view live stdout/stderr and operation logs.
- Use **Settings** for startup checks (on by default), checks every 1/6/24 hours while the app runs (off by default), system/light/dark theme, and optional prerelease display. Preferences are saved on this device. Checks never install automatically.

## Safety

- Globally configured versions cannot be removed; an unreadable global configuration blocks deletion.
- Core plugins cannot be removed from the app.
- Tool deletion, mise self-update, and major-version updates require confirmation.
- One-click updates keep the previously installed version.
- Edits to `~/.config/mise/config.toml` touch only the `[tool_alias]` section and keep every other line, comment, and ordering as is. A file that does not look like TOML is left untouched.

## Requirements

To use the app:

- [mise](https://mise.jdx.dev/getting-started.html), or the in-app installation guidance when mise is not detected
- Network access for release checks and remote plugin data

To build from source:

- Xcode 16 or newer (Swift 6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) only if you edit `project.yml` (the generated `MiseManager.xcodeproj` is tracked)

## Getting Started

```bash
git clone https://github.com/mabyko/mise-manager.git
cd mise-manager
open MiseManager.xcodeproj
```

Run the `MiseManager` scheme. The Debug configuration installs side by side with a release build as **Mise Manager Dev** with its own icon and settings domain.

## Build

```bash
scripts/release.sh
```

This builds the Release configuration and writes `build/release/MiseManager-<version>.dmg`. Signing follows `Config/Local.xcconfig` (see below); without it the app is ad-hoc signed for local use. Developer ID signing and notarization are not wired up yet.

## Test

```bash
scripts/test.sh
```

`MiseCore` (Swift package, no UI) holds the mise integration, parsers, update rules, and app state with its tests; the app test bundle covers menu-bar geometry. A few tests run against the real `mise` when it is installed.

## How It Works

Mise Manager delegates runtime and plugin management to the installed `mise` executable:

| Action | Command |
| --- | --- |
| Read the mise version | `mise --version` |
| List installed and global tool versions | `mise ls --installed --json`, `mise ls --global --json` |
| Check available versions | `mise ls-remote <tool> --json` |
| Install a tool version | `mise install -y <tool>@<version>` |
| Select a global version | `mise use -g -y <tool>@<version>` |
| Remove a tool version | `mise uninstall -y <tool>@<version>` |
| Manage plugin definitions | `mise plugins install`, `mise plugins uninstall` |
| Check plugin source updates | `mise plugins ls --user --outdated` |
| Update one plugin's source | `mise plugins update <plugin>` |
| Update mise | `mise self-update -y --no-plugins` |

GUI apps start without the shell `PATH`, so mise is looked up through `MISE_BIN` and the usual install directories (`~/.local/bin`, `~/.mise/bin`, Homebrew, `/usr/local/bin`). One observable `AppState` drives both the window and the menu-bar panel; commands from the panel are checked against current state before execution.

Plugin updates invalidate cached tool candidates; run the full check again to refresh them. Older mise versions may not support `--outdated`. Package-manager installations that disable self-update must update mise through that package manager. Numeric tracking currently groups by major, so Python 3.11 and 3.12 share the `3.x` series; tracking arbitrary minor lines and project-specific version pins is not implemented.

## Project Structure

| Path | Purpose |
| --- | --- |
| `Packages/MiseCore/` | Swift package: mise CLI runner, parsers, version and update rules, `config.toml` editing, app state and feature flows, tests |
| `MiseManager/App/` | App entry, delegate, debug hooks |
| `MiseManager/Views/` | SwiftUI main window (sidebar, tabs, dialogs, status bar) and menu-bar panel |
| `MiseManager/MenuBar/` | `NSStatusItem`, badge, non-activating `NSPanel`, placement |
| `MiseManager/Resources/` | Asset catalog (`AppIcon`, `AppIcon-Dev`, brand icon) |
| `Config/` | `Base.xcconfig` (tracked) and `Local.xcconfig` (ignored) |
| `project.yml` | XcodeGen spec for `MiseManager.xcodeproj` |
| `assets/icon.iconset/` | 1024px app icon master |

## Bundle Identifier Safety

The tracked configuration intentionally uses the sacrificial identifier `forked.misemanager.local` and no signing team. Do not commit an organization or personal signing identifier.

For a personal build, create the ignored file `Config/Local.xcconfig`:

```xcconfig
MISEMANAGER_BUNDLE_ID = <personal-bundle-id>
MISEMANAGER_BUNDLE_ID[config=Debug] = <personal-bundle-id>.dev
DEVELOPMENT_TEAM = <team id from the certificate's OU>
```

`Base.xcconfig` includes it automatically when present.

## Contributing

Issues and pull requests are welcome. Keep changes focused, add tests for behavior changes, and run `scripts/test.sh` before submitting.

See [CHANGELOG.md](./CHANGELOG.md) for notable changes.

## License

Mise Manager is available under the [MIT License](./LICENSE).
