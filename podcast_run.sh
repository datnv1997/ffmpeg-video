#!/bin/bash

mkdir -p podcast_output
TMP_DIR="temp_dir"
VIDEO_DIR="podcast_video_resized"
SUB_DIR="subtitles"

mkdir -p "$TMP_DIR"
mkdir -p "$SUB_DIR"

# rm -f "$SUB_DIR"/*.srt

echo "✅Start: "
echo $(date "+%Y-%m-%d %H:%M:%S")

for MAIN_AUDIO in podcast_audio/*.wav; do
  echo "🎧 Đang xử lý: $MAIN_AUDIO"

  # === Tên cơ bản ===
  BASENAME=$(basename "$MAIN_AUDIO" .wav)
  WAV_FILE="$MAIN_AUDIO"
  SRT_FILE="${SUB_DIR}/${BASENAME}.srt"
  MIXED_AUDIO="${TMP_DIR}/${BASENAME}_output.mp3"

  # === Bước 1: Bỏ qua convert ===
  echo "✅ Bỏ qua bước convert, dùng trực tiếp: $WAV_FILE"

  # === Bước 2: Transcribe để tạo SRT ===
  # python transcribe.py "$WAV_FILE" "$SRT_FILE"
  echo "✅ Đã tạo phụ đề: $SRT_FILE"

  # === Bước 3: Mix audio + background ===
  ffmpeg -y -i "$WAV_FILE" -i rainy_road.mp3 -filter_complex "\
    [1:a]aloop=loop=-1:size=2e+09[a1]; \
    [a1]volume=0.6[a1quiet]; \
    [0:a]volume=2[a0]; \
    [a0][a1quiet]amix=inputs=2:duration=first:dropout_transition=3[aout]" \
    -map "[aout]" -shortest "$MIXED_AUDIO"

  echo "✅ Audio đã được mix: $MIXED_AUDIO"

  # === Bước 4: Ghép video ngẫu nhiên ===
  VIDEO_LIST=( $(basename -a "$VIDEO_DIR"/*.mp4) )
  length=${#VIDEO_LIST[@]}
  for ((i=length-1; i>0; i--)); do
    j=$((RANDOM % (i + 1)))
    temp=${VIDEO_LIST[i]}
    VIDEO_LIST[i]=${VIDEO_LIST[j]}
    VIDEO_LIST[j]=$temp
  done

  FILTER=""
  INPUTS=""
  index=0
  for f in "${VIDEO_LIST[@]}"; do
    FILTER+="[$index:v:0]"
    INPUTS+=" -i \"$VIDEO_DIR/$f\""
    ((index++))
  done

  CONCAT="concat=n=$length:v=1:a=0[outv]"
  eval ffmpeg -y $INPUTS \
    -filter_complex "$FILTER$CONCAT" \
    -map "[outv]" \
    -crf 23 -preset ultrafast -r 30 -s 1920x1080 \
    -c:v libx264 -c:a aac -b:a 192k \
    -pix_fmt yuv420p \
    "$TMP_DIR/combined.mp4"

  echo "✅ Video đã được ghép: $TMP_DIR/combined.mp4"

  # === Bước 5: Tính số vòng lặp video ===
  audio_dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$MIXED_AUDIO")
  video_dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TMP_DIR/combined.mp4")
  loops=$(awk -v a="$audio_dur" -v b="$video_dur" 'BEGIN{print int(a/b)+1}')

  rm -f "$TMP_DIR/repeat_list.txt"
  for i in $(seq 1 $loops); do
    echo "file 'combined.mp4'" >> "$TMP_DIR/repeat_list.txt"
  done

  ffmpeg -y -f concat -safe 0 -i "$TMP_DIR/repeat_list.txt" -c copy "$TMP_DIR/looped_video.mp4"

  # === Bước 6: Ghép ảnh, gif, phụ đề và audio ===
  TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
  OUTNAME="podcast_output/${BASENAME}_${TIMESTAMP}.mp4"

  ffmpeg -y \
  -i "$TMP_DIR/looped_video.mp4" \
  -i "$MIXED_AUDIO" \
  -ignore_loop 0 -i podcast.gif \
  -filter_complex "\
    [2:v]scale=280:500[img]; \
    [0:v][img]overlay=W-w-20:H-h-20[tmp1]; \
    movie=man.png,scale=200:200,hflip[man]; \
    [tmp1][man]overlay=20:20[tmp2]; \
    [2:v]scale=250:120[gif]; \
    [tmp2][gif]overlay=20:300:shortest=1[tmp3]; \
    [tmp3]eq=brightness=-0.09[dark]; \
    [dark]subtitles=${SRT_FILE}[outv]" \
  -map "[outv]" -map 1:a \
  -c:v libx264 -crf 23 -preset ultrafast \
  -r 30 -s 1920x1080 \
  -c:a aac -b:a 192k \
  -pix_fmt yuv420p \
  -shortest "$OUTNAME"

  echo "🎬 Đã tạo video: $OUTNAME"

  # === Cleanup tạm thời ===
  rm -f "$TMP_DIR/combined.mp4" "$TMP_DIR/looped_video.mp4" "$MIXED_AUDIO" "$TMP_DIR/repeat_list.txt"
done

echo "✅End: "
echo $(date "+%Y-%m-%d %H:%M:%S")
echo "🎉 Xong toàn bộ!"
