# Changelog

All notable changes to muglock are documented in this file.

## [Unreleased]

### Added

- Speaker icon next to the date shows whether the default sink is muted, so you
  know before unlocking whether the chirp will be heard. Click toggles mute.

## [0.2.0] - 2026-08-18

### Changed

- **Scanner backend is howdy-next 3.x** (#1). Native `howdy-compare` replaces
  howdy 2.x's Python `compare.py`, which removes interpreter startup from the
  scan path: **1.88 s per unlock over five consecutive runs, against 2.9-3.1 s**
  on the same machine and camera. The recognition engine is YuNet + SFace (ONNX)
  rather than dlib, so the match knob is `[face] sface_threshold` instead of
  `certainty`, and the sudoers line names the new helper.
- **Upgrading requires re-enrolling your face.** howdy-next keeps models in its
  own place, so an upgraded machine has a working camera and no enrolled face —
  and `howdy-compare` reports that as exit 10. muglock now says "No face
  enrolled" for it instead of "Camera unavailable"; the old mapping is precisely
  how a healthy webcam came to look broken during this migration.
- Exit 11 (howdy-next's scan window expiring) now reads as "didn't recognize you"
  rather than a timeout: it has no separate no-match code, and from where the
  user sits the two are the same event.

### Added

- `lockNoScan` IPC command: engages the lock without starting a scan, for callers
  that know the camera has nothing to look at. A lid daemon locking a closed
  laptop used to burn several seconds of camera time per close and land on "too
  dark" — a message for someone who can see the screen, drawn on a shut panel.
  The scan happens on the following `wake` instead.

### Fixed

- **An unlock that went through the watchdog left the lock screen pinned over the
  desktop.** `forceUnlock()` cleared `fading` but left `overlayArmed` to
  `fadeAnim.onStopped` — and `stop()` emits nothing when the animation never ran,
  which is exactly that path. The overlay stayed mapped at full opacity and, being
  input-transparent, produced a working cursor under a frozen lock screen until the
  daemon was killed from a tty. Overlay state is now reset unconditionally from
  every exit, and readiness no longer trusts the mapped-window counter alone
  (`backingWindowVisible` also toggles on dpms and across suspend, which is how it
  read 0 for an overlay that had been up for minutes).

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
