#!/usr/bin/env bash
set -euo pipefail
FFMPEG="${FFMPEG:-$HOME/Library/Python/3.9/lib/python/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1}"
SRC="${1:-$PWD/docs/brand/store-assets/asc-screenshots/2026-08-19-v4/iphone-17-pro}"
OUT="${2:-$PWD/docs/brand/store-assets/promo/hiair-promo-v4.mov}"
mkdir -p "$(dirname "$OUT")"
FRAMES=(
  01-auth.png
  01b-onboarding.png
  02-dashboard.png
  03-planner.png
  04-insights.png
  05-symptoms.png
  06-settings.png
  07-paywall.png
)
INPUTS=()
FILTER=""
IDX=0
for frame in "${FRAMES[@]}"; do
  path="$SRC/$frame"
  [[ -f "$path" ]] || { echo "missing $path" >&2; exit 1; }
  INPUTS+=(-loop 1 -t 2.8 -i "$path")
  FILTER+="[${IDX}:v]scale=1206:2622:force_original_aspect_ratio=decrease,pad=1206:2622:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p,tpad=stop_mode=clone:stop_duration=0.2[v${IDX}];"
  IDX=$((IDX + 1))
done
CONCAT=""
for ((i=0; i<IDX; i++)); do
  CONCAT+="[v${i}]"
done
CONCAT+="concat=n=${IDX}:v=1:a=0[v]"
"$FFMPEG" -y "${INPUTS[@]}" -filter_complex "${FILTER}${CONCAT}" -map "[v]" \
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$OUT"
echo "Wrote $OUT"
ls -lh "$OUT"
