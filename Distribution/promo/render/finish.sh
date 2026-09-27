#!/usr/bin/env bash
# Une los segmentos del render, masteriza el audio (−14 LUFS, −1 dBTP, estándar
# de Reels/TikTok) y exporta los dos entregables en Distribution/promo/.
set -euo pipefail
cd "$(dirname "$0")"
FF=${FFMPEG:-ffmpeg}
SEG=out/segments_2x_60
DEST=..

"$FF" -y -loglevel error -f concat -safe 0 -i "$SEG/list.txt" -c copy out/video_master.mp4

"$FF" -y -loglevel error -i out/audio.wav \
  -af "loudnorm=I=-14:TP=-1.0:LRA=9" -ar 48000 out/audio_master.wav

# 4K UHD 2160×3840 · 60 fps · ~20 Mbps (dentro del máximo que aceptan Meta y TikTok)
"$FF" -y -loglevel error -i out/video_master.mp4 -i out/audio_master.wav \
  -map 0:v -map 1:a -c:v libx264 -preset slow -crf 17 -maxrate 22M -bufsize 44M \
  -tune animation -profile:v high -level 5.2 -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -c:a aac -b:a 320k -movflags +faststart -shortest \
  "$DEST/FisuEvolution_Reel_30s_4K.mp4"

# 1080×1920 · 60 fps para subir directo
"$FF" -y -loglevel error -i out/video_master.mp4 -i out/audio_master.wav \
  -map 0:v -map 1:a -vf "scale=1080:1920:flags=lanczos" \
  -c:v libx264 -preset slow -crf 16 -maxrate 12M -bufsize 24M \
  -tune animation -profile:v high -level 4.2 -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -c:a aac -b:a 320k -movflags +faststart -shortest \
  "$DEST/FisuEvolution_Reel_30s_1080.mp4"

ls -la "$DEST"/*.mp4
