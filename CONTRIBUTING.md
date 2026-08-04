# Contributing to muglock

Thanks for your interest in contributing. Here's how to get started.

## Getting started

1. Fork and clone the repo
2. You need `quickshell` (>= 0.3) and a Wayland session; `howdy` is optional —
   mock mode covers everything it does
3. Run the checks: every unit ships a runnable test under `scripts/`

```bash
scripts/test-chirp.sh
scripts/test-stub.sh
scripts/test-qml-loads.sh shell/DevPreview.qml
scripts/test-scanner.sh
scripts/test-ipc.sh
scripts/test-install.sh
scripts/test-deb.sh        # needs dpkg + makepkg
```

4. Hack with zero privileges and no camera:

```bash
MUGLOCK_DEV=1 MUGLOCK_MOCK=ok qs -p shell
qs -p shell ipc call muglock wake
```

## Branch model

- `main` receives releases and reviewed PRs. Features/fixes go on `feature/*`
  branches and arrive as PRs.
- Run the full `scripts/test-*.sh` suite before pushing — it must be green.

## Claiming an issue

Assign yourself or leave a comment before implementing, so parallel work
doesn't produce duplicate PRs. If an **AI agent** leaves the claim comment, it
must name the model and platform. (This repo is 100% vibe-coded; agents are
first-class contributors here, but they follow the same rules as everyone.)

## ⚠️ Never edit `shell/` while your screen is locked

`install.sh` symlinks `~/.config/quickshell/muglock` straight at the repo, and
quickshell hot-reloads on file change. Saving a file with a syntax error kills
the running instance — and if that happens while the session is locked, the
compositor keeps the session hidden (that is `ext-session-lock` behaving
correctly), so you are looking at a black screen with nothing to type into. The
way out is a tty (see README § Recovery), not a reboot.

Develop against a copy in dev mode (`MUGLOCK_DEV=1 ... qs -p shell`), and let
the symlinked instance be the one you actually lock with.

## Ground rules

- **The password path is sacred.** Whatever you do to animations, scanning, or
  timing: a correct password must unlock in every state, and no animation state
  may ever block an authenticated unlock. There is a watchdog for a reason.
- muglock never writes `/etc/pam.d/*`, and the sudoers drop-in stays exactly
  one command, validated with `visudo -cf`.
- QML API claims are verified against the installed qmltypes
  (`/usr/lib/qt6/qml/Quickshell/**/*.qmltypes`) — quickshell moves fast and
  guessed API names are the #1 source of broken PRs.
- New non-trivial logic ships with a runnable check under `scripts/`,
  following the existing `test-*.sh` shape.
- Docs, comments, and commit messages in English.

## Hardware caveats worth knowing

Real cameras are not the ideal on paper (see the git history for the scars):

- facetimehd's low-res modes **crop the sensor corner** instead of scaling —
  always request the native resolution in howdy's config
- `sudo` cannot forward SIGKILL — the scan time-box must live *inside* the
  granted command (`timeout(1)`)
- input methods (fcitx5) deliver composed keys with an empty `event.text`;
  never use "non-text key" heuristics around the password field
