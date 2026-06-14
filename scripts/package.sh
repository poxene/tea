#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/package.sh [options] [output.zip]

Build a distributable zip from the addon source.

Options:
  --release          Publish the zip to GitHub Releases (requires gh CLI)
  --draft            Create a draft release (with --release)
  --prerelease       Mark the release as a pre-release (with --release)
  --notes TEXT       Release notes (with --release)
  --generate-notes   Auto-generate release notes from commits (with --release)
  -h, --help         Show this help

Examples:
  scripts/package.sh
  scripts/package.sh --release
  scripts/package.sh --release --generate-notes
  scripts/package.sh tea-0.6.0.zip
EOF
}

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOC_FILE="${PROJECT_DIR}/tea.toc"
DIST_DIR="${PROJECT_DIR}/dist"
ADDON_NAME="$(basename "$PROJECT_DIR")"

PUBLISH_RELEASE=false
DRAFT_RELEASE=false
PRERELEASE=false
GENERATE_NOTES=false
RELEASE_NOTES=""

OUTPUT_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      PUBLISH_RELEASE=true
      shift
      ;;
    --draft)
      DRAFT_RELEASE=true
      shift
      ;;
    --prerelease)
      PRERELEASE=true
      shift
      ;;
    --generate-notes)
      GENERATE_NOTES=true
      shift
      ;;
    --notes)
      RELEASE_NOTES="${2:-}"
      if [[ -z "$RELEASE_NOTES" ]]; then
        echo "Error: --notes requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      OUTPUT_NAME="$1"
      shift
      ;;
  esac
done

if [[ ! -f "$TOC_FILE" ]]; then
  echo "Error: tea.toc not found in $PROJECT_DIR" >&2
  exit 1
fi

VERSION="$(grep '^## Version:' "$TOC_FILE" | awk '{print $3}')"
if [[ -z "$VERSION" ]]; then
  echo "Error: could not read version from tea.toc" >&2
  exit 1
fi

if [[ -z "$OUTPUT_NAME" ]]; then
  OUTPUT_NAME="tea-${VERSION}.zip"
fi

OUTPUT_PATH="${DIST_DIR}/${OUTPUT_NAME}"
TAG="v${VERSION}"

mkdir -p "$DIST_DIR"
rm -f "$OUTPUT_PATH"

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT
STAGE_ADDON="${STAGE_DIR}/${ADDON_NAME}"

mkdir -p "$STAGE_ADDON"
cp "$TOC_FILE" "$STAGE_ADDON/"
cp -r "${PROJECT_DIR}/Core" "${PROJECT_DIR}/Modules" "$STAGE_ADDON/"
if [[ -f "${PROJECT_DIR}/README.md" ]]; then
  cp "${PROJECT_DIR}/README.md" "$STAGE_ADDON/"
fi

(
  cd "$STAGE_DIR"
  zip -r "$OUTPUT_PATH" "$ADDON_NAME"
)

echo "Created $OUTPUT_PATH"
echo "Share this zip. It should unpack to: Interface/AddOns/tea/tea.toc"

publish_release() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: gh CLI is not installed." >&2
    echo "Install it from https://cli.github.com/ then run: gh auth login" >&2
    exit 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "Error: gh is not authenticated. Run: gh auth login" >&2
    exit 1
  fi

  local title="tea ${VERSION}"
  local create_args=(
    "$TAG"
    "$OUTPUT_PATH"
    --title "$title"
  )

  if [[ "$DRAFT_RELEASE" == true ]]; then
    create_args+=(--draft)
  fi

  if [[ "$PRERELEASE" == true ]]; then
    create_args+=(--prerelease)
  fi

  if [[ "$GENERATE_NOTES" == true ]]; then
    create_args+=(--generate-notes)
  elif [[ -n "$RELEASE_NOTES" ]]; then
    create_args+=(--notes "$RELEASE_NOTES")
  else
    create_args+=(--notes "WoW Classic Era release for tea ${VERSION}.")
  fi

  if gh release view "$TAG" >/dev/null 2>&1; then
    echo "Release $TAG already exists. Uploading asset..."
    gh release upload "$TAG" "$OUTPUT_PATH" --clobber
    echo "Updated asset on https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/$TAG"
    return
  fi

  gh release create "${create_args[@]}"
  echo "Published https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/$TAG"
}

if [[ "$PUBLISH_RELEASE" == true ]]; then
  publish_release
fi
