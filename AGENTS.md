# V2rayU — Agent Guide

macOS menu-bar proxy client (Xray-core / sing-box). SwiftUI + GRDB. Targets: macOS 14+.

## Targets & entrypoints

| Target | Type | Entry | Deployment |
|--------|------|-------|------------|
| `V2rayU` | macOS app (LSUIElement) | `V2rayU/App/App.swift` — `@main struct V2rayUApp` | 14+ |
| `V2rayUTool` | CLI (setuid helper) | `V2rayUTool/main.swift` — sets system proxy via SCPreferences | 11.5+ |
| `V2rayUTests` | Test bundle | Swift Testing, host app = V2rayU.app | 14+ |

## Key paths (defined in `V2rayU/App/App.swift:9-21`)

- `AppHomePath` = `~/.V2rayU` — config, logs, DB, PAC files
- `AppBinRoot` = `/usr/local/v2rayu` — core binaries + V2rayUTool + update scripts
- `databasePath` = `~/.V2rayU/.V2rayU.db`
- `v2rayUTool` = `/usr/local/v2rayu/V2rayUTool`
- `coreApiPort` = 11111, `coreApiBaseUrl` = `http://127.0.0.1:11111`

## Dependencies (SPM)

GRDB 7.11+ (SQLite), KeyboardShortcuts 2.4+, Yams 6.2+ (YAML), FlyingFox 0.26+ (HTTP), Firebase 12.14+, AppCenter 5.12+.

## Architecture

- **App layer**: `V2rayU/App/` — `App.swift` (entry + AppDelegate), `AppMenu.swift` (menu bar), `AppSettings.swift`, `AppState.swift` (global singleton)
- **Core layer**: `V2rayU/Core/`
  - `Database/` — GRDB-based SQLite (`AppDatabase.shared`), entities, migrations, stores
  - `Handlers/` — `V2rayLaunch.swift` (start/stop cores), `LaunchAgent.swift` (plist gen), `AppInstaller.swift`, `NetworkMonitor.swift`, `SleepManager.swift`, `CoreConfigHandler.swift` (JSON config gen for both cores), `Singbox/`, `V2ray/`
  - `Protocols/` — Share URI parsing/generation, V2ray/SingBox JSON model structs
  - `Services/` — `GithubService.swift` (releases API), `HttpServer.swift` (local PAC server via FlyingFox), `DownloadDelegate.swift`
  - `Utilities/` — `CoreCapabilityRules.swift` (capability rule engine ~1171 lines), `CertFingerprintFetcher.swift`, `DnsResolver.swift`, `Port.swift`, `Shell.swift`, `Scanner.swift`, `Network.swift` (ping)
- **Features layer**: `V2rayU/Features/` — Profile, Subscription, Routing, Share, PAC, Migration, Diagnostic, Update
- **UI layer**: `V2rayU/UI/` — Components, Views, Windows

## Run modes

`RunMode` enum: `global`, `pac`, `manual`, `tun` (defined in `V2rayU/Core/Handlers/V2rayLaunch.swift:13`).

## Core engine (V2rayLaunch)

Actor-based singleton in `V2rayU/Core/Handlers/V2rayLaunch.swift`. Flow: read DB profile → resolve core compatibility (capability rules) → generate config JSON → create LaunchAgent plist → launch daemon → wait for SOCKS port → set system proxy → (if TUN mode) create tun.json + start tun-helper LaunchDaemon.

## Capability rules system

Two JSON rule files at `Build/capability-rules/`:
- `xray-capability-rules.json` (456 lines) — per-protocol/transport/security support with version bounds
- `singbox-capability-rules.json` (367 lines) — sing-box capabilities

Engine: `V2rayU/Core/Utilities/CoreCapabilityRules.swift` (~1171 lines). Rules loaded from bundled JSON, evaluated at startup to decide which core to use + warn about incompatibilities.

## Build & release

```bash
# Build universal binary + DMG
./Build/build.sh

# Install (run as root via app or manually)
# Copies V2rayUTool, update scripts, core binaries to /usr/local/v2rayu/
# Sets up LaunchDaemon + sudoers entries
./Build/install.sh
```

`build.sh` flow: `xcodebuild archive` (arm64+x86_64) → copy .app → `appdmg` for DMG. Version extracted from `project.pbxproj` MARKETING_VERSION (currently 5.0.2).

## Testing

Uses **Swift Testing** framework (not XCTest). Tests are host-app-dependent (TEST_HOST = V2rayU.app).

```bash
# Run all tests
xcodebuild test -project V2rayU.xcodeproj -scheme V2rayU -destination 'platform=macOS'

# Run compatibility test suite (needs pre-downloaded core binaries)
./Build/tests/run-compatibility-test.sh          # requires binaries
./Build/tests/run-compatibility-test.sh --download  # download first

# Download core versions for testing (xray v1.8.0~v26.5.6, sing-box v1.12.0~v1.13.13)
python3 Build/tests/download-cores.py
# Or per-core:
python3 Build/tests/download-cores.py --core xray
python3 Build/tests/download-cores.py --core sing-box
```

Test config: `Build/tests/test-config.json` (`maxProfiles`, `sampleVersions`). Env: `V2RAYU_TEST_BIN_DIR`, `V2RAYU_TEST_REPORT_DIR`, `V2RAYU_MAX_PROFILES`, `V2RAYU_SAMPLE_VERSIONS`.

Compatibility test report: `Build/tests/reports/compatibility-report-*.json`. Generate HTML: `python3 Build/tests/generate-report.py <report.json>`.

Tests read the **real DB** at `~/.V2rayU/.V2rayU.db` — profiles must exist.

## Core update scripts (root, via sudoers)

- `Build/update-xray.sh` — installed to `/usr/local/v2rayu/update-xray.sh`, called with sudo for xray-core updates
- `Build/update-singbox.sh` — same path pattern
- Both support backup + rollback on failure

## Run-time paths

- `~/.V2rayU/config.json` — active core config
- `~/.V2rayU/tun.json` — TUN mode config (sing-box)
- `~/.V2rayU/V2rayU.log` — app log
- `~/.V2rayU/core.log` — core stderr/stdout
- `~/.V2rayU/tun.log` — TUN helper log
- `~/Library/LaunchAgents/yanue.v2rayu.sing-box.plist` / `yanue.v2rayu.xray-core.plist` — per-user LaunchAgents
- `/Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist` — system LaunchDaemon
- `/private/etc/sudoers.d/v2rayu-sudoer` — sudoers entry for tun-helper + core updates

## Repository conventions

- **No CI**, no linter/formatter config, no typecheck script
- **Localization**: en, zh-Hans, zh-HK in `V2rayU/Localization/` (String Catalogs + Localizable.strings)
- **TODO**: `TODO` file (Chinese, issues list) at repo root
- **Branch/PR**: no established convention visible
- **Docs are executable sources of truth** — `Docs/CoreCapabilityRules.md` documents the capability rules policy, `Docs/CompatibilityTestSystem.md` documents the test framework, `Docs/XrayReleaseFeatureAnalysis.md` is auto-generated by `Tools/analyze_xray_releases.py`
