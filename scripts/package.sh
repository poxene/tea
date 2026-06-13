#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOC_FILE="${PROJECT_DIR}/tea.toc"
DIST_DIR="${PROJECT_DIR}/dist"
ADDON_NAME="$(basename "$PROJECT_DIR")"

if [[ ! -f "$TOC_FILE" ]]; then
  echo "Error: tea.toc not found in $PROJECT_DIR" >&2
  exit 1
fi

VERSION="$(grep '^## Version:' "$TOC_FILE" | awk '{print $3}')"
if [[ -z "$VERSION" ]]; then
  echo "Error: could not read version from tea.toc" >&2
  exit 1
fi

OUTPUT_NAME="${1:-tea-${VERSION}.zip}"
OUTPUT_PATH="${DIST_DIR}/${OUTPUT_NAME}"

mkdir -p "$DIST_DIR"
rm -f "$OUTPUT_PATH"

(
  cd "$(dirname "$PROJECT_DIR")"
  zip -r "$OUTPUT_PATH" "$ADDON_NAME" \
    -x "$ADDON_NAME/.git/*" \
    -x "$ADDON_NAME/.vscode/*" \
    -x "$ADDON_NAME/scripts/*" \
    -x "$ADDON_NAME/dist/*"
)

echo "Created $OUTPUT_PATH"
echo "Share this zip. It should unpack to: Interface/AddOns/tea/tea.toc"
