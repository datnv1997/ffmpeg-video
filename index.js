const fs = require("fs");
const path = require("path");
const ffmpeg = require("fluent-ffmpeg");

// ==== Cấu hình ====
const imagesDir = path.join(__dirname, "images"); // thư mục chứa ảnh
const outputVideo = path.join(__dirname, "output.mp4"); // video chính
const finalOutput = path.join(__dirname, "final_output.mp4"); // video sau khi ghép intro
const audioFile = path.join(__dirname, "audio.wav");
const introVideo = path.join(__dirname, "fixed_intro.mp4");
const stickerGif = path.join(__dirname, "podcast.gif");

function getAudioDuration(filePath) {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(filePath, (err, metadata) => {
      if (err) return reject(err);
      const duration = metadata.format.duration;
      resolve(duration);
    });
  });
}

async function generateVideo() {
  try {
    const secondsPerImage = 6;
    const durationSeconds = await getAudioDuration(audioFile);
    console.log("⏱ Thời lượng audio:", durationSeconds, "giây");

    // ==== Đọc danh sách ảnh ====
    let imageFiles = fs
      .readdirSync(imagesDir)
      .filter((file) => /\.(jpg|jpeg|png|webp)$/i.test(file))
      .sort(); // đảm bảo đúng thứ tự

    if (imageFiles.length === 0) {
      console.error("Không tìm thấy ảnh trong thư mục.");
      process.exit(1);
    }

    // ==== Tính số lần cần lặp ====
    const loopCount = Math.ceil(durationSeconds / (imageFiles.length * secondsPerImage));

    // ==== Tạo danh sách ảnh lặp ====
    const repeatedImages = Array.from({ length: loopCount }, () => imageFiles).flat();
    const limitedImages = repeatedImages.slice(0, Math.ceil(durationSeconds / secondsPerImage));

    // ==== Tạo danh sách ảnh tạm thời ====
    const inputListPath = path.join(__dirname, "input.txt");
    const inputListContent = limitedImages
      .map((filename) => {
        const fullPath = path.join(imagesDir, filename);
        return `file '${fullPath.replace(/\\/g, "/")}\nduration ${secondsPerImage}`;
      })
      .join("\n");

    // FFmpeg yêu cầu lặp ảnh cuối 1 lần nữa không có `duration`
    const lastImage = path.join(imagesDir, limitedImages[limitedImages.length - 1]).replace(/\\/g, "/");
    const finalInputList = inputListContent + `\nfile '${lastImage}'\n`;

    fs.writeFileSync(inputListPath, finalInputList);
    // ghep intro
    const concatVideoIntro = () => {
      const concatListPath = path.join(__dirname, "videos.txt");
      const concatListContent = `file '${introVideo.replace(/\\/g, "/")}'\nfile '${outputVideo.replace(/\\/g, "/")}'`;

      fs.writeFileSync(concatListPath, concatListContent);

      ffmpeg()
        .input(concatListPath)
        .inputOptions(["-f concat", "-safe 0"])
        // .outputOptions([
        //   "-c:v libx264",
        //   "-c:a aac", // ensure audio codec is specified
        //   "-pix_fmt yuv420p",
        //   "-r 60",
        //   "-s 1920x1080", // set video resolution to 1920x1080
        //   "-b:v 4000k", // set video bitrate to 5000k
        //   "-b:a 192k",
        //   "-ar 48000",
        // ])
        .on("start", (cmd) => console.log("🎬 Đang ghép intro:\n" + cmd))
        .on("error", (err) => console.error("❌ Lỗi khi ghép intro: " + err))
        .on("end", () => {
          console.log("🎉 Video cuối cùng đã tạo: final_output.mp4");
          fs.unlinkSync(concatListPath);
        })
        .save(finalOutput);
    };
    const addSubtitles = () => {
      ffmpeg()
        .input("output.mp4")
        .videoFilter("subtitles=subtitles/audio.srt")

        .on("end", () => {
          console.log("🎉 Subtitles added successfully!");
        })
        .on("error", (err) => {
          console.error("❌ Error:", err.message);
        })
        .save(finalOutput);
    };
    // ==== Tạo video bằng FFmpeg ====
    ffmpeg()
      .input(inputListPath)

      .inputOptions(["-f concat", "-safe 0"])
      .input(audioFile)
      .inputFormat("wav")
      .complexFilter([
        "volume=1.5", // tăng âm lượng gấp 1.5 lần (~+4dB)
      ])
      // .input(stickerGif) // thêm GIF làm lớp phủ
      // .complexFilter([
      //   "[0:v][2:v] overlay=W-w-20:H-h-20:shortest=1", // sticker ở góc phải dưới
      //   "volume=6dB"
      // ])
      .outputOptions([
        "-c:v libx264",
        "-c:a aac", // ensure audio codec is specified
        "-pix_fmt yuv420p",
        "-r 60",
        "-s 1920x1080", // set video resolution to 1920x1080
        "-b:v 4000k", // set video bitrate to 5000k
        "-b:a 192k",
        "-ar 48000",
      ])
      // .videoFilter("subtitles=subtitles/audio.srt:force_style='FontName=Arial,FontSize=18,PrimaryColour=&H00FFFFFF,Outline=2,OutlineColour=&H00000000,Shadow=1'")
      .on("start", (cmd) => console.log("Chạy FFmpeg:\n" + cmd))
      .on("error", (err) => console.error("Lỗi: " + err.message))
      .on("end", () => {
        console.log("✅ Video đã tạo xong kèm âm thanh!");
        fs.unlinkSync(inputListPath);
        // concatVideoIntro();
        // addSubtitles();
      })
      .save(outputVideo);
  } catch (error) {
    console.error(error);
  }
}
generateVideo();
