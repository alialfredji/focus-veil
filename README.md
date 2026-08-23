# Focus Veil

Focus Veil is a local macOS menu-bar utility that keeps the focused window clear while softly blurring and dimming ordinary windows behind it. It is a personal, native AppKit app with no network access.

The menu-bar control provides a continuous intensity slider and an on/off toggle. A deliberate left-right pointer shake also toggles the effect. The veil fades and moves smoothly, respects Reduce Motion, stays click-through, and hides automatically in Mission Control.

## Requirements

- macOS 14 or later
- Apple Silicon (`arm64`)
- Xcode command-line tools with Swift 6.2 or later

No Screen Recording permission is required. Focus tracking and the pointer-shake gesture use Accessibility access; the app does not use screen capture.

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

Focus Veil asks only for Accessibility access. It never requests Screen Recording permission. If Accessibility access is unavailable or revoked, the effect fails open by showing no overlay.

## Current limitations

- No launch-at-login support, updater, analytics, or network access is included.
- This build is for local use on this Mac. It is not notarized or intended for distribution to other Macs.

## Uninstall

Quit Focus Veil, then delete `/Applications/Focus Veil.app`. There are no helper processes, launch agents, or other files to remove.
