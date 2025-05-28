#!/bin/bash

# whisper audio.wav \
#   --language en \
#   --model turbo \
#   --output_format srt \
#   --output_dir ./subtitles/ \
#   --word_timestamps True \
#   --max_line_width 30 \
#   --max_line_count 2 \

python transcribe.py

node index.js

ffmpeg -y \
-i intro.mp4 \
-i output.mp4 \
-i subtitles/audio.srt \
-ignore_loop 0 -i podcast.gif \
-filter_complex "
[1:v]subtitles=subtitles/audio.srt[vidsub]; \
[vidsub][3:v]overlay=W-w-20:20:shortest=1[filtered]; \
[0:v:0][0:a:0][filtered][1:a:0]concat=n=2:v=1:a=1[outv][outa]
" \
-map "[outv]" -map "[outa]" \
-crf 23 -preset ultrafast -r 30 -s 1920x1080 \
-c:v libx264 -threads 0 -c:a aac -b:a 192k \
-pix_fmt yuv420p \
final_video.mp4

# ffmpeg -y -i output.mp4 -vf subtitles=subtitles/audio.srt output_subtitle.mp4

# ffmpeg -y -i output_subtitle.mp4 -ignore_loop 0 -i podcast.gif \
# -filter_complex "[0:v][1:v]overlay=W-w-20:20:shortest=1" \
# -pix_fmt yuv420p -c:a copy output_filter.mp4

# ffmpeg -y -i intro.mp4 -i output_filter.mp4 \
# -filter_complex "[0:v:0][0:a:0][1:v:0][1:a:0]concat=n=2:v=1:a=1[outv][outa]" \
# -map "[outv]" -map "[outa]" \
# -r 30 -s 1920x1080 -b:v 4000k -c:v libx264 -c:a aac -b:a 192k \
# final_video.mp4

