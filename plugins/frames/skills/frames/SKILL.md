---
name: frames
description: Extract frames from a video file or screen recording (.mov, .mp4, .webm, .avi, .mkv) so Claude can view, review, or analyze it. Do NOT use for GIF conversion (use /gif instead).
argument-hint: "<video-file>"
allowed-tools:
  - Bash(ffmpeg *)
  - Bash(ffprobe *)
  - Bash(/bin/cp *)
  - Bash(/bin/ls *)
  - Bash(mkdir -p /tmp/video-frames)
  - Bash(trash *)
  - Bash(wc *)
  - Read
model: opus
---

# Video to Frames

ultrathink

Claude cannot view video files directly but can view images. Extract frames using ffmpeg, then read a sample. Claude supports up to 600 images per request with the 1M context window, so sampling can be generous.

## Environment

- ffmpeg: !`which ffmpeg 2>/dev/null && ffmpeg -version 2>&1 | head -1 || echo "NOT INSTALLED - run: brew install ffmpeg"`

If ffmpeg is NOT INSTALLED, stop immediately and tell the user to install it. Do not attempt any extraction.

## Workflow

Parse the video path from `$ARGUMENTS`.

### Step 1: Copy + Probe

File paths with spaces and special characters break quoting. Copy to a clean `/tmp` path using glob on a unique substring (timestamp, keyword).

```bash
/bin/cp -f /path/to/dir/*UNIQUE_PART* /tmp/video.mov && \
ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate,duration -of csv=p=0 /tmp/video.mov
```

**Example for** `Screen Recording 2026-01-10 at 11.33.27 AM.mov`:
```bash
/bin/cp -f ~/Desktop/Screen*11.33.27* /tmp/video.mov && \
ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate,duration -of csv=p=0 /tmp/video.mov
```

### Step 2: Extract frames

Select FPS based on duration from the probe output. Scale to 640px width to save context tokens.

| Duration | FPS | Rationale |
|----------|-----|-----------|
| <5s | native | Short clip, need full detail |
| 5-30s | 2 | 10-60 frames |
| 30s-2min | 1 | 30-120 frames |
| >2min | 0.5 | Keep frame count manageable |

```bash
trash /tmp/video-frames 2>/dev/null; mkdir -p /tmp/video-frames && \
ffmpeg -y -v warning -i /tmp/video.mov -vf "fps=FPS,scale=640:-1" /tmp/video-frames/frame_%04d.png && \
/bin/ls /tmp/video-frames/ | wc -l
```

For short videos (<5s), omit the `fps=` filter but keep the scale:
```bash
ffmpeg -y -v warning -i /tmp/video.mov -vf "scale=640:-1" /tmp/video-frames/frame_%04d.png
```

To extract a specific time range, add `-ss START -t DURATION` before `-i`:
```bash
ffmpeg -y -v warning -ss 00:01:00 -t 10 -i /tmp/video.mov -vf "fps=2,scale=640:-1" /tmp/video-frames/frame_%04d.png
```

### Step 3: Read frames

List frames, then read a sample evenly distributed across the video. Use parallel Read calls for speed.

```bash
/bin/ls /tmp/video-frames/
```

| Frame count | Frames to read |
|-------------|----------------|
| <30 | All |
| 30-100 | 15-20 evenly spaced |
| 100-300 | 30-40 evenly spaced |
| >300 | 50-60 evenly distributed |

Pick frame numbers evenly spaced across the total. Read them with the Read tool, multiple per response.

## Why the Copy Pattern?

| Problem | Solution |
|---------|----------|
| Spaces in filenames | `/bin/cp -f` with glob handles any filename |
| Quoted paths fail | Glob avoids quoting issues |
| `cd` fails (zoxide) | Never use `cd`, use absolute paths |
| Shell aliases interfere | Use `/bin/cp`, `/bin/ls` for reliability |
