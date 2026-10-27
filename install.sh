#!/usr/bin/env bash
# Install everywhisper → ~/.local/bin + login LaunchAgent
set -euo pipefail
cd "$(dirname "$0")"

BIN_DIR="${HOME}/.local/bin"
LAUNCH_AGENTS="${HOME}/Library/LaunchAgents"
LABEL="com.cdiak.everywhisper"
LEGACY_LABEL="com.local.whisper-dictation"
PLIST="${LAUNCH_AGENTS}/${LABEL}.plist"
DEST="${BIN_DIR}/everywhisper"

mkdir -p "$BIN_DIR" "$LAUNCH_AGENTS"

./build.sh "$DEST"

# Stop current + legacy agents
for lbl in "$LABEL" "$LEGACY_LABEL"; do
  launchctl bootout "gui/$(id -u)/${lbl}" 2>/dev/null || true
done
launchctl unload "$PLIST" 2>/dev/null || true
launchctl unload "${LAUNCH_AGENTS}/${LEGACY_LABEL}.plist" 2>/dev/null || true
rm -f "${LAUNCH_AGENTS}/${LEGACY_LABEL}.plist"
rm -f "${BIN_DIR}/whisper-dictation"

# Resolve defaults: env → PATH → common Homebrew location
if [[ -z "${WHISPER_CLI:-}" ]]; then
  if command -v whisper-cli >/dev/null 2>&1; then
    WHISPER_CLI="$(command -v whisper-cli)"
  else
    WHISPER_CLI="/opt/homebrew/bin/whisper-cli"
  fi
fi

# Resolve a whisper model: env → common locations
if [[ -z "${WHISPER_MODEL:-}" ]]; then
  for candidate in \
    "${HOME}/.cache/whisper/ggml-base.en.bin" \
    "${HOME}/models/whisper/ggml-base.en.bin" \
    "/opt/homebrew/share/whisper-cpp/ggml-base.en.bin" \
    "/usr/local/share/whisper-cpp/ggml-base.en.bin"
  do
    if [[ -f "$candidate" ]]; then
      WHISPER_MODEL="$candidate"
      break
    fi
  done
fi
WHISPER_MODEL="${WHISPER_MODEL:-}"
WHISPER_LANGUAGE="${WHISPER_LANGUAGE:-en}"

if [[ ! -f "$WHISPER_MODEL" ]]; then
  echo "warning: no whisper model found. Set WHISPER_MODEL to a ggml/gguf model path." >&2
  echo "  example: WHISPER_MODEL=\$HOME/.cache/whisper/ggml-base.en.bin ./install.sh" >&2
fi

# Escape XML special chars in paths for plist
xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

CLI_XML="$(xml_escape "$WHISPER_CLI")"
MODEL_XML="$(xml_escape "$WHISPER_MODEL")"
LANG_XML="$(xml_escape "$WHISPER_LANGUAGE")"
DEST_XML="$(xml_escape "$DEST")"
HOME_XML="$(xml_escape "$HOME")"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${DEST_XML}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>WHISPER_CLI</key>
    <string>${CLI_XML}</string>
    <key>WHISPER_MODEL</key>
    <string>${MODEL_XML}</string>
    <key>WHISPER_LANGUAGE</key>
    <string>${LANG_XML}</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${HOME_XML}/Library/Logs/everywhisper.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME_XML}/Library/Logs/everywhisper.log</string>
  <key>ProcessType</key>
  <string>Interactive</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null \
  || launchctl load "$PLIST"

echo
echo "Installed everywhisper"
echo "  binary:  $DEST"
echo "  agent:   $PLIST"
echo "  log:     $HOME/Library/Logs/everywhisper.log"
echo "  whisper: $WHISPER_CLI"
echo "  model:   ${WHISPER_MODEL:-(not set)}"
echo
echo "Hotkey: Option+Shift+W  (toggle record → stop → paste)"
echo
echo "Permissions (first run):"
echo "  System Settings → Privacy & Security → Microphone → everywhisper"
echo "  System Settings → Privacy & Security → Accessibility → everywhisper"
echo "  If missing from the list, run once: $DEST"
echo
echo "Menu bar: \"W\" idle · \"●\" recording · \"…\" transcribing"
echo "Uninstall: ./uninstall.sh"
