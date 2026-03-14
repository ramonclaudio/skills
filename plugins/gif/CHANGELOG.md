# Changelog

## 1.3.0

- Remove `Bash(for *)` from allowed-tools
- Scope `Bash(mkdir *)` to `Bash(mkdir -p /tmp/gif-output)`
- Replace `for f in ...; do /bin/cp; done` with direct `/bin/cp -f` glob pattern
- Add `$ARGUMENTS` reference for parsing video path
- Add `argument-hint` frontmatter for autocomplete display

## 1.2.0

- Upgrade to `opus` model for skill execution

## 1.1.0

- Use `sonnet[1m]` (1M context) for skill execution
- Remove `Bash(rm *)` from allowed-tools
- Remove all `rm -rf` commands. `mkdir -p` + ffmpeg `-y` handles overwrites
- Add `--speed` and `--crop` options to README
- Add HDR detection/conversion to README "How It Works"
- Enable model invocation for full agent autonomy

## 1.0.0

- Initial release
- Two-pass ffmpeg palette encoding for high-quality GIFs
- HDR (smpte2084/PQ) detection and SDR conversion via avconvert
- Options: --speed, --width, --fps, --full, --crop
- Glob+copy pattern for macOS filenames with spaces
