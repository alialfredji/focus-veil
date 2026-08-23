# Focus Veil

Focus Veil is a local macOS menu-bar utility that will keep the focused window clear while softly blurring and dimming ordinary windows behind it. It is a personal, native AppKit app with no network access.

Phase 1 provides the signed app bundle, menu-bar skeleton, and local install flow. The focus effect and Accessibility permission flow are added in later phases.

## Requirements

- macOS 14 or later
- Apple Silicon (`arm64`)
- Xcode command-line tools with Swift 6.2 or later

No Screen Recording permission is required. Later focus tracking requires Accessibility permission; it does not use screen capture.

## Build

From this directory:

```sh
./scripts/build-app.sh
```

The build script runs tests, creates a release arm64 executable, assembles `dist/Focus Veil.app`, signs it with the first installed Apple Development identity, verifies the signature, and creates `dist/Focus-Veil-0.1.0.zip`.

If no Apple Development identity is available, the script warns before using ad-hoc signing. In that case, macOS may request Accessibility approval again after rebuilding.

## Install locally

```sh
./scripts/install-local.sh
```

This builds first, refuses to replace a running Focus Veil process, installs the bundle at `/Applications/Focus Veil.app`, verifies its signature, and launches it. Use `--skip-build` only when `dist/Focus Veil.app` is already a verified build:

```sh
./scripts/install-local.sh --skip-build
```

## Permissions

Focus Veil is intended to ask only for Accessibility access once focused-window tracking is implemented. It must never request Screen Recording permission. If Accessibility access is unavailable or revoked, the eventual effect will fail open by showing no overlay.

## Current limitations

- Phase 1 has an empty menu-bar skeleton; it does not yet blur or dim windows.
- No preferences, global shortcut, launch-at-login support, updater, analytics, or network access are included.
- This build is for local use on this Mac. It is not notarized or intended for distribution to other Macs.

## Uninstall

Quit Focus Veil, then delete `/Applications/Focus Veil.app`. There are no helper processes, launch agents, or other files to remove.
