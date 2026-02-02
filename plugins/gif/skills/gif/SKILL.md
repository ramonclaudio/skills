---
name: gif
description: Convert screen recordings to compressed GIFs using ffmpeg two-pass palette. Handles macOS filenames with spaces and HDR recordings.
argument-hint: <video-path> [--speed N] [--width N] [--fps N] [--crop]
disable-model-invocation: true
allowed-tools:
  - Bash(ffmpeg *)
  - Bash(ffprobe *)
  - Bash(avconvert *)
  - Bash(for *)
  - Bash(/bin/cp *)
  - Bash(/bin/ls *)
  - Bash(mkdir *)
  - Bash(rm *)
  - Bash(wc *)
  - Bash(du *)
  - Bash(open *)
  - Read
model: sonnet
---

# Video to GIF

Convert screen recordings to compressed GIFs using ffmpeg's two-pass palette method. Handles HDR (HDR10/PQ) recordings from macOS automatically.

## Prerequisites

Requires `ffmpeg` to be installed:
```bash
brew install ffmpeg  # macOS
apt install ffmpeg   # Linux
```

## Defaults

| Setting | Value | Notes |
|---------|-------|-------|
| FPS | 10 | Good for screen recordings |
| Width | 640px | Lanczos scaling |
| Speed | 1x | No speedup |
| Palette | `stats_mode=diff` | Optimizes for static areas |
| Dither | `bayer:bayer_scale=5` | Good quality, small file |

Parse arguments from the user's invocation:
- `--speed N` → playback speed multiplier (default: 1). Use 2-4x for long demos.
- `--width N` → override scale width (default: 640)
- `--fps N` → override frame rate (default: 10)
- `--full` → no scaling, keep original resolution
- `--crop` → crop out macOS screen recording overlay (top bar). Probe dimensions first, then apply `crop=in_w:in_h-PIXELS:0:PIXELS` to remove the top PIXELS.

## Quick Workflow

**IMPORTANT:** File paths with spaces, timestamps, and special characters are problematic. ALWAYS use the glob+copy pattern.

### Step 1: Copy + Probe

Extract a unique identifier from the user's path (like a timestamp) and use glob:

```bash
for f in /path/to/dir/*UNIQUE_PART*; do /bin/cp -f "$f" /tmp/video.mov; done && \
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,duration \
  -show_entries stream=color_transfer \
  -of default=noprint_wrappers=1 /tmp/video.mov
```

**Example for** `Screen Recording 2026-01-29 at 12.33.07 PM.mov`:
```bash
for f in ~/Desktop/Screen*12.33.07*; do /bin/cp -f "$f" /tmp/video.mov; done && \
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,duration \
  -show_entries stream=color_transfer \
  -of default=noprint_wrappers=1 /tmp/video.mov
```

Check the `color_transfer` value:
- `smpte2084` → **HDR recording**, must convert to SDR first (Step 1b)
- Anything else (`bt709`, `unknown`, etc.) → SDR, skip to Step 2

### Step 1b: HDR → SDR conversion (only if color_transfer=smpte2084)

macOS screen recordings on XDR displays use HDR10 (PQ/BT.2020/10-bit). The base Homebrew ffmpeg cannot tone-map PQ without the `zimg` library. Use macOS-native `avconvert` instead. It uses AVFoundation which handles HDR to SDR tone mapping correctly.

```bash
avconvert -s /tmp/video.mov -o /tmp/video_sdr.mov -p PresetHighestQuality --replace --progress
```

Then use `/tmp/video_sdr.mov` as input for Step 2 instead of `/tmp/video.mov`.

**Verify conversion:**
```bash
ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of csv=p=0 /tmp/video_sdr.mov
```
Should output `bt709` (not `smpte2084`).

### Step 2: Convert to GIF (two-pass palette method)

Use `/tmp/video_sdr.mov` if HDR was detected, otherwise `/tmp/video.mov`. Substitute the input path as `INPUT` below.

Build the filter chain from arguments. Omit `setpts` when speed is 1. Omit `crop` when not requested.

Filter chain order: `setpts → crop → fps → scale → palettegen/paletteuse`

**With defaults (fps=10, width=640, speed=1):**
```bash
rm -rf /tmp/gif-output && mkdir -p /tmp/gif-output; \
ffmpeg -y -v warning -i INPUT \
  -vf "fps=10,scale=640:-1:flags=lanczos,palettegen=stats_mode=diff" \
  -update 1 /tmp/gif-output/palette.png && \
ffmpeg -y -v warning -i INPUT -i /tmp/gif-output/palette.png \
  -lavfi "fps=10,scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5" \
  -loop 0 /tmp/gif-output/output.gif && \
du -h /tmp/gif-output/output.gif
```

**With `--speed 3` (3x speedup):**
```bash
rm -rf /tmp/gif-output && mkdir -p /tmp/gif-output; \
ffmpeg -y -v warning -i INPUT \
  -vf "setpts=PTS/3,fps=10,scale=640:-1:flags=lanczos,palettegen=stats_mode=diff" \
  -update 1 /tmp/gif-output/palette.png && \
ffmpeg -y -v warning -i INPUT -i /tmp/gif-output/palette.png \
  -lavfi "setpts=PTS/3,fps=10,scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5" \
  -loop 0 /tmp/gif-output/output.gif && \
du -h /tmp/gif-output/output.gif
```

**With `--full` (no scaling):**
```bash
rm -rf /tmp/gif-output && mkdir -p /tmp/gif-output; \
ffmpeg -y -v warning -i INPUT \
  -vf "fps=10,palettegen=stats_mode=diff" \
  -update 1 /tmp/gif-output/palette.png && \
ffmpeg -y -v warning -i INPUT -i /tmp/gif-output/palette.png \
  -lavfi "fps=10[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5" \
  -loop 0 /tmp/gif-output/output.gif && \
du -h /tmp/gif-output/output.gif
```

**With `--crop` (remove macOS recording overlay):**
Insert `crop` before fps. The macOS recording bar is typically ~60px on retina displays:
```bash
# crop=in_w:in_h-PIXELS:0:PIXELS removes top PIXELS from source
"setpts=PTS/3,crop=in_w:in_h-60:0:60,fps=10,scale=640:-1:flags=lanczos,palettegen=stats_mode=diff"
```

### Step 3: Report

Report the output path and file size. Then open:
```bash
open /tmp/gif-output/output.gif  # macOS
```

## Size Reduction Tips

For large or long videos:

| Technique | Command modification |
|-----------|---------------------|
| Speed up | `setpts=PTS/3` for 3x (fewer frames = smaller file) |
| Lower FPS | `fps=5` (for long videos) |
| Smaller width | `scale=480:-1` or `scale=320:-1` |
| Trim to range | Add `-ss 00:00:05 -t 10` before `-i` to grab 10s starting at 5s |
| Crop region | Add `crop=w:h:x:y` to the filter chain |
| Remove overlay | `crop=in_w:in_h-60:0:60` removes top 60px (macOS recording bar) |
