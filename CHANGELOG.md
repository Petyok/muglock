# Changelog

All notable changes to muglock are documented in this file.

## [Unreleased]

## [0.1.1] - 2026-08-05

### Fixed

- **Runtime assets never loaded in a real install.** The installed config is a
  symlink and `Quickshell.shellPath()` resolves against it, so `../assets/...`
  pointed outside the config directory: the unlock chirp silently never played
  and the background dither never rendered. Assets moved into `shell/assets/`,
  and `scripts/test-symlinked-config.sh` now runs the shell through a symlink —
  the coverage gap that let this ship (every other test launches from the repo).
- **A failed scan could wedge the camera until the module was reloaded.** The UI
  cap fired before the kernel-side cap and SIGKILLed `sudo`, orphaning the
  process that held the camera; the orphan was then killed mid-capture, leaving
  facetimehd unable to deliver frames. Teardown is SIGTERM (relayed down to
  python3, so OpenCV releases the device), and the ladder now fires inside-out.
- **Every scan reported "Camera unavailable" with a working camera.** howdy
  counts its scan window from the first captured frame, so a 9 s window plus
  startup landed exactly on the hard cap. Window shortened, and `timeout(1)`'s
  own exit codes read as a timeout rather than a backend fault.
- **A wrong password locked out the password path entirely.** PAM was answered on
  a `responseRequired` transition, which only fires once per process; every later
  attempt waited forever. Answered per PAM message now, with Escape as an abort.
- **The second unlock in a session could hang on the checkmark.** A stale mapped-
  overlay count stalled the handoff; overlays are now armed at lock time, a
  watchdog unlocks without the animation, and an authenticated unlock always wins.
- Typing a password no longer restarts the camera (input methods deliver composed
  keys with an empty `event.text`, which defeated the old "non-text key" test).
- Gradient banding on the background: the palette spans ~38 blue values across the
  screen, so an exact 8-bit gradient can only render as ~24 px stripes. A tiled
  neutral dither breaks them (measured: 18.4 px average run -> 1.1 px).

### Added

- Honest failure copy: "didn't recognize you" is now shown only when howdy really
  looked and did not match; a busy camera, a dark room, a timeout and a broken
  config each say what happened.
- Keyboard layout chip in the password pill, highlighted when the layout is not
  EN — a hidden-echo field plus a wrong layout is how a correct password "stops
  working".
- Auto-retry feedback: the plaque shakes its head every few seconds while a scan
  is still running (retries are howdy's own frame loop, so the camera stays hot).
- Bounded liveness trace in the log, ticking only during transient phases, so a
  future wedge can be diagnosed without a witness.

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
