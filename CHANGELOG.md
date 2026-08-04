# Changelog

All notable changes to muglock are documented in this file.

## [Unreleased]

## [0.1.0] - 2026-08-05

### Added

- quickshell (QML) lockscreen on `ext-session-lock`: gradient background,
  clock, date, FaceID plaque, password pill — one surface per screen
- Face recognition via howdy 2.6.x (`compare.py`), spawned from QML with a
  kernel-side hard cap: `sudo timeout --signal=KILL 12` wraps the scan so a
  hung camera can never be held open
- Animated plaque state machine: pulsing face icon + scanline while scanning,
  spring checkmark + synthesized chirp on success, calm hint on failure
- Seamless fade-to-desktop on unlock: a pixel-identical overlay layer is armed
  at lock time, the session lock drops behind it, and the overlay dissolves
  over the live desktop; a watchdog guarantees the animation can never block
  an authenticated unlock
- Password fallback via PAM (`PamContext`, the same `login` service hyprlock
  uses), active in every state; Escape aborts a wedged conversation
- Keyboard layout chip in the password pill (hyprctl seed + `activelayout`
  IPC events), highlighted when the layout is not EN
- Rescan gestures: Enter on an empty field, click on the plaque, IPC `wake`
- Mock (`MUGLOCK_MOCK`, gated behind dev mode) and dev (`MUGLOCK_DEV=1`)
  modes: full development with no root, camera, or session lock
- `install.sh` (distro-aware, idempotent, `--dry-run`), PKGBUILD, and
  `scripts/make-deb.sh` producing the release .deb
- Runnable checks for every unit under `scripts/test-*.sh`
