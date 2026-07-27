# everywhisper

**Local speech-to-text, everywhere on your Mac.**

Hold focus in any text field — browser URL bar, Word, Google Docs, Slack, Terminal — press **⌥⇧W**, speak, press **⌥⇧W** again. Your words are transcribed **on-device** with [whisper.cpp](https://github.com/ggerganov/whisper.cpp) and pasted into the app.

No cloud API. No Raycast / Hammerspoon / Keyboard Maestro. One small native helper plus the Whisper model you already have.

```
⌥⇧W  →  ● record  →  ⌥⇧W  →  … transcribe  →  paste
```

## Requirements

| Need | Notes |
|------|--------|
| macOS | Apple Silicon or Intel; tested on recent macOS |
| [Xcode Command Line Tools](https://developer.apple.com/xcode/) | for `swiftc` (build once) |
| [`whisper-cli`](https://github.com/ggerganov/whisper.cpp) | e.g. `brew install whisper-cpp` |
| A Whisper model file | e.g. `ggml-base.en.bin` from whisper.cpp releases |

**ffmpeg is not required** — audio is captured as 16 kHz mono WAV.

## Install

```bash
git clone https://github.com/cdiak/everywhisper.git
cd everywhisper

# Point at your model if it is not in a default search path:
export WHISPER_MODEL="$HOME/path/to/ggml-base.en.bin"

./install.sh
```

This builds `~/.local/bin/everywhisper` and registers a login LaunchAgent.

### Permissions (first run)

macOS will prompt, or set them manually:

1. **System Settings → Privacy & Security → Microphone** → enable **everywhisper**
2. **System Settings → Privacy & Security → Accessibility** → enable **everywhisper**  
   (needed to send ⌘V into other apps)

If the app does not appear in those lists:

```bash
~/.local/bin/everywhisper
```

Then:

```bash
launchctl kickstart -k "gui/$(id -u)/com.cdiak.everywhisper"
```

## Use

1. Click into any text field.
2. **⌥⇧W** — menu bar shows `●` (recording).
3. Speak.
4. **⌥⇧W** again — menu bar shows `…`, then text is pasted.

Menu bar: **`W`** idle · **`●`** recording · **`…`** transcribing. Quit from the menu bar item.

Log file: `~/Library/Logs/everywhisper.log`

## Configuration

| Variable | Default / discovery |
|----------|---------------------|
| `WHISPER_CLI` | `whisper-cli` on `PATH`, else `/opt/homebrew/bin/whisper-cli` |
| `WHISPER_MODEL` | First existing file among common paths (see below), or set explicitly |
| `WHISPER_LANGUAGE` | `en` |
| `WHISPER_THREADS` | half of CPU cores |

Model search order when `WHISPER_MODEL` is unset:

- `~/Development/Models/whisper/ggml-base.en.bin`
- `~/models/whisper/ggml-base.en.bin`
- `~/.cache/whisper/ggml-base.en.bin`
- `/opt/homebrew/share/whisper-cpp/ggml-base.en.bin`

Example:

```bash
WHISPER_MODEL="$HOME/models/ggml-small.en.bin" \
WHISPER_LANGUAGE=en \
./install.sh
```

## Manual run (no login item)

```bash
./build.sh
export WHISPER_MODEL=/path/to/ggml-base.en.bin
./everywhisper
```

## Uninstall

```bash
./uninstall.sh
```

## Security & privacy

- **Speech never leaves your machine** for transcription (local `whisper-cli` only).
- The helper requests **Microphone** (record) and **Accessibility** (paste via ⌘V). Those permissions are powerful by design — same class as other dictation tools. Build from source and read `EveryWhisper.swift` if you want to verify behavior.
- Temporary WAVs live under your system temp directory and are deleted after each transcription.
- The log file may contain recent transcript text; it is only on your disk.
- This repo contains **no API keys**, **no network STT**, and **no model weights**.

## Project layout

```
everywhisper/
├── EveryWhisper.swift   # single-file AppKit + AVFoundation app
├── build.sh
├── install.sh           # → ~/.local/bin + LaunchAgent
├── uninstall.sh
├── LICENSE              # MIT
└── README.md
```

## License

[MIT](LICENSE)
