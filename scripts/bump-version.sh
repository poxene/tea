#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="${PROJECT_DIR}/scripts/tea-version.sh"
TOC_FILE="${PROJECT_DIR}/tea.toc"
PART="patch"

usage() {
  cat <<'EOF'
Usage: scripts/bump-version.sh [--major | --minor | --patch]

Bump TEA_VERSION in scripts/tea-version.sh and sync ## Version in tea.toc (default: patch).
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

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "Error: scripts/tea-version.sh not found at $VERSION_FILE" >&2
  exit 1
fi

if [[ ! -f "$TOC_FILE" ]]; then
  echo "Error: tea.toc not found at $TOC_FILE" >&2
  exit 1
fi

# shellcheck source=tea-version.sh
source "$VERSION_FILE"

CURRENT="${TEA_VERSION:-}"
if [[ -z "$CURRENT" ]]; then
  echo "Error: TEA_VERSION is not set in scripts/tea-version.sh" >&2
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

sed -i "s/^TEA_VERSION=.*/TEA_VERSION=\"${NEXT}\"/" "$VERSION_FILE"
sed -i "s/^## Version: .*/## Version: ${NEXT}/" "$TOC_FILE"
echo "Version: ${CURRENT} -> ${NEXT}"
