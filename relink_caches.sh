#!/usr/bin/env bash
# Redirect bulky app caches from the 4.7G ~ partition onto /goinfre (22G free).
#
# Safe to re-run any time. Re-run it after /goinfre is wiped, or the first time
# you log into a different machine -- it recreates any missing targets so the
# symlinks never dangle.
#
# Close VS Code, Cursor and your browsers before running for the best result:
# dirs belonging to a running app are skipped rather than moved out from under it.

set -uo pipefail

GOINFRE="/goinfre/$USER/cache"

# home path under $HOME  ->  subdir name under $GOINFRE  ->  process to check
LINKS=(
  ".config/Code/CachedExtensionVSIXs|code-vsix|code"
  ".config/Code/CachedData|code-cacheddata|code"
  ".config/Code/WebStorage|code-webstorage|code"
  ".cache|cache|"
  ".config/Cursor/Cache|cursor-cache|cursor"
  ".config/Cursor/CachedData|cursor-cacheddata|cursor"
  ".config/BraveSoftware/Brave-Browser/component_crx_cache|brave-crx|brave"
  ".config/BraveSoftware/Brave-Browser/GrShaderCache|brave-shader|brave"
  ".config/google-chrome/component_crx_cache|chrome-crx|chrome"
)

mkdir -p "$GOINFRE" || { echo "cannot create $GOINFRE" >&2; exit 1; }

running() {
  [ -z "$1" ] && return 1
  pgrep -u "$USER" -f "$1" >/dev/null 2>&1
}

for entry in "${LINKS[@]}"; do
  IFS='|' read -r rel sub proc <<<"$entry"
  src="$HOME/$rel"
  dst="$GOINFRE/$sub"

  mkdir -p "$dst"

  if [ -L "$src" ]; then
    # Already linked. Target was just recreated above, so this repairs a
    # post-wipe dangling link.
    echo "ok      $rel -> $(readlink "$src")"
    continue
  fi

  if running "$proc"; then
    echo "SKIP    $rel (owning app '$proc' is running)"
    continue
  fi

  if [ -d "$src" ]; then
    # Move existing contents across, then replace with a symlink.
    if cp -a "$src/." "$dst/" 2>/dev/null && rm -rf "$src"; then
      ln -s "$dst" "$src"
      echo "MOVED   $rel -> $dst"
    else
      echo "FAILED  $rel (left untouched)" >&2
    fi
  else
    mkdir -p "$(dirname "$src")"
    ln -s "$dst" "$src"
    echo "LINKED  $rel -> $dst"
  fi
done

echo
df -h "$HOME" | tail -1
