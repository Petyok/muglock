#!/usr/bin/env bash
# Synthesizes the muglock success chirp: D5 tap into A5 ring, ~0.45 s.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets

# ponytail: ffmpeg's `sine` source is not full scale (~-18 dBFS on ffmpeg 8), so the
# mix needs make-up gain to land near -6 dBFS. Tune by ear / for other ffmpeg builds:
#   CHIRP_GAIN=3.0 ./scripts/make-chirp.sh
gain=${CHIRP_GAIN:-2.4}

ffmpeg -y -v error \
  -f lavfi -i "sine=frequency=587.33:duration=0.14" \
  -f lavfi -i "sine=frequency=880:duration=0.30" \
  -filter_complex "\
[0]afade=t=in:d=0.012,afade=t=out:st=0.10:d=0.04[a];\
[1]adelay=110|110,afade=t=in:d=0.012,afade=t=out:st=0.22:d=0.18[b];\
[a][b]amix=inputs=2:normalize=0,volume=${gain}" \
  -c:a libvorbis shell/assets/chirp.ogg
echo "wrote shell/assets/chirp.ogg"
