#!/usr/bin/env bash
# muglock installer: deps, quickshell config symlink, sudoers drop-in, integration hints.
# Idempotent. Usage: ./install.sh [--dry-run]
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
USER_NAME=${USER:-$(id -un)}
CONFIG_LINK="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/muglock"
SUDOERS_FILE=/etc/sudoers.d/muglock
# timeout(1) is inside the granted command on purpose: sudo cannot forward SIGKILL
# to its child, so the hard cap on the camera has to be owned kernel-side.
SUDOERS_LINE="$USER_NAME ALL=(root) NOPASSWD: /usr/bin/timeout --signal=TERM --kill-after=2 11 /usr/lib/howdy/howdy-compare $USER_NAME"

DRY_RUN=0
case "${1:-}" in
  --dry-run) DRY_RUN=1 ;;
  "") ;;
  *) echo "usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
# Every side effect goes through run(): printed always, executed only for real.
run() {
  printf '+ %s\n' "$*"
  [ "$DRY_RUN" -eq 1 ] || "$@"
}

step "1. Detect distro"
distro=unknown
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  distro=$(. /etc/os-release && printf '%s' "${ID:-unknown}")
fi
say "distro ID: $distro"

step "2. Dependencies (howdy, quickshell)"
case "$distro" in
  arch|archarm|manjaro|endeavouros)
    # pacman -T lists deps not satisfied by any installed package or provider,
    # so an installed howdy-bin/howdy-git correctly satisfies "howdy" here.
    missing=$(pacman -T howdy quickshell || true)
    if [ -z "$missing" ]; then
      say "howdy and quickshell already present, nothing to install"
    else
      helper=""
      for h in paru yay; do command -v "$h" >/dev/null && { helper=$h; break; }; done
      if [ -n "$helper" ]; then
        # shellcheck disable=SC2086
        run "$helper" -S --needed $missing
      else
        say "No AUR helper found. Install manually:"
        say "  paru -S --needed $missing"
      fi
    fi
    ;;
  debian|ubuntu|pop|linuxmint)
    say "No silent installs on this distro. Do these by hand:"
    say "  howdy-next has no apt package — install it from https://codeberg.org/nathawat/howdy-next"
    say "  quickshell has no apt package — build it: https://quickshell.org/docs/guide/install/"
    ;;
  *)
    say "Unknown distro — install howdy-next and quickshell (>= 0.3) yourself:"
    say "  howdy-next: https://codeberg.org/nathawat/howdy-next"
    say "  quickshell: https://quickshell.org/docs/guide/install/"
    ;;
esac

step "3. Symlink $REPO/shell -> $CONFIG_LINK"
if [ "$(readlink -f "$CONFIG_LINK" 2>/dev/null)" = "$REPO/shell" ]; then
  say "already linked, nothing to do"
else
  run mkdir -p "$(dirname "$CONFIG_LINK")"
  run ln -sfn "$REPO/shell" "$CONFIG_LINK"
fi

step "4. sudoers drop-in $SUDOERS_FILE (mode 0440)"
say "line: $SUDOERS_LINE"
current=""
# Reading the drop-in needs root; skip that (and every other sudo call) in dry-run.
if [ "$DRY_RUN" -eq 0 ]; then
  current=$(sudo cat "$SUDOERS_FILE" 2>/dev/null || true)
fi
if [ "$current" = "$SUDOERS_LINE" ]; then
  say "already present and identical, nothing to do"
else
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  printf '%s\n' "$SUDOERS_LINE" >"$tmp"
  if command -v visudo >/dev/null; then
    visudo -cf "$tmp" >/dev/null || { echo "ABORT: visudo rejected the sudoers line" >&2; exit 1; }
    say "visudo -cf: OK"
  else
    echo "ABORT: visudo not found — install sudo (it ships visudo) and re-run" >&2
    exit 1
  fi
  run sudo install -o root -g root -m 0440 "$tmp" "$SUDOERS_FILE"
fi

# The drop-in is dead weight if /etc/sudoers never includes sudoers.d —
# some setups ship the includedir line commented out.
if [ "$DRY_RUN" -eq 0 ]; then
  # Both '@includedir' (current) and '#includedir' (legacy directive, not a
  # comment) count as active; '#@includedir' / '# includedir' do not.
  if ! sudo grep -qE '^\s*(@includedir|#includedir)\s+/etc/sudoers\.d' /etc/sudoers; then
    say "WARNING: /etc/sudoers does not appear to include /etc/sudoers.d"
    say "         (no active '@includedir /etc/sudoers.d' line). The drop-in"
    say "         will be ignored until you enable it via 'sudo visudo'."
  fi
fi

step "5. Manual steps left for you (nothing is auto-edited)"
say "Enroll your face:"
say "  sudo howdy add   # howdy-next 3.x"
say "Verify recognition without a password prompt:"
say "  sudo -n /usr/lib/howdy/howdy-compare $USER_NAME"
say "Add these two lines to the general{} block of ~/.config/hypridle.conf:"
say '  lock_cmd = qs -p ~/.config/quickshell/muglock ipc call muglock lock'
say '  after_sleep_cmd = qs -p ~/.config/quickshell/muglock ipc call muglock wake'
say "Add this line to ~/.config/hypr/hyprland.conf (smooth unlock fade needs it):"
say '  layerrule = no_anim on, match:namespace ^muglock-fade$'
say "Then reload hypridle and try: qs -p ~/.config/quickshell/muglock ipc call muglock lock"

[ "$DRY_RUN" -eq 1 ] && say $'\n(dry run — nothing above was executed)'
exit 0
