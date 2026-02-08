# Changelog

## 1.2.0

- Upgrade to `opus` model for skill execution

## 1.1.0

- Use `sonnet[1m]` (1M context) for skill execution
- Scope `Bash(rm *)` to `Bash(rm -rf /tmp/video-frames)` — no more wildcard delete
- Scope `Bash(mkdir *)` to `Bash(mkdir -p /tmp/video-frames)`
- Remove `Bash(for *)` escape hatch — use `/bin/cp` with glob directly
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- Extract frames from video files as PNG images via ffmpeg
- Glob+copy pattern for macOS filenames with spaces
- Smart frame sampling based on video duration
- Support for .mov, .mp4, .webm, .avi formats
