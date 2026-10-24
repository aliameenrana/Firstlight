#!/bin/sh
# Normalizes audio-source/*.m4a to -16 LUFS and writes bundle-ready .caf files to Sounds/.
set -e
cd "$(dirname "$0")/.."
mkdir -p Sounds
tmp=$(mktemp -d)
for f in audio-source/*.m4a; do
  name=$(basename "$f" .m4a | sed -E 's/^[0-9]+ - //')
  [ "$name" = "Timer Sound" ] && continue
  ffmpeg -loglevel error -y -i "$f" -af loudnorm=I=-16:TP=-1.5 -ar 44100 "$tmp/n.wav"
  afconvert -f caff -d aac -b 192000 "$tmp/n.wav" "Sounds/$name.caf"
done
rm -rf "$tmp"
