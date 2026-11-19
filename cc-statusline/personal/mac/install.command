#!/usr/bin/env bash
# One-click installer: coralline statusline for macOS.
# Uses the coralline.conf sitting next to this script (profile = this folder).
#
#   Double-click in Finder, or run:  bash install.command
#
# What it does:
#   1. makes sure jq is installed (via Homebrew if missing), plus JetBrainsMono Nerd Font
#      (skip the font with:  bash install.command --no-font)
#   2. installs upstream coralline, pinned to a release tag (runtime files + statusLine in settings.json)
#   3. enables the subagent panel row
#   4. copies this folder's coralline.conf to ~/.claude/coralline.conf (existing one is backed up)
#
# Override the pinned release with:  CORALLINE_REF=v0.21.0 bash install.command

set -eu
set -o pipefail

REF="${CORALLINE_REF:-v0.20.1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
STAMP="$(date +%Y%m%d%H%M%S)"
TMP_FILES=""

step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

cleanup() {
  rc=$?
  for f in $TMP_FILES; do rm -f "$f"; done
  # Keep the Terminal window readable when launched by double-click.
  if [ -t 0 ]; then printf '\nPress Enter to close...'; read -r _ || true; fi
  exit "$rc"
}
trap cleanup EXIT

[ -f "$HERE/coralline.conf" ] || die "coralline.conf not found next to this script ($HERE)"

# ---- 1. prerequisites ------------------------------------------------------
step "Checking jq"
if ! command -v jq >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install jq
  else
    die "jq is missing and Homebrew is not installed. Install Homebrew (https://brew.sh), then run this again."
  fi
fi
command -v curl >/dev/null 2>&1 || die "curl is required but was not found."
echo "jq: $(command -v jq)"

# Nerd Font (optional, non-fatal). Skip with:  bash install.command --no-font
FONT_NOTE="If icons look broken, set your terminal font to a Nerd Font."
if [ "${1:-}" = "--no-font" ]; then
  echo "Skipping Nerd Font (--no-font)."
elif ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found: skipping Nerd Font."
elif brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
  echo "Nerd Font already installed (JetBrainsMono)."
  FONT_NOTE="Make sure your terminal font is set to 'JetBrainsMono Nerd Font'."
elif brew install --cask font-jetbrains-mono-nerd-font; then
  FONT_NOTE="Installed JetBrainsMono Nerd Font. Now select it in your terminal's profile/font settings."
else
  warn "Nerd Font install failed (non-fatal). Try: brew install --cask font-jetbrains-mono-nerd-font"
fi

# ---- 2. upstream coralline -------------------------------------------------
step "Installing coralline $REF (upstream)"
INSTALLER="$(mktemp "${TMPDIR:-/tmp}/coralline-install.XXXXXX")"
TMP_FILES="$INSTALLER"
curl -fsSL "https://raw.githubusercontent.com/Nanako0129/coralline/$REF/install.sh" -o "$INSTALLER"
bash "$INSTALLER" --install-only --ref "$REF"

# ---- 3. subagent panel row -------------------------------------------------
step "Enabling subagent status row"
bash "$CLAUDE_DIR/coralline/configure.sh" --subagent-rows=on \
  || warn "Could not enable the subagent row (non-fatal). Run: bash ~/.claude/coralline/configure.sh --subagent-rows=on"

# ---- 4. your config --------------------------------------------------------
step "Installing your coralline.conf"
mkdir -p "$CLAUDE_DIR"
DEST="$CLAUDE_DIR/coralline.conf"
CLEAN="$(mktemp "${TMPDIR:-/tmp}/coralline-conf.XXXXXX")"
TMP_FILES="$TMP_FILES $CLEAN"
tr -d '\r' < "$HERE/coralline.conf" > "$CLEAN"   # strip CRLF if git converted line endings
if [ -f "$DEST" ] && cmp -s "$CLEAN" "$DEST"; then
  echo "Already up to date: $DEST"
else
  if [ -f "$DEST" ]; then
    cp "$DEST" "$DEST.bak.$STAMP"
    echo "Backed up existing config to $DEST.bak.$STAMP"
  fi
  cp "$CLEAN" "$DEST"
  echo "Wrote $DEST"
fi

# ---- done ------------------------------------------------------------------
step "Done"
echo "Restart Claude Code to see the new statusline."
echo
echo "$FONT_NOTE"
