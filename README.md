# macfuseGui

`macfuseGui` is a macOS menu bar agent app for mounting remote directories with `sshfs` + macFUSE.

- macOS 13+
- Apple Silicon first (`arm64`), Intel supported (`ARCH_OVERRIDE=x86_64`)
- `NSStatusItem` menu bar UX, no Dock icon (`LSUIElement=true`)
- SwiftUI settings + AppKit menu bar integration

## Key Features

- Multiple remotes with per-remote connect/disconnect.
- Startup duplicate-instance guard (singleton lock + running-app check) to avoid duplicate menu bar icons.
- Secure persistence:
  - Non-sensitive config in JSON.
  - Passwords in macOS Keychain.
- Test Connection in add/edit (real temporary mount + unmount validation).
- Per-remote startup toggle: `Auto-connect on app launch`.
- Recovery handling for sleep/wake and network restoration.
- Busy unmount diagnostics (shows blocking processes via `lsof`).
- Finder-style remote browser:
  - Sidebar (Favorites / Recents / Roots)
  - Breadcrumb navigation
  - Directories-only table view
  - Sticky cache with reconnect-state banners (no silent blank state)
- Diagnostics snapshot + `Copy Diagnostics` menu action.

## Dependency Install

```bash
brew install --cask macfuse
brew install sshfs-mac
```

Expected `sshfs` search order:
1. `/opt/homebrew/bin/sshfs`
2. `/usr/local/bin/sshfs`
3. `sshfs` from `$PATH`

## Build / Run / Clean

From repo root:

```bash
./scripts/build.sh
./scripts/run.sh
./scripts/clean.sh
```

`build.sh` includes a pre-step:
- `./scripts/build_libssh2.sh`

This prepares third-party libssh2 artifacts in:
- `build/third_party/libssh2`

Output app path:
- `build/macfuseGui.app`

Derived data:
- `build/DerivedData`

## Make Targets

```bash
make build
make run
make clean
```

## Common Build Overrides

```bash
# Intel build
ARCH_OVERRIDE=x86_64 ./scripts/build.sh

# Release build
CONFIGURATION=Release ./scripts/build.sh

# Allow signing if needed
CODE_SIGNING_ALLOWED=YES ./scripts/build.sh
```

## Xcode CLI Fallback

```bash
xcodebuild -project macfuseGui.xcodeproj -scheme macfuseGui -configuration Debug -derivedDataPath build/DerivedData build
```

## Run Tests

```bash
xcodebuild -project macfuseGui.xcodeproj -scheme macfuseGui -configuration Debug -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' test CODE_SIGNING_ALLOWED=NO
```

## Reliability Gate

```bash
scripts/audit_mount_calls.py && xcodebuild -project macfuseGui.xcodeproj -scheme macfuseGui -configuration Debug -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' test CODE_SIGNING_ALLOWED=NO
```

## VS Code

Included:
- `.vscode/tasks.json`
- `.vscode/launch.json`
- `.vscode/settings.json`

Tasks:
- `build` -> `scripts/build.sh`
- `run` -> build + launch app
- `clean` -> `scripts/clean.sh`
- `sourcekit-reset-cache` -> `scripts/reset_sourcekit_cache.sh`

Debug launch:
- Program: `build/macfuseGui.app/Contents/MacOS/macfuseGui`
- Pre-launch task: `build`

## Documentation

- **[New Contributor Guide](CONTRIBUTING.md)**: Start here if you want to modify the app.
- **[Architecture & Jargon Buster](ARCHITECTURE.md)**: Visual diagrams and plain-English explanations.
- **[Safe Change Rules (AGENTS.md)](AGENTS.md)**: Critical rules for AI agents and developers.

## Security Notes

- All external command execution uses `Process` with argument arrays.
- No shell interpolation for user input.
- Password mode uses temporary `SSH_ASKPASS` helper (`0700`) and ephemeral env vars.
- Passwords are never stored in JSON or logs.
- Diagnostics redact sensitive content.

## Browser Subsystem Notes

Browser internals are session-based (`openSession` / `listDirectories` / `health` / `closeSession`) with per-session health and sticky-cache behavior.

Current transport implementation uses native libssh2 SFTP through a C bridge (`LibSSH2Bridge.c/.h`) behind an internal transport abstraction.

Recovery contract:
- Keepalive runs every 12s only while the browser session is idle.
- Keepalive failures do not hard-close sessions; they schedule list-based recovery.
- Recovery backoff: `0.2s`, `0.8s`, `2s`, `5s`.
- Empty listings are confirmation-checked before being treated as truly empty.
- Browser keeps last-good entries visible during transient failures.

## Troubleshooting

### Missing dependencies

```bash
brew install --cask macfuse
brew install sshfs-mac
```

### xcodebuild first-launch issues

```bash
sudo xcodebuild -runFirstLaunch
```

### VS Code SourceKit stale errors

```bash
./scripts/reset_sourcekit_cache.sh
```

Then in VS Code:
1. Reload window
2. Restart Swift LSP
3. Re-index project

### Mount/unmount issues

- Use `Copy Diagnostics` from the app menu.
- For busy unmount, diagnostics now include blocking process hints.

### Duplicate menu icon or stale second app process

```bash
pkill -x macfuseGui
open -a /Applications/macfuseGui.app
```

If this still happens, check for multiple running processes:

```bash
pgrep -lf macfuseGui
```

### Browser diagnostics interpretation

- `state=healthy` with `isConfirmedEmpty=true`: path is reachable and truly has no subfolders.
- `state=reconnecting` or `state=degraded` with `fromCache=true`: browser is showing last-good cached data while retrying.
- `lastSuccessAt` and `lastLatencyMs` in `Browser Sessions` show the last confirmed successful list.
- Repeated `keepalive failed` followed by `recovery attempt` means auto-recovery is active; use `Retry now` in the browser UI to force an immediate list call.

### Mount concurrency proof logs (actor funnel check)

Use this during wake/reconnect testing:

```bash
log stream --style compact --predicate 'process == "macfuseGui"' \
  | rg 'Operation start remoteID=|Operation end remoteID=|mount call op=|actor enter op=|probe start op=sshfs-connect|probe end op=sshfs-connect'
```

Interpretation:
- Healthy parallelism: different remotes show overlapping `probe start/end op=sshfs-connect` windows.
- Funnel warning: one remote repeatedly waits with high `queueDelayMs` before `actor enter`.
