#!/usr/bin/env bash
# SessionStart hook: advance the coralline theme rotation ONCE per Claude Code launch
# (startup or resume). Records "session_id|idx" in the same state file coralline.conf
# reads, so the statusline just looks its session up and the theme stays fixed
# until the next launch. The newest line for a session id wins.
N=4   # number of themes in coralline.conf's _cor_themes
DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/coralline"
STATE="$DIR/theme-rotation.state"
sid=$(cat | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0
mkdir -p "$DIR"
last=$(tail -n 1 "$STATE" 2>/dev/null | awk -F'|' '{print $2}')
idx=$(( (${last:-$((N - 1))} + 1) % N ))
printf '%s|%s\n' "$sid" "$idx" >> "$STATE"
tail -n 50 "$STATE" > "$STATE.tmp" 2>/dev/null && mv "$STATE.tmp" "$STATE"
exit 0
