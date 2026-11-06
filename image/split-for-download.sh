#!/bin/bash
# Splits st-peter-usb.img.xz into pieces small enough to send (default 190 MB each) and writes
# "Join St Peter image.cmd", which puts them back together on Windows and checks the result.
#   image/split-for-download.sh path/to/st-peter-usb.img.xz out-folder [piece-MB]
set -euo pipefail
X="$1"; OUT="$2"; MB="${3:-190}"
mkdir -p "$OUT"; rm -f "$OUT"/st-peter-usb.img.xz.part* "$OUT/Join St Peter image.cmd"
size=$(stat -c%s "$X"); n=$(( (size + MB*1048576 - 1) / (MB*1048576) ))
split -n "$n" -d -a 2 "$X" "$OUT/tmp.part"
i=1; for f in "$OUT"/tmp.part*; do mv "$f" "$OUT/st-peter-usb.img.xz.part$i"; i=$((i+1)); done
H=$(sha256sum "$X" | cut -d' ' -f1)
list=""; for i in $(seq 1 "$n"); do list+="\"st-peter-usb.img.xz.part$i\" + "; done; list="${list% + }"
printf '%s\r\n' '@echo off' \
  "rem Puts the $n downloaded pieces back together into st-peter-usb.img.xz (for balenaEtcher)." \
  "rem Keep this file in the same folder as the $n pieces and double-click it." \
  'cd /d "%~dp0"' 'echo Joining the St. Peter USB stick image...' \
  "copy /b $list \"st-peter-usb.img.xz\" >nul || goto bad" \
  "powershell -NoProfile -Command \"if ((Get-FileHash 'st-peter-usb.img.xz' -Algorithm SHA256).Hash -eq '$H') { exit 0 } else { exit 1 }\" || goto bad" \
  'echo.' 'echo Done! Open balenaEtcher, choose "Flash from file" and pick st-peter-usb.img.xz' 'echo.' 'pause' 'exit /b 0' \
  ':bad' 'echo.' "echo Something is wrong with the downloaded pieces. Download all $n again into this folder." 'pause' 'exit /b 1' \
  > "$OUT/Join St Peter image.cmd"
[ "$(cat $(for i in $(seq 1 "$n"); do echo "$OUT/st-peter-usb.img.xz.part$i"; done) | sha256sum | cut -d' ' -f1)" = "$H" ] \
  && echo "$n pieces, verified" || { echo "pieces don't match!"; exit 1; }
