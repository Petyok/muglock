#!/usr/bin/env bash
# Checks the committed success chirp: present, ogg/vorbis, short.
set -euo pipefail
cd "$(dirname "$0")/.."
f=shell/assets/chirp.ogg
[ -f "$f" ] || { echo "FAIL: $f missing"; exit 1; }
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
awk -v d="$dur" 'BEGIN{exit !(d>0.2 && d<=1.0)}' || { echo "FAIL: duration $dur"; exit 1; }
# Captured, not piped into `grep -q` — see test-deb.sh for why that combination
# is a SIGPIPE trap under `pipefail`.
codec=$(ffprobe -v error -show_entries stream=codec_name -of csv=p=0 "$f")
grep -q vorbis <<<"$codec" || { echo "FAIL: not vorbis"; exit 1; }
echo PASS
