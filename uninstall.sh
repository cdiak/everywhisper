#!/usr/bin/env bash
set -euo pipefail
LABEL="com.cdiak.everywhisper"
# Legacy label from earlier local name
LEGACY_LABEL="com.local.whisper-dictation"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LEGACY_PLIST="${HOME}/Library/LaunchAgents/${LEGACY_LABEL}.plist"
DEST="${HOME}/.local/bin/everywhisper"
LEGACY_DEST="${HOME}/.local/bin/whisper-dictation"

for lbl in "$LABEL" "$LEGACY_LABEL"; do
  launchctl bootout "gui/$(id -u)/${lbl}" 2>/dev/null || true
done
for p in "$PLIST" "$LEGACY_PLIST"; do
  launchctl unload "$p" 2>/dev/null || true
  rm -f "$p"
done
rm -f "$DEST" "$LEGACY_DEST"
echo "Removed everywhisper (and any legacy whisper-dictation agent/binary)."
