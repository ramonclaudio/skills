# Changelog

## 1.4.0

- Add pre-loaded ffmpeg availability check via shell interpolation for fail-fast behavior
- Add `ultrathink` for better frame sampling decisions
- Add negative trigger to description ("Do NOT use for GIF conversion")
- Add `.mkv` and more trigger words ("look at", "review", "screen recording") to description
- Add FPS-by-duration table: <5s native, 5-30s 2fps, 30s-2min 1fps, >2min 0.5fps
- Add default 640px width scaling to save context tokens on retina recordings
- Increase frame sampling limits (up to 50-60 frames) for 600-image-per-request support
- Consolidate separate Long Videos, Resize, Time Range sections into main workflow
- Use `frame_%04d.png` naming (supports >999 frames)
- Add `version`, `repository`, `license`, `keywords` to `plugin.json`
- Remove Prerequisites section (replaced by pre-loaded environment check)

## 1.3.0

- Add `Bash(trash *)` to allowed-tools
- Add cleanup step: `trash /tmp/video-frames` before `mkdir -p` to prevent stale frames
- Add `$ARGUMENTS` reference for parsing video path
- Add parallel Read calls note for faster frame analysis
- Add `argument-hint` frontmatter for autocomplete display

## 1.2.0

- Upgrade to `opus` model for skill execution

## 1.1.0

- Use `sonnet[1m]` (1M context) for skill execution
- Scope `Bash(rm *)` to `Bash(rm -rf /tmp/video-frames)`, no more wildcard delete
- Scope `Bash(mkdir *)` to `Bash(mkdir -p /tmp/video-frames)`
- Remove `Bash(for *)` escape hatch, use `/bin/cp` with glob directly
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- Extract frames from video files as PNG images via ffmpeg
- Glob+copy pattern for macOS filenames with spaces
- Smart frame sampling based on video duration
- Support for .mov, .mp4, .webm, .avi formats
