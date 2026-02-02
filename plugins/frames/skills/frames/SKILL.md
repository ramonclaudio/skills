---
name: run
description: Extract frames from video files to view them as images. Use when the user asks to watch, view, or analyze a video file (.mov, .mp4, .webm, .avi, etc.) since Claude cannot directly view videos but can view images.
argument-hint: <video-path>
disable-model-invocation: true
allowed-tools:
  - Bash(ffmpeg *)
  - Bash(ffprobe *)
  - Bash(for *)
  - Bash(/bin/cp *)
  - Bash(/bin/ls *)
  - Bash(mkdir *)
  - Bash(rm *)
  - Bash(wc *)
  - Read
model: sonnet
---

# Video to Frames

Claude cannot directly view video files, but can view images. This skill extracts frames from videos using ffmpeg, allowing Claude to "watch" videos by viewing sampled frames.

## Prerequisites

Requires `ffmpeg` to be installed:
```bash
brew install ffmpeg  # macOS
apt install ffmpeg   # Linux
```

## Quick Workflow (2 Commands)

**IMPORTANT:** File paths with spaces, timestamps, and special characters are problematic. ALWAYS use this pattern:

### Step 1: Copy + Probe + Extract (single command)

Extract a unique identifier from the user's path (like a timestamp) and use glob:

```bash
for f in /path/to/dir/*UNIQUE_PART*; do /bin/cp -f "$f" /tmp/video.mov; done && \
rm -rf /tmp/video-frames && mkdir -p /tmp/video-frames; \
ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate,duration -of csv=p=0 /tmp/video.mov && \
ffmpeg -y -v warning -i /tmp/video.mov /tmp/video-frames/frame_%03d.png && \
/bin/ls /tmp/video-frames/ | wc -l
```

**Example for** `Screen Recording 2026-01-10 at 11.33.27 AM.mov`:
```bash
for f in ~/Desktop/Screen*11.33.27*; do /bin/cp -f "$f" /tmp/video.mov; done && \
rm -rf /tmp/video-frames && mkdir -p /tmp/video-frames; \
ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate,duration -of csv=p=0 /tmp/video.mov && \
ffmpeg -y -v warning -i /tmp/video.mov /tmp/video-frames/frame_%03d.png && \
/bin/ls /tmp/video-frames/ | wc -l
```

This returns: `frame_rate,duration` on one line, then frame count.

### Step 2: View frames

Sample frames evenly. Use Read tool on PNG files:

```bash
# List available frames
/bin/ls /tmp/video-frames/
```

Then read frames with the Read tool:
- Short videos (<30 frames): Read frames 1, middle, last
- Medium videos (30-100 frames): Read 5-6 evenly spaced frames
- Long videos (>100 frames): Read 10-15 evenly distributed frames

## Why This Pattern?

| Problem | Solution |
|---------|----------|
| Spaces in filenames | Glob pattern + for loop handles any filename |
| Quoted paths fail | `/bin/cp -f` with glob avoids quoting issues |
| `cd` fails (zoxide) | Never use `cd`, use absolute paths |
| `rm *.png` fails in zsh | `rm -rf dir && mkdir -p dir` avoids glob entirely |
| Overwrite prompts | `/bin/cp -f` forces overwrite |
| Shell aliases interfere | Use `/bin/cp`, `/bin/ls` for reliability |

## Long Videos

For videos longer than 10 seconds, extract at lower FPS:

```bash
# 2 FPS for long videos
ffmpeg -y -v warning -i /tmp/video.mov -vf "fps=2" /tmp/video-frames/frame_%03d.png

# 1 FPS for very long videos
ffmpeg -y -v warning -i /tmp/video.mov -vf "fps=1" /tmp/video-frames/frame_%03d.png

# Keyframes only (scene changes)
ffmpeg -y -v warning -i /tmp/video.mov -vf "select=eq(pict_type\,I)" -vsync vfr /tmp/video-frames/frame_%03d.png
```

## Specific Time Range

```bash
# Extract 10 seconds starting at 1 minute
ffmpeg -y -v warning -ss 00:01:00 -t 10 -i /tmp/video.mov /tmp/video-frames/frame_%03d.png
```

## Resize Frames

```bash
# Scale to 640px width (smaller files, faster reads)
ffmpeg -y -v warning -i /tmp/video.mov -vf "scale=640:-1" /tmp/video-frames/frame_%03d.png
```
