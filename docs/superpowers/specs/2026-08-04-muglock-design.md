# muglock — Design

macOS-style FaceID unlock for Linux (Wayland/Hyprland): a custom quickshell
lockscreen with smooth animations, face recognition via howdy, and a chirp
sound on success. Public repo (GitHub, MIT), distributed via AUR and a .deb
attached to GitHub Releases.

## Context and constraints

- Author's target machine: MacBook Air 2015, Apple FaceTime HD camera
  (`/dev/video0`, facetimehd driver), RGB only — no IR. Arch, Hyprland,
  quickshell 0.3, hypridle (already manages lid/lock/suspend), PipeWire.
- RGB camera ⇒ recognition can be fooled by a photo. muglock is a
  convenience, not a security boundary. Stated prominently in the README.
- The camera must not run continuously: scanning starts only on wake
  events, is time-boxed (~10 s), then the camera is released.

## Scope

**In:** screen unlock by face + status widget ("plaque") + sound. Password
fallback at all times.
**Out (non-goals):** face auth for sudo/polkit/login; IR/liveness
detection; npm/pypi/crates packaging (this is QML + bash, not a library);
a self-hosted PPA/apt repository (maintenance treadmill; a prebuilt .deb
in GitHub Releases instead — see Distribution); non-Hyprland compositors
in v1 (WlSessionLock is a standard protocol, but only Hyprland is tested).

## Architecture

Three components, one repository:

1. **Lockscreen** — a quickshell config (QML), separate from the user's
   own `shell.qml`: runs as `qs -c muglock`. Contains:
   - `WlSessionLock` — the lock itself (standard ext-session-lock).
   - Clock/date/background (parity with the author's current hyprlock
     config).
   - Password field via `PamContext` (plain system PAM stack, no howdy) —
     the fallback lives independently of the camera.
   - FaceID plaque — an animation state machine (see Unlock flow).
   - `Process` — spawns `sudo howdy compare <user>`, judges by exit code.
   - IPC handlers (`qs ipc`): `lock`, `wake` (restart the scan).
2. **Integration** — lines in `hypridle.conf`: on-lock → `qs -c muglock
   ipc call ... lock`, on-resume → `... wake`. Plus a sudoers drop-in:
   `<user> ALL=(root) NOPASSWD: /usr/bin/howdy compare <user>` — exactly
   one command, not all of howdy.
3. **Sound** — `scripts/make-chirp.sh` synthesizes a short two-tone chirp
   (ffmpeg, sine), stored in assets; played with `paplay` from a QML
   Process. Tone tuned iteratively by ear during development; the file is
   committed to the repo.

## Unlock flow (plaque state machine)

```
LOCKED (screen woke up / ipc wake)
  → SCANNING: face icon pulses + scanline; howdy compare running
      ── exit 0 → SUCCESS: spring checkmark + chirp, ~500 ms of beauty
      │            → lock.locked = false (unlock)
      ── exit ≠0 / ~10 s timeout → FAILED: "didn't recognize you — type
                   your password or press any key"; camera released
  FAILED --any key--> SCANNING (new attempt)
  * the password field is active in every state (PamContext), Enter → PAM
```

Note: aborting an in-flight scan on display-off (dpms) is out of scope for
v1 — the 10 s scan time-box already bounds camera usage, and hypridle
re-triggers `wake` on resume. Revisit if the camera LED bothers anyone.

Animations: QML easing/spring (Behavior, NumberAnimation, scale+opacity);
reference — mockup C chosen during brainstorming.

## Failure modes and recovery

- howdy/camera dies → FAILED state, password still works. A hard timeout
  on the Process is mandatory (the camera may hang — facetimehd is not
  perfect).
- quickshell crashes while locked → Hyprland keeps the session hidden per
  ext-session-lock (black screen, not the desktop). Emergency path: tty →
  `hyprlock` (kept installed) or `loginctl unlock-session`. Documented in
  the README ("Recovery").
- PAM configuration is never touched (PamContext reads the system stack)
  ⇒ zero risk of locking yourself out via PAM edits.

## Repository

```
muglock/
  shell/           # quickshell config (shell.qml + components)
  scripts/         # make-chirp.sh, make-deb.sh, howdy stub for mock mode
  assets/          # chirp.ogg
  install.sh       # distro-aware: deps, sudoers drop-in, hypridle lines, config symlink
  PKGBUILD         # AUR distribution
  README.md        # GIF, install, security disclaimer, recovery, "100% vibecoded" badge
  LICENSE          # MIT
```

The README MUST carry a prominent **"100% vibecoded"** badge plus a line
stating the entire codebase was written by Claude in dialogue — author's
requirement, do not remove during edits.

## Distribution

- **AUR** — PKGBUILD in the repo, primary channel (the Hyprland audience
  ≈ Arch).
- **.deb in GitHub Releases** — `scripts/make-deb.sh` builds the package
  with `dpkg-deb`; the file is attached to each release. quickshell/howdy
  don't exist in apt ⇒ they are not declared in Depends; postinst checks
  for them and prints what's missing and where to get it. Cheap: one
  script, zero infrastructure.
- **install.sh** — detects the distro and installs deps as best it can
  (Arch — AUR; Ubuntu/Debian — howdy PPA + quickshell build pointer).

## Promotion (after v1, GIF required)

The animation GIF is the primary asset — nothing gets posted without it.
Channels by expected payoff:

1. **r/unixporn** — the perfect format (rice video/GIF), main star source.
2. **r/hyprland** + Hyprland Discord (#showcase) — exact target audience.
3. **Show HN** — "macOS-style FaceID for Linux" — clear headline, will land.
4. **awesome-hyprland** and similar lists — PR with a link.
5. AUR listing is a channel by itself (`paru -Ss faceid/face`).
6. Mastodon/X Linux crowd, r/archlinux — leftovers.

## Decisions made during brainstorming

- Option C (own QML lockscreen) chosen over a hyprlock text plaque (B) for
  real animations; full PAM coverage (sudo/login) rejected — YAGNI.
- Scan on wake + limited attempts, not continuous (battery/camera LED).
- Chirp is synthesized, not taken from a system theme.
- Name: **muglock** (mug = face, lock = lock).
- Docs and code comments in English — the target audience is
  English-speaking. Implementation delegated to Opus-class subagents with
  explicit interface contracts, per the author's standard workflow.
