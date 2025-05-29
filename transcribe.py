import sys
from faster_whisper import WhisperModel
import os

audio_file = sys.argv[1]
output_file = sys.argv[2]

model = WhisperModel("small", device="cpu", compute_type="int8")
segments, info = model.transcribe(audio_file, language="en", word_timestamps=True)
segments = list(segments)

os.makedirs(os.path.dirname(output_file), exist_ok=True)

def format_timestamp(seconds):
    hrs = int(seconds // 3600)
    mins = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds - int(seconds)) * 1000)
    return f"{hrs:02}:{mins:02}:{secs:02},{millis:03}"

with open(output_file, "w", encoding="utf-8") as f:
    for i, segment in enumerate(segments, 1):
        f.write(f"{i}\n")
        f.write(f"{format_timestamp(segment.start)} --> {format_timestamp(segment.end)}\n")
        f.write(f"{segment.text.strip()}\n\n")

print(f"Transcription saved to {output_file}")