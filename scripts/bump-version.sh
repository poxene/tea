#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOC_FILE="${PROJECT_DIR}/tea.toc"
PART="patch"

usage() {
  cat <<'EOF'
Usage: scripts/bump-version.sh [--major | --minor | --patch]

Bump ## Version in tea.toc (default: patch).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --major)
      PART="major"
      shift
      ;;
    --minor)
      PART="minor"
      shift
      ;;
    --patch)
      PART="patch"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$TOC_FILE" ]]; then
  echo "Error: tea.toc not found at $TOC_FILE" >&2
  exit 1
fi

CURRENT="$(grep '^## Version:' "$TOC_FILE" | awk '{print $3}')"
if [[ -z "$CURRENT" ]]; then
  echo "Error: could not read version from tea.toc" >&2
  exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"

case "$PART" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

NEXT="${MAJOR}.${MINOR}.${PATCH}"

if [[ "$CURRENT" == "$NEXT" ]]; then
  echo "Version unchanged: $CURRENT"
  exit 0
fi

sed -i "s/^## Version: .*/## Version: ${NEXT}/" "$TOC_FILE"
echo "Version: ${CURRENT} -> ${NEXT}"
