# Mise Manager

**English** | [한국어](./README.ko.md)

A desktop GUI for browsing and managing runtimes, tools, and plugins with [mise](https://mise.jdx.dev/).

Manage installed versions in the app, or check updates and switch global versions from the macOS menu bar. Mise Manager tracks each installed major separately, so Node 26 and Node 24 can both stay up to date. It runs the `mise` CLI for you and keeps command output visible in the app.

## Platform Support

- [x] macOS — supported and verified
- [ ] Windows (Alpha) — build and runtime behavior need verification

macOS is currently the only supported platform.

## Screenshots

[![Mise Manager app window, menu-bar panel, and red update badge showing separate updates for Node 26 and Node 24](./docs/images/mise-manager-overview.png)](./docs/images/mise-manager-overview.png)

**App window:** browse tools, review updates for each installed major, and manage global versions. **Menu bar:** the red badge and count show available mise, tool, and plugin updates. Open the compact panel to check updates, install a new version, or switch versions.

View full size: [App window](./docs/images/mise-manager-app.png) · [Menu-bar icon and panel](./docs/images/mise-manager-menu-bar.png)

Captured from the current app UI in the browser preview with the light theme and sample data. Window frames and the menu-bar icon are arranged for presentation.

## Features

- Select installed tools directly from the searchable sidebar. The detail pane shows each installed major, its latest stable version, and global version controls.
- Open **mise Management**, **Plugin Management**, **Logs**, or **Settings** from the sidebar.
- **Updates** collects tool-series, mise, and external-plugin updates in one list. Its sidebar badge and the macOS menu bar share the same count. A red dot on the menu-bar icon stays visible while updates are available and clears when none remain; unknown and failed checks remain visible separately.
- Click the menu-bar icon for a compact tool list, per-series installs, and global version selection. **Settings → 메뉴바 아이콘 표시** controls its visibility (on by default, saved across restarts). mise and new-major updates open the main window for review. Closing the main window keeps the app running, even with the icon hidden; reopen it from the Dock or quit from the app menu. When the icon is shown, its right-click menu also offers **Mise Manager 종료**.
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

## Requirements

To use the app:

- [mise](https://mise.jdx.dev/getting-started.html), or the in-app installation guidance when mise is not detected
- Network access for release checks and remote plugin data

To build from source:

- [Bun](https://bun.sh/)
- Rust 1.77.2 or newer
- The [Tauri system prerequisites](https://v2.tauri.app/start/prerequisites/) for your platform

## Getting Started

```bash
git clone https://github.com/mabyko/mise-manager.git
cd mise-manager
bun install
bun run dev
```

To work on the frontend without launching Tauri, run the browser UI with its mock backend:

```bash
bun run ui:dev
```

Open the root page first, then `http://localhost:5173/?surface=tray` in a second tab to preview the synchronized menu-bar UI with sample data.

## Build

```bash
bun run build
```

On macOS, build only the application bundle with:

```bash
bun run build -- --bundles app
```

Build artifacts are written under `src-tauri/target/release/bundle/`.

## Test

```bash
bunx vitest run
bun run ui:build

cd src-tauri
cargo test
cargo check
```

On macOS, run `cargo run --example tray_badge_check` from `src-tauri/` to check native badge visibility, click handling, and icon recreation.

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

The main webview owns checks and mutations, and sends snapshots to the menu-bar webview. Commands from the popover are checked against current state before execution. The hidden main window disables WebKit background throttling on supported macOS versions (14+).

Plugin updates invalidate cached tool candidates; run the full check again to refresh them. Older mise versions may not support `--outdated`. Package-manager installations that disable self-update must update mise through that package manager. Numeric tracking currently groups by major, so Python 3.11 and 3.12 share the `3.x` series; tracking arbitrary minor lines and project-specific version pins is not implemented.

## Project Structure

| Path | Purpose |
| --- | --- |
| `src/mainview/` | Svelte 5 frontend |
| `src/shared/` | Frontend/backend contracts and shared version logic |
| `src-tauri/src/` | Rust commands, mise process integration, and configuration editing |
| `src-tauri/tauri.conf.json` | Tauri application and bundle configuration |

## Bundle Identifier Safety

The tracked Tauri configuration intentionally uses the sacrificial identifier `forked.misemanager.local`. Do not commit an organization or personal signing identifier.

For a personal build, create the ignored file `src-tauri/tauri.local.conf.json`:

```json
{
  "identifier": "<personal-bundle-id>"
}
```

Apply it explicitly:

```bash
bun run dev -- --config src-tauri/tauri.local.conf.json
bun run build -- --config src-tauri/tauri.local.conf.json
```

## Contributing

Issues and pull requests are welcome. Keep changes focused, add tests for behavior changes, and run the frontend and Rust checks above before submitting.

See [CHANGELOG.md](./CHANGELOG.md) for notable changes.

## License

Mise Manager is available under the [MIT License](./LICENSE).
