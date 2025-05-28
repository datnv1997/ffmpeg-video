from faster_whisper import WhisperModel
import os

# ====== Cấu hình ======
audio_file = "audio.wav"
output_dir = "subtitles"
output_file = os.path.join(output_dir, "audio.srt")
model_size = "small"        # tiny, base, small, medium, large-v2
language = "en"             # hoặc None để auto detect
compute_type = "int8"       # int8, float16, float32

# ====== Khởi tạo model ======
model = WhisperModel(
    model_size,
    device="cpu",
    compute_type=compute_type,
)

# ====== Tạo thư mục output nếu chưa có ======
os.makedirs(output_dir, exist_ok=True)

# ====== Transcribe ======
segments, info = model.transcribe(audio_file, language=language, word_timestamps=True)

# Chuyển segments thành list để dùng nhiều lần
segments = list(segments)

print(f"Detected language: {info.language}")
print(f"Number of segments: {len(segments)}")

# ====== Hàm format timestamp ======
def format_timestamp(seconds):
    hrs = int(seconds // 3600)
    mins = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds - int(seconds)) * 1000)
    return f"{hrs:02}:{mins:02}:{secs:02},{millis:03}"

# ====== Viết file SRT ======
with open(output_file, "w", encoding="utf-8") as f:
    for i, segment in enumerate(segments, start=1):
        start = format_timestamp(segment.start)
        end = format_timestamp(segment.end)
        text = segment.text.strip()

        f.write(f"{i}\n")
        f.write(f"{start} --> {end}\n")
        f.write(f"{text}\n\n")

print(f"✅ Đã tạo file SRT tại: {output_file}")
