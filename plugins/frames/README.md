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
3. Selects FPS based on duration (<5s native, 5-30s 2fps, 30s-2min 1fps, >2min 0.5fps)
4. Extracts frames as PNGs scaled to 640px width (saves context tokens)
5. Reads a sample of frames evenly distributed across the video

Frame sampling scales with extracted frame count:

| Frame count | Frames read |
|:---|:---|
| <30 | All |
| 30-100 | 15-20 evenly spaced |
| 100-300 | 30-40 evenly spaced |
| >300 | 50-60 evenly distributed |

Claude supports up to 600 images per request with the 1M context window, so sampling can be generous.

<details>
<summary>Why the Copy Pattern?</summary>

macOS screen recordings have filenames like `Screen Recording 2026-01-10 at 11.33.27 AM.mov`. These break most quoting strategies. The plugin copies to a clean `/tmp/video.mov` path using glob matching to sidestep the problem entirely.

</details>

---

> [!IMPORTANT]
> Requires `ffmpeg` (`brew install ffmpeg` on macOS, `apt install ffmpeg` on Linux).
