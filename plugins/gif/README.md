# GIF Plugin

I share screen recordings in PRs and docs constantly. Converting .mov to .gif by hand is annoying, and the ffmpeg incantation for two-pass palette encoding is impossible to remember. This does it in one command.

## Usage

```bash
/gif ~/Desktop/recording.mov
/gif ~/Desktop/recording.mov --width 480
/gif ~/Desktop/recording.mov --fps 5
/gif ~/Desktop/recording.mov --full
```

<details>
<summary>Fully-qualified syntax</summary>

If another plugin has a conflicting skill name, use the full `plugin:skill` form:

```bash
/gif:gif <video-path> [--width N] [--fps N] [--speed N] [--crop] [--full]
```

</details>

## How It Works

1. Copies the video to `/tmp/video.mov` using glob patterns (handles spaces and special characters in filenames)
2. Probes video metadata (frame rate, duration, dimensions, color transfer)
3. Detects HDR (smpte2084/PQ) recordings and converts to SDR via macOS-native `avconvert` before processing
4. Generates an optimized palette from the video
5. Converts to GIF using the palette for maximum compression
6. Reports output path and file size

## Defaults

| Setting | Default | Why |
|:---|:---|:---|
| FPS | 10 | Good for screen recordings, keeps size down |
| Width | 640px | Shareable size, lanczos scaling |
| Palette | `stats_mode=diff` | Optimizes for screen recordings with static areas |
| Dither | `bayer:bayer_scale=5` | Good quality, small file |

## Options

| Flag | Effect |
|:---|:---|
| `--width N` | Change output width (default: 640) |
| `--fps N` | Change frame rate (default: 10) |
| `--speed N` | Playback speed multiplier (default: 1) |
| `--full` | No scaling, keep original resolution |
| `--crop` | Crop to content area (removes macOS recording overlay) |

<details>
<summary>Why the Copy Pattern?</summary>

macOS screen recordings have filenames like `Screen Recording 2026-01-10 at 11.33.27 AM.mov`. These break most quoting strategies. The plugin copies to a clean `/tmp/video.mov` path using glob matching to sidestep the problem entirely.

</details>

---

> [!IMPORTANT]
> Requires `ffmpeg` (`brew install ffmpeg` on macOS, `apt install ffmpeg` on Linux).
