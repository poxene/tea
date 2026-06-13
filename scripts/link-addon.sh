#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WOW_ADDONS="/home/tea/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/Interface/AddOns"
TARGET="${WOW_ADDONS}/tea"

if [[ -e "$TARGET" && ! -L "$TARGET" ]]; then
  echo "Error: $TARGET exists and is not a symlink." >&2
  exit 1
fi

ln -sfn "$PROJECT_DIR" "$TARGET"
echo "Linked $TARGET -> $PROJECT_DIR"
