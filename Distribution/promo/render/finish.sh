#!/usr/bin/env bash
# Une los segmentos del render, masteriza el audio (−14 LUFS, −1 dBTP, estándar
# de Reels/TikTok) y exporta los dos entregables en Distribution/promo/.
set -euo pipefail
cd "$(dirname "$0")"
FF=${FFMPEG:-ffmpeg}
V=${V:-1}   # V=2 ./finish.sh para el reel v2
SEG=out/segments_v${V}_2x_60
DEST=..
# el 4K de 45 s se limita a 15 Mbps para quedar bajo los 100 MB por archivo de GitHub
if [ "$V" = 2 ]; then AUDIO=out/audio_v2.wav; NAME=FisuEvolution_Reel_v2_45s; RATE=15; else AUDIO=out/audio.wav; NAME=FisuEvolution_Reel_30s; RATE=22; fi

"$FF" -y -loglevel error -f concat -safe 0 -i "$SEG/list.txt" -c copy out/video_master_v${V}.mp4

"$FF" -y -loglevel error -i "$AUDIO" \
  -af "loudnorm=I=-14:TP=-1.0:LRA=9" -ar 48000 out/audio_master_v${V}.wav

# 4K UHD 2160×3840 · 60 fps (dentro del máximo que aceptan Meta y TikTok)
"$FF" -y -loglevel error -i out/video_master_v${V}.mp4 -i out/audio_master_v${V}.wav \
  -map 0:v -map 1:a -c:v libx264 -preset slow -crf 17 -maxrate ${RATE}M -bufsize $((RATE * 2))M \
  -tune animation -profile:v high -level 5.2 -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -c:a aac -b:a 320k -movflags +faststart -shortest \
  "$DEST/${NAME}_4K.mp4"

# 1080×1920 · 60 fps para subir directo
"$FF" -y -loglevel error -i out/video_master_v${V}.mp4 -i out/audio_master_v${V}.wav \
  -map 0:v -map 1:a -vf "scale=1080:1920:flags=lanczos" \
  -c:v libx264 -preset slow -crf 16 -maxrate 12M -bufsize 24M \
  -tune animation -profile:v high -level 4.2 -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -c:a aac -b:a 320k -movflags +faststart -shortest \
  "$DEST/${NAME}_1080.mp4"

ls -la "$DEST"/*.mp4
