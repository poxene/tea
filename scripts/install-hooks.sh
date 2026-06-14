#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="${ROOT}/.git/hooks"
SOURCE_DIR="${ROOT}/scripts/hooks"

if [[ ! -d "${ROOT}/.git" ]]; then
  echo "Error: .git not found. Run this from the tea repository." >&2
  exit 1
fi

mkdir -p "$HOOKS_DIR"

for hook in "$SOURCE_DIR"/*; do
  [[ -f "$hook" ]] || continue
  name="$(basename "$hook")"
  target="${HOOKS_DIR}/${name}"
  cp "$hook" "$target"
  chmod +x "$target"
  echo "Installed ${name}"
done

echo "Git hooks installed. Commits will auto-bump tea.toc patch version."
