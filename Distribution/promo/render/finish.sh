#!/usr/bin/env bash
# Une los segmentos del render, masteriza el audio (−14 LUFS, −1 dBTP, estándar
# de Reels/TikTok) y exporta los dos entregables en Distribution/promo/.
set -euo pipefail
cd "$(dirname "$0")"
FF=${FFMPEG:-ffmpeg}
V=${V:-1}   # V=2…5 ./finish.sh para los otros reels
L=${L:-es}  # L=en → versión EE. UU. (segmentos de render.mjs --lang en), a en-US/
TAG=$([ "$L" = es ] && echo "" || echo "_$L")
SEG=out/segments_v${V}${TAG}_2x_60
DEST=..
# el 4K se limita (RATE, Mbps) para quedar bajo los 100 MB por archivo de GitHub
case "$V" in
  1) AUDIO=out/audio.wav;    NAME=FisuEvolution_Reel_30s;        RATE=22 ;;
  2) AUDIO=out/audio_v2.wav; NAME=FisuEvolution_Reel_v2_45s;     RATE=15 ;;
  3) AUDIO=out/audio_v3.wav; NAME=FisuEvolution_Reel_v3_Top5;    RATE=20 ;;
  4) AUDIO=out/audio_v4.wav; NAME=FisuEvolution_Reel_v4_Dia365;  RATE=20 ;;
  5) AUDIO=out/audio_v5.wav; NAME=FisuEvolution_Reel_v5_Quiz;    RATE=20 ;;
  7) AUDIO=out/audio_v7.wav; NAME=FisuEvolution_TOFU_v7_PausaQueFisuraSos; RATE=22 ;;
  8) AUDIO=out/audio_v8.wav; NAME=FisuEvolution_MOFU_v8_TomiVsSofi;        RATE=20 ;;
  9) AUDIO=out/audio_v9.wav; NAME=FisuEvolution_BOFU_v9_TuPrimerMinuto;    RATE=22 ;;
  *) echo "V desconocida: $V" >&2; exit 1 ;;
esac
if [ "$L" = en ]; then
  DEST=../en-US; mkdir -p "$DEST"
  case "$V" in
    1) NAME=HoboEvolution_EN_MOFU_FromBrokeToGod ;;
    2) NAME=HoboEvolution_EN_MOFU_WhatsOnTheTopFloor ;;
    3) NAME=HoboEvolution_EN_TOFU_Top5Unhinged ;;
    4) NAME=HoboEvolution_EN_TOFU_Day1To365 ;;
    5) NAME=HoboEvolution_EN_TOFU_Quiz ;;
    7) NAME=HoboEvolution_EN_TOFU_PauseWhichOneAreYou ;;
    8) NAME=HoboEvolution_EN_MOFU_JakeVsEmma ;;
    9) NAME=HoboEvolution_EN_BOFU_YourFirstMinute ;;
  esac
fi

"$FF" -y -loglevel error -f concat -safe 0 -i "$SEG/list.txt" -c copy out/video_master_v${V}${TAG}.mp4

"$FF" -y -loglevel error -i "$AUDIO" \
  -af "loudnorm=I=-14:TP=-1.0:LRA=9" -ar 48000 out/audio_master_v${V}${TAG}.wav

# 4K UHD 2160×3840 · 60 fps (dentro del máximo que aceptan Meta y TikTok)
"$FF" -y -loglevel error -i out/video_master_v${V}${TAG}.mp4 -i out/audio_master_v${V}${TAG}.wav \
  -map 0:v -map 1:a -c:v libx264 -preset slow -crf 17 -maxrate ${RATE}M -bufsize $((RATE * 2))M \
  -tune animation -profile:v high -level 5.2 -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -c:a aac -b:a 320k -movflags +faststart -shortest \
  "$DEST/${NAME}_4K.mp4"

# 1080×1920 · 60 fps para subir directo
"$FF" -y -loglevel error -i out/video_master_v${V}${TAG}.mp4 -i out/audio_master_v${V}${TAG}.wav \
  -map 0:v -map 1:a -vf "scale=1080:1920:flags=lanczos" \
  -c:v libx264 -preset slow -crf 16 -maxrate 12M -bufsize 24M \
  -tune animation -profile:v high -level 4.2 -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -c:a aac -b:a 320k -movflags +faststart -shortest \
  "$DEST/${NAME}_1080.mp4"

ls -la "$DEST"/*.mp4
