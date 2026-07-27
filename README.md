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
| [`whisper-cli`](https://github.com/ggml-org/whisper.cpp) | e.g. `brew install whisper-cpp` |
| A GGML Whisper model (`.bin`) | **not** included here — download separately (below) |

**ffmpeg is not required** — audio is captured as 16 kHz mono WAV.

everywhisper does **not** download model weights for you. You install `whisper-cli`, fetch one GGML model file, then run `./install.sh`.

## Get `whisper-cli` and a model

### 1. Install the CLI

```bash
brew install whisper-cpp
```

That provides `whisper-cli`. Homebrew does **not** ship the speech models ([formula notes](https://github.com/Homebrew/homebrew-core/blob/master/Formula/w/whisper-cpp.rb)).

### 2. Download a GGML model

Official model files for whisper.cpp:

| Source | URL |
|--------|-----|
| Hugging Face (primary) | [huggingface.co/ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp/tree/main) |
| Mirror | [ggml.ggerganov.com](https://ggml.ggerganov.com/) |
| Upstream project | [github.com/ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp) |

**Recommended starter (English, ~142 MB):** `ggml-base.en.bin` — good balance of speed and quality on a MacBook Air.

```bash
mkdir -p ~/.cache/whisper
curl -fL -o ~/.cache/whisper/ggml-base.en.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
```

Other common English models on the same Hugging Face repo (pick one):

| File | Rough size | Notes |
|------|------------|--------|
| `ggml-tiny.en.bin` | ~75 MB | Fastest, lower accuracy |
| `ggml-base.en.bin` | ~142 MB | Good default |
| `ggml-small.en.bin` | ~466 MB | Better accuracy, slower |
| `ggml-medium.en.bin` | ~1.5 GB | High accuracy |
| `ggml-large-v3.bin` | ~3 GB | Best quality (multilingual; drop `.en` for other languages) |

Direct download pattern (replace the filename):

```bash
curl -fL -o ~/.cache/whisper/ggml-small.en.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin"
```

You only need **one** `.bin` file. Point `WHISPER_MODEL` at its full path (or place it where install can auto-discover it — see [Configuration](#configuration)).

## Install everywhisper

```bash
git clone https://github.com/cdiak/everywhisper.git
cd everywhisper

export WHISPER_MODEL="$HOME/.cache/whisper/ggml-base.en.bin"
# optional if whisper-cli is not on PATH:
# export WHISPER_CLI="$(brew --prefix)/bin/whisper-cli"

./install.sh
```

If `WHISPER_MODEL` is already in a [default search path](#configuration), you can omit the export.

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
export WHISPER_MODEL="$HOME/.cache/whisper/ggml-base.en.bin"
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
