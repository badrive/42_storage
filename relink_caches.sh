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

GOINFRE="${GOINFRE_CACHE:-/goinfre/$USER/cache}"

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

running() {
  [ -z "$1" ] && return 1
  # -x matches the process name exactly. Do NOT use -f here: it matches whole
  # command lines, so any process merely mentioning "code" or "cursor" (this
  # script included) would count as running and every dir would be skipped.
  pgrep -u "$USER" -x "$1" >/dev/null 2>&1
}

# Your home is network-attached (iSCSI) and follows you between posts, but
# /goinfre is a local disk and does not. If it is missing or unwritable here,
# any symlink pointing into it is dangling -- turn those back into real dirs so
# apps keep working, then stop. Nothing is deleted on this path.
if ! mkdir -p "$GOINFRE" 2>/dev/null || [ ! -w "$GOINFRE" ]; then
  echo "/goinfre unavailable on this machine -- restoring local cache dirs"
  for entry in "${LINKS[@]}"; do
    IFS='|' read -r rel _ _ <<<"$entry"
    src="$HOME/$rel"
    if [ -L "$src" ] && [ ! -d "$src" ]; then
      rm -f "$src"
      mkdir -p "$src"
      echo "RESTORED $rel (now a real directory)"
    fi
  done
  exit 0
fi

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
