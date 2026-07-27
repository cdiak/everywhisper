# everywhisper

**Local speech-to-text, everywhere on your Mac.**

Hold focus in any text field — browser URL bar, Word, Google Docs, Slack, Terminal — press **⌥⇧W**, speak, press **⌥⇧W** again. Your words are transcribed **on-device** with [whisper.cpp](https://github.com/ggml-org/whisper.cpp) and pasted into the app.

No cloud API. No Raycast / Hammerspoon / Keyboard Maestro. One small native helper plus a local Whisper model.

```
⌥⇧W  →  ● record  →  ⌥⇧W  →  … transcribe  →  paste
```

## Install from a prompt

Copy everything inside the block below and paste it into a coding agent (Grok Build, Claude Code, Cursor, Codex, …). It should install dependencies, fetch a model, build everywhisper, and start the login agent — no manual GitHub steps.

```text
Set up everywhisper: system-wide local Whisper dictation on this Mac. Do every step yourself in the shell; do not tell me what to run. Stay on macOS only.

Repo: https://github.com/cdiak/everywhisper
Install dir: ~/Development/Projects/everywhisper (create parent dirs if needed)
Model path: ~/.cache/whisper/ggml-base.en.bin
Binary: ~/.local/bin/everywhisper
LaunchAgent label: com.cdiak.everywhisper

Steps:
1. Prerequisites
   - Confirm macOS (uname -s is Darwin). If not, stop and say everywhisper is macOS-only.
   - Ensure Xcode Command Line Tools (swiftc) are available. If missing, run xcode-select --install and wait / guide only if the GUI installer blocks non-interactive completion.
   - Ensure Homebrew is available (brew). If missing, install from https://brew.sh or report that brew is required.
2. Clone
   - If ~/Development/Projects/everywhisper is already a git clone of this repo, git pull --ff-only origin main (or the default branch).
   - If that path exists but is not this repo, move it to ~/Development/Projects/everywhisper.bak.<timestamp>.
   - Otherwise: git clone https://github.com/cdiak/everywhisper.git ~/Development/Projects/everywhisper
3. whisper-cli
   - If whisper-cli is not on PATH, brew install whisper-cpp.
   - Resolve WHISPER_CLI to the full path of whisper-cli (command -v whisper-cli or $(brew --prefix)/bin/whisper-cli).
4. Model (do not skip; everywhisper does not ship weights)
   - mkdir -p ~/.cache/whisper
   - If ~/.cache/whisper/ggml-base.en.bin is missing or smaller than ~100MB, download with:
       curl -fL --retry 3 -o ~/.cache/whisper/ggml-base.en.bin \
         "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
   - Verify the file exists and is a normal size (~142MB for base.en).
5. Install the helper
   - cd ~/Development/Projects/everywhisper
   - export WHISPER_CLI and WHISPER_MODEL (model = ~/.cache/whisper/ggml-base.en.bin)
   - ./install.sh
6. Verify process
   - Confirm ~/.local/bin/everywhisper exists and is executable.
   - Confirm LaunchAgent is loaded: launchctl print "gui/$(id -u)/com.cdiak.everywhisper" (or equivalent) shows running / path.
   - tail ~/Library/Logs/everywhisper.log and confirm a "everywhisper ready" line (or note Accessibility/mic prompts).
7. Permissions (cannot fully automate TCC — be explicit)
   - Tell me I must enable Microphone and Accessibility for everywhisper in:
       System Settings → Privacy & Security → Microphone
       System Settings → Privacy & Security → Accessibility
   - If the app is missing from those lists, run ~/.local/bin/everywhisper once from the terminal to trigger registration, then:
       launchctl kickstart -k "gui/$(id -u)/com.cdiak.everywhisper"
8. Report when done
   - clone path, whisper-cli path, model path + size, binary path, whether the agent is running, log snippet, and the hotkey (Option+Shift+W).
   - Remind me: click a text field, ⌥⇧W to record, ⌥⇧W again to stop and paste.

If any step fails, diagnose and fix before reporting done. Prefer fixing brew/path/model/download issues over asking me to run commands.
```

After the agent finishes, grant **Microphone** and **Accessibility** if prompted, then try **⌥⇧W** in any text field.

### What the prompt does

| Step | Result |
|------|--------|
| Clone / pull | `~/Development/Projects/everywhisper` at latest `main` |
| `brew install whisper-cpp` | `whisper-cli` on PATH |
| `curl` model | `~/.cache/whisper/ggml-base.en.bin` (~142 MB, English) |
| `./install.sh` | builds `~/.local/bin/everywhisper`, registers login LaunchAgent |
| Permissions note | you still flip Mic + Accessibility in System Settings (macOS requirement) |

---

## Requirements

| Need | Notes |
|------|--------|
| macOS | Apple Silicon or Intel; tested on recent macOS |
| [Xcode Command Line Tools](https://developer.apple.com/xcode/) | for `swiftc` (build once) |
| [`whisper-cli`](https://github.com/ggml-org/whisper.cpp) | e.g. `brew install whisper-cpp` |
| A GGML Whisper model (`.bin`) | **not** included here — download separately (below) |

**ffmpeg is not required** — audio is captured as 16 kHz mono WAV.

everywhisper does **not** download model weights unless *you* (or an agent following the prompt above) fetch them. You install `whisper-cli`, obtain one GGML model file, then run `./install.sh`.

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

## Manual install

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
WHISPER_MODEL="$HOME/.cache/whisper/ggml-small.en.bin" \
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
