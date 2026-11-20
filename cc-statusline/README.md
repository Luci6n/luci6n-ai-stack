# cc-statusline

My config for [coralline](https://github.com/Nanako0129/coralline), a Claude Code statusline,
plus one-click installers. Only my config and installers live here; the script and themes come
from upstream (MIT), pinned to release `v0.20.1`.

## Layout

    personal/   subscription plan: 5h/7d limit gauges + burn
    work/       pay-as-you-go API: cost instead of limits
      mac/      install.command   coralline.conf   rotate-theme.sh
      window/   setup.cmd  setup.ps1   coralline.conf   rotate-theme.sh

Both profiles rotate nord -> morning-haze -> gruvbox-dark -> claude-coral once per launch of Claude Code
(including `--resume`). A `SessionStart` hook, `rotate-theme.sh`, advances the rotation; open tabs keep
their own theme. If you add or remove a theme in `coralline.conf`, update `N` in `rotate-theme.sh`.
All profiles use the responsive `VL_LAYOUT="auto"`: one segment list that wraps to the terminal width
(up to 3 lines). Set it back to `"fixed"` in `coralline.conf` to get the old two fixed rows.
`settings.snippet.json` in each folder is reference only (manual setup); the installers do not use it.

## One-click install

**macOS** - double-click `install.command` in Finder, or run `bash install.command`.
Installs `jq` and JetBrainsMono Nerd Font with Homebrew if missing (Homebrew itself is not
installed for you). Skip the font with `bash install.command --no-font`.
The first double-click may need right-click > Open (Gatekeeper), and the file needs its
executable bit (`chmod +x install.command`, or `git update-index --chmod=+x` before committing).

**Windows** - double-click `setup.cmd`, or run
`powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1`.
Installs Git for Windows, `jq` and JetBrainsMono Nerd Font with winget if missing.
Skip the font with `setup.cmd -NoFont`. A managed work laptop may block winget or script
execution; install Git for Windows and `jq` by hand and re-run.

Each installer: installs upstream coralline at the pinned tag, enables the subagent row,
installs `rotate-theme.sh` plus its `SessionStart` entry in `~/.claude/settings.json` (backed up first),
then copies this folder's `coralline.conf` to `~/.claude/coralline.conf`
(an existing different one is backed up as `coralline.conf.bak.<timestamp>`).
Re-running is safe. Restart Claude Code afterwards.

Pin a different release with `CORALLINE_REF=v0.21.0` (env var) before running.

## Notes

- A Windows render takes ~1s (each Git Bash process costs ~0.15s). If the bar goes blank, raise
  `refreshInterval` in `settings.json` (a render must finish before the next refresh starts).
- Windows must use the Bash renderer (Git Bash + `jq`). The theme rotation is shell code in
  `coralline.conf`; the native PowerShell renderer parses the file instead of executing it.
- Installing the font is not enough: select "JetBrainsMono Nerd Font" in your terminal's
  font settings yourself, otherwise the icons look broken.
- `.gitattributes` keeps `.sh/.command/.conf` as LF. A CRLF `coralline.conf` breaks bash.
