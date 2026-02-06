# Changelog

## 1.1.0

- Use `sonnet[1m]` (1M context) for skill execution
- Remove `Bash(rm *)` from allowed-tools
- Remove all `rm -rf` commands — `mkdir -p` + ffmpeg `-y` handles overwrites
- Add `--speed` and `--crop` options to README
- Add HDR detection/conversion to README "How It Works"
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- Two-pass ffmpeg palette encoding for high-quality GIFs
- HDR (smpte2084/PQ) detection and SDR conversion via avconvert
- Options: --speed, --width, --fps, --full, --crop
- Glob+copy pattern for macOS filenames with spaces
