#!/usr/bin/env bash
#
# Generate placeholder media files for DDEX delivery test packages.
# Requires: ffmpeg, ImageMagick (convert/magick)
#
# Usage: ./scripts/generate_placeholder_media.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$PROJECT_ROOT/priv/ddex/packages"

# Detect ImageMagick command (v7 uses "magick", v6 uses "convert")
if command -v magick &>/dev/null; then
  CONVERT="magick"
elif command -v convert &>/dev/null; then
  CONVERT="convert"
else
  echo "Error: ImageMagick not found. Install with: brew install imagemagick" >&2
  exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
  echo "Error: ffmpeg not found. Install with: brew install ffmpeg" >&2
  exit 1
fi

# Generate a sine-wave audio file
# Args: output_path format duration_seconds frequency
generate_audio() {
  local output="$1"
  local format="$2"
  local duration="$3"
  local freq="$4"

  if [[ -f "$output" ]]; then
    echo "  Skip (exists): $(basename "$output")"
    return
  fi

  echo "  Audio: $(basename "$output") (${duration}s @ ${freq}Hz)"
  ffmpeg -y -loglevel error \
    -f lavfi -i "sine=frequency=${freq}:duration=${duration}" \
    -ac 2 -ar 44100 \
    "$output"
}

# Generate a colored cover image with text overlay
# Args: output_path bg_color title artist dimensions
generate_cover() {
  local output="$1"
  local bg_color="$2"
  local title="$3"
  local artist="$4"
  local size="${5:-3000x3000}"

  if [[ -f "$output" ]]; then
    echo "  Skip (exists): $(basename "$output")"
    return
  fi

  echo "  Image: $(basename "$output") ($size)"
  $CONVERT -size "$size" "xc:${bg_color}" \
    -gravity center \
    -fill white -pointsize 120 -annotate +0-100 "$title" \
    -fill '#cccccc' -pointsize 60 -annotate +0+50 "$artist" \
    -quality 95 \
    "$output"
}

# Generate a simple PDF placeholder
# Args: output_path title artist
generate_booklet() {
  local output="$1"
  local title="$2"
  local artist="$3"

  if [[ -f "$output" ]]; then
    echo "  Skip (exists): $(basename "$output")"
    return
  fi

  echo "  PDF: $(basename "$output")"
  # Create a temporary image and convert to PDF
  local tmp_img
  tmp_img="$(mktemp /tmp/booklet_XXXXXX.jpg)"
  $CONVERT -size 2480x3508 'xc:#1a1a2e' \
    -gravity center \
    -fill white -pointsize 100 -annotate +0-200 "$title" \
    -fill '#aaaaaa' -pointsize 50 -annotate +0+0 "$artist" \
    -fill '#666666' -pointsize 40 -annotate +0+200 "Digital Booklet" \
    -quality 90 \
    "$tmp_img"
  $CONVERT "$tmp_img" "$output"
  rm -f "$tmp_img"
}

echo "=== Glass Garden (ERN 4.3 Album) ==="
GLASS_DIR="$PACKAGES_DIR/glass_garden_ern43/resources"
mkdir -p "$GLASS_DIR"

# 8 tracks as FLAC - unique frequencies per track
generate_audio "$GLASS_DIR/GBX0425000101.flac" flac 258 261  # Prism Light — 4:18
generate_audio "$GLASS_DIR/GBX0425000102.flac" flac 222 293  # Soft Machine — 3:42
generate_audio "$GLASS_DIR/GBX0425000103.flac" flac 307 329  # Dissolve — 5:07
generate_audio "$GLASS_DIR/GBX0425000104.flac" flac 295 349  # Glass Garden — 4:55
generate_audio "$GLASS_DIR/GBX0425000105.flac" flac 209 392  # Tidal — 3:29
generate_audio "$GLASS_DIR/GBX0425000106.flac" flac 273 440  # Moth to Neon — 4:33
generate_audio "$GLASS_DIR/GBX0425000107.flac" flac 231 493  # Afterimage — 3:51
generate_audio "$GLASS_DIR/GBX0425000108.flac" flac 372 523  # Still Water — 6:12

generate_cover "$GLASS_DIR/cover_front.jpg" '#2d5a3d' "Glass Garden" "Mara Chen"
generate_booklet "$GLASS_DIR/booklet.pdf" "Glass Garden" "Mara Chen"

echo ""
echo "=== Copper Sun (ERN 3.8.2 Single) ==="
COPPER_DIR="$PACKAGES_DIR/copper_sun_ern382/resources"
mkdir -p "$COPPER_DIR"

# 2 tracks as WAV
generate_audio "$COPPER_DIR/GBAYE2500001.wav" wav 234 330  # Copper Sun — 3:54
generate_audio "$COPPER_DIR/GBAYE2500002.wav" wav 251 220  # Copper Sun (Acoustic) — 4:11

generate_cover "$COPPER_DIR/cover_front.jpg" '#8b4513' "Copper Sun" "The Midnight Wire"

echo ""
echo "=== Night Market (ERN 4.3 EP) ==="
NIGHT_DIR="$PACKAGES_DIR/night_market_ern43/resources"
mkdir -p "$NIGHT_DIR"

# 5 tracks as FLAC (24-bit)
generate_audio "$NIGHT_DIR/FRZ0425000201.flac" flac 332 130  # Night Market — 5:32
generate_audio "$NIGHT_DIR/FRZ0425000202.flac" flac 288 155  # Jade Lantern — 4:48
generate_audio "$NIGHT_DIR/FRZ0425000203.flac" flac 375 174  # Silk Road — 6:15
generate_audio "$NIGHT_DIR/FRZ0425000204.flac" flac 262 196  # Golden Hour — 4:22
generate_audio "$NIGHT_DIR/FRZ0425000205.flac" flac 404 110  # Night Market (Kira Remix) — 6:44

generate_cover "$NIGHT_DIR/cover_front.jpg" '#1a0a2e' "Night Market" "DJ Sable"

echo ""
echo "Done. Generated placeholder media in:"
echo "  $PACKAGES_DIR/glass_garden_ern43/resources/"
echo "  $PACKAGES_DIR/copper_sun_ern382/resources/"
echo "  $PACKAGES_DIR/night_market_ern43/resources/"
