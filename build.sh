#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-everywhisper}"
echo "Compiling $OUT …"
swiftc -O \
  -o "$OUT" \
  EveryWhisper.swift \
  -framework AppKit \
  -framework AVFoundation \
  -framework Carbon \
  -framework ApplicationServices
if [[ "$OUT" = /* ]]; then
  echo "Built: $OUT"
else
  echo "Built: $(pwd)/$OUT"
fi
file "$OUT"
