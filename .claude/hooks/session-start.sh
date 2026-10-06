#!/bin/bash
# Installs the pinned Godot headless binary for Claude Code cloud sessions and
# imports the project so GUT tests can run straight away.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.7.2-stable"
INSTALL_DIR="$HOME/.local/share/godot-bin/$GODOT_VERSION"
GODOT_BIN="$INSTALL_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"

if [ ! -x "$GODOT_BIN" ]; then
  mkdir -p "$INSTALL_DIR"
  tmp_zip="$(mktemp --suffix=.zip)"
  curl -fsSL --retry 4 --retry-delay 2 -o "$tmp_zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -o -q "$tmp_zip" -d "$INSTALL_DIR"
  rm -f "$tmp_zip"
  chmod +x "$GODOT_BIN"
fi

mkdir -p "$HOME/.local/bin"
ln -sf "$GODOT_BIN" "$HOME/.local/bin/godot"
echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# Build .godot/ (class_name cache, imports) so tests resolve on a fresh clone.
cd "$CLAUDE_PROJECT_DIR"
"$GODOT_BIN" --headless --import --path . > /dev/null 2>&1 || true
