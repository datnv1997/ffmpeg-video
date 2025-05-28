#!/bin/bash
ffmpeg -y -i main_audio.mp3 audio.wav
echo "✅done convert to wav"

# python transcribe.py
# echo "✅done transcribe"

# prepare audio
ffmpeg -y -i audio.wav -i creepy_bg.mp3 -i creepy_bg2.mp3 -filter_complex "\
[1:a][2:a]concat=n=2:v=0:a=1[bg]; \
[0:a]volume=2[a0]; \
[bg]aloop=loop=-1:size=2e+09[a1]; \
[a1]volume=0.6[a1quiet]; \
[a0][a1quiet]amix=inputs=2:duration=first:dropout_transition=3[aout]" \
-map "[aout]" -shortest output.mp3

# === CONFIG ===
AUDIO="output.mp3"
TMP_DIR="temp_dir"
VIDEO_DIR="creepy_video"

mkdir -p "$TMP_DIR"
rm -f "$TMP_DIR"/video_list.txt "$TMP_DIR"/repeat_list.txt

# === STEP 1: Tạo file video_list.txt để ghép video ===
# for vid in "${VIDEO_LIST[@]}"; do
#   win_path=$(cygpath -w "$vid" | sed 's|\\|/|g')
#   echo "file '$win_path'" >> "$TMP_DIR/video_list.txt"
# done

# VIDEO_LIST=(
#   walk3.mp4 walk4.mp4 walk5.mp4 walk6.mp4 outhouse.mp4
#   lobby.mp4 stair.mp4 house.mp4 open_door.mp4 inhouse.mp4
#   victim.mp4 candle.mp4 walk1.mp4 house2.mp4
# )
VIDEO_LIST=( $(basename -a "$VIDEO_DIR"/*.mp4) )

# Lấy độ dài mảng
length=${#VIDEO_LIST[@]}

# Fisher–Yates Shuffle
for ((i=length-1; i>0; i--)); do
  # Lấy một chỉ số ngẫu nhiên từ 0 đến i
  j=$((RANDOM % (i + 1)))

  # Hoán đổi VIDEO_LIST[i] và VIDEO_LIST[j]
  temp=${VIDEO_LIST[i]}
  VIDEO_LIST[i]=${VIDEO_LIST[j]}
  VIDEO_LIST[j]=$temp
done


FILTER=""
index=0

for file in "${VIDEO_LIST[@]}"; do
  FILTER+="[$index:v:0]"
  ((index++))
done

CONCAT="concat=n=${#VIDEO_LIST[@]}:v=1:a=0[outv]"

# Ghép chuỗi lệnh input
INPUTS=""
for f in "${VIDEO_LIST[@]}"; do
  INPUTS+=" -i \"$VIDEO_DIR/$f\""
done

# Ghép video bằng ffmpeg
eval ffmpeg -y $INPUTS \
  -filter_complex "$FILTER$CONCAT" \
  -map "[outv]" \
  -crf 23 -preset ultrafast -r 30 -s 1920x1080 \
  -c:v libx264 -c:a aac -b:a 192k \
  -pix_fmt yuv420p \
  "$TMP_DIR/combined.mp4"
echo "✅ combined done"



# cd ..
# === STEP 2: Ghép video thành combined.mp4 ===
# ffmpeg -y -f concat -safe 0 -i "$TMP_DIR/video_list.txt" \
#   -vf "fps=30" \
#   -crf 23 -preset ultrafast -s 1920x1080 \
#   -c:v libx264 -threads 0 -c:a aac -b:a 192k \
#   -pix_fmt yuv420p \
#   "$TMP_DIR/combined.mp4"
# echo "✅ Done combined video"

# === STEP 3: Tính số lần lặp để đủ độ dài audio ===
audio_dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO")
video_dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TMP_DIR/combined.mp4")

loops=$(awk -v a="$audio_dur" -v b="$video_dur" 'BEGIN{print int(a/b)+1}')

# === STEP 4: Lặp lại video ===
for i in $(seq 1 $loops); do
  echo "file 'combined.mp4'" >> "$TMP_DIR/repeat_list.txt"
done

ffmpeg -y -f concat -safe 0 -i "$TMP_DIR/repeat_list.txt" -c copy "$TMP_DIR/looped_video.mp4"

# === STEP 5: Cắt video đúng độ dài và ghép audio ===
ffmpeg -y \
  -i "$TMP_DIR/looped_video.mp4" -i "$AUDIO" -i "$TMP_DIR/ronal.png" \
  -ignore_loop 0 -i podcast.gif \
  -filter_complex "\
    [2:v]scale=280:500[img]; \
    [0:v][img]overlay=W-w-20:H-h-20[tmp1]; \
    movie=man.png,scale=200:200,hflip[man]; \
    [tmp1][man]overlay=20:20[tmp2]; \
    [3:v]scale=250:120[gif]; \
    [tmp2][gif]overlay=20:300:shortest=1[tmp3]; \
    [tmp3]eq=brightness=-0.09[dark]; \
    [dark]subtitles=subtitles/audio.srt[outv]" \
  -map "[outv]" -map 1:a \
  -c:v libx264 -crf 23 -preset ultrafast \
  -r 30 -s 1920x1080 \
  -c:a aac -b:a 192k \
  -pix_fmt yuv420p \
  -shortest \
  output_creepy_final.mp4




# Cleanup tạm (tuỳ chọn)
rm -rf  "$TMP_DIR/repeat_list.txt" "$TMP_DIR/combined.mp4" "$TMP_DIR/looped_video.mp4" "$TMP_DIR/output.mp3" "$TMP_DIR/main_audio.mp3"


echo "✅ Done! Output: output_creepy_final.mp4"