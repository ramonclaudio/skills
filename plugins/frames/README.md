# Frames Plugin

Claude can't watch videos. But it can look at images. This extracts frames from screen recordings so Claude can see what happened. Useful for bug reproductions and demos.

## Usage

```bash
/frames ~/Desktop/recording.mov
/frames ~/Videos/demo.mp4
```

<details>
<summary>Fully-qualified syntax</summary>

If another plugin has a conflicting skill name, use the full `plugin:skill` form:

```bash
/frames:frames <video-path>
```

</details>

## How It Works

1. Copies the video to `/tmp/video.mov` using glob patterns (handles spaces and special characters in filenames)
2. Probes video metadata (frame rate, duration)
3. Extracts all frames as PNGs to `/tmp/video-frames/`
4. Reads a sample of frames evenly distributed across the video

Frame sampling scales with video length:

| Video length | Frames read |
|:---|:---|
| Short (<30 frames) | 3 (first, middle, last) |
| Medium (30-100) | 5-6 evenly spaced |
| Long (>100) | 10-15 evenly distributed |

For long videos (>10s), automatically reduces extraction FPS.

<details>
<summary>Why the Copy Pattern?</summary>

macOS screen recordings have filenames like `Screen Recording 2026-01-10 at 11.33.27 AM.mov`. These break most quoting strategies. The plugin copies to a clean `/tmp/video.mov` path using glob matching to sidestep the problem entirely.

</details>

---

> [!IMPORTANT]
> Requires `ffmpeg` (`brew install ffmpeg` on macOS, `apt install ffmpeg` on Linux).
