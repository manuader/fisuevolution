#!/usr/bin/env bash
# Arma los tres cortes BOFU: el mejor momento de cada reel + la placa de conversión (v6).
# Requiere los masters de v1, v2, v3 y el render de la placa (segments_v6_2x_60).
set -euo pipefail
cd "$(dirname "$0")"
FF=${FFMPEG:-ffmpeg}
L=${L:-es}  # L=en → cortes en inglés desde en-US/, a en-US/BOFU
TAG=$([ "$L" = es ] && echo "" || echo "_$L")
DEST=../BOFU; SRC=..; B=out/bofu
if [ "$L" = en ]; then DEST=../en-US/BOFU; SRC=../en-US; B=out/bofu_en; fi
mkdir -p "$DEST" $B
# placa BOFU en 4K con su audio
"$FF" -y -loglevel error -f concat -safe 0 -i out/segments_v6${TAG}_2x_60/list.txt -i out/audio_v6.wav \
  -map 0:v -map 1:a -c:v libx264 -preset slow -crf 14 -pix_fmt yuv420p -c:a pcm_s16le -ar 48000 -ac 2 $B/card.mov

cut() { # fuente desde hasta salida
  "$FF" -y -loglevel error -ss "$2" -to "$3" -i "$1" -vf "fps=60" -af "afade=t=out:st=$(python3 -c "print($3-$2-0.15)"):d=0.15" \
    -c:v libx264 -preset slow -crf 14 -pix_fmt yuv420p -c:a pcm_s16le -ar 48000 -ac 2 "$4"
}
join() { # corte salida-base
  "$FF" -y -loglevel error -i "$1" -i $B/card.mov -filter_complex \
    "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a];[a]loudnorm=I=-14:TP=-1.0:LRA=9[an]" \
    -map "[v]" -map "[an]" -c:v libx264 -preset slow -crf 17 -maxrate 20M -bufsize 40M -tune animation \
    -profile:v high -level 5.2 -pix_fmt yuv420p -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
    -c:a aac -b:a 320k -ar 48000 -movflags +faststart "$DEST/${2}_4K.mp4"
  "$FF" -y -loglevel error -i "$DEST/${2}_4K.mp4" -vf "scale=1080:1920:flags=lanczos" \
    -c:v libx264 -preset slow -crf 16 -maxrate 12M -bufsize 24M -tune animation -profile:v high -level 4.2 \
    -pix_fmt yuv420p -color_primaries bt709 -color_trc bt709 -colorspace bt709 -c:a copy -movflags +faststart "$DEST/${2}_1080.mp4"
}
if [ "$L" = en ]; then
  cut $SRC/FisuEvolution_EN_MOFU_WhatsOnTheTopFloor_4K.mp4 6.0 16.4 $B/a.mov
  cut $SRC/FisuEvolution_EN_TOFU_Top5Unhinged_4K.mp4 24.75 30.45 $B/b.mov
  cut $SRC/FisuEvolution_EN_MOFU_FromBrokeToGod_4K.mp4 0 8.0 $B/c.mov
  join $B/a.mov FisuEvolution_EN_BOFU_A_Gameplay
  join $B/b.mov FisuEvolution_EN_BOFU_B_GodIsArgentinian
  join $B/c.mov FisuEvolution_EN_BOFU_C_FromBrokeToGod
else
  cut $SRC/FisuEvolution_Reel_v2_45s_4K.mp4 6.0 16.4 $B/a.mov
  cut $SRC/FisuEvolution_Reel_v3_Top5_4K.mp4 24.75 30.45 $B/b.mov
  cut $SRC/FisuEvolution_Reel_30s_4K.mp4 0 8.0 $B/c.mov
  join $B/a.mov FisuEvolution_BOFU_A_Gameplay
  join $B/b.mov FisuEvolution_BOFU_B_DiosArgentino
  join $B/c.mov FisuEvolution_BOFU_C_DeFisuraADios
fi
ls -la "$DEST"
