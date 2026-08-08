#!/usr/bin/env bash
# Reclaim space on the small ~ partition by DELETING regenerable caches and
# dead weight. Everything here either rebuilds itself on demand or is already
# orphaned -- no projects, configs, keys or history are touched.
#
# Companion to relink-caches.sh, which handles the recurrence rather than the
# one-off cleanup. Safe to re-run; each step is guarded.
#
# Dirs belonging to a running app are skipped, so close VS Code, Cursor and
# your browsers first for a full sweep.

set -uo pipefail

before=$(df -k "$HOME" | awk 'NR==2{print $4}')

running() { pgrep -u "$USER" -x "$1" >/dev/null 2>&1; }

zap() {  # zap <path> [more paths...]
  for p in "$@"; do
    [ -e "$p" ] || continue
    sz=$(du -xsh "$p" 2>/dev/null | cut -f1)
    rm -rf "$p" && echo "  removed $sz  ${p#$HOME/}"
  done
}

echo "=== 1. Orphaned flatpak objects in the per-user repo ==="
# Apps installed system-wide leave unreferenced objects here. Prunes to ~nothing
# when no --user apps exist; keeps whatever is genuinely referenced if they do.
if command -v flatpak >/dev/null; then
  du -xsh "$HOME/.local/share/flatpak/repo" 2>/dev/null
  flatpak repair --user 2>&1 | tail -3
  flatpak uninstall --unused --user -y 2>/dev/null | tail -2
  du -xsh "$HOME/.local/share/flatpak/repo" 2>/dev/null
fi

echo "=== 2. VS Code ==="
# .vsix installer archives kept after install -- redundant with ~/.vscode/extensions.
zap "$HOME/.config/Code/CachedExtensionVSIXs"
if running code; then
  echo "  SKIP live profile data (VS Code running)"
else
  zap "$HOME/.config/Code/Cache" "$HOME/.config/Code/Code Cache" \
      "$HOME/.config/Code/GPUCache" "$HOME/.config/Code/CachedData" \
      "$HOME/.config/Code/CachedProfilesData" "$HOME/.config/Code/logs" \
      "$HOME/.config/Code/WebStorage" "$HOME/.config/Code/Crashpad"
fi

echo "=== 3. Duplicate hand-downloaded VS Code ==="
# Only if the system package is present, so this can't leave you without an editor.
if [ -x /usr/share/code/code ] || [ -x /usr/bin/code ]; then
  zap "$HOME/apps/VSCode-linux-x64"
else
  echo "  SKIP (no system VS Code found -- the local copy may be your only one)"
fi

echo "=== 4. Cursor ==="
if running cursor; then
  echo "  SKIP (Cursor running)"
else
  zap "$HOME/.config/Cursor/User/globalStorage/state.vscdb.backup" \
      "$HOME/.config/Cursor/Cache" "$HOME/.config/Cursor/Code Cache" \
      "$HOME/.config/Cursor/GPUCache" "$HOME/.config/Cursor/CachedData" \
      "$HOME/.config/Cursor/CachedProfilesData" "$HOME/.config/Cursor/logs" \
      "$HOME/.config/Cursor/DawnGraphiteCache" "$HOME/.config/Cursor/DawnWebGPUCache"
fi

echo "=== 5. Browsers ==="
for b in "BraveSoftware/Brave-Browser:brave" "google-chrome:chrome"; do
  dir="${b%%:*}"; proc="${b##*:}"
  root="$HOME/.config/$dir"
  [ -d "$root" ] || continue
  if running "$proc"; then
    echo "  SKIP $dir ($proc running)"
    continue
  fi
  zap "$root/component_crx_cache" "$root/extensions_crx_cache" \
      "$root/GrShaderCache" "$root/ShaderCache" "$root/GraphiteDawnCache" \
      "$root/Crash Reports" \
      "$root/Default/Cache" "$root/Default/Code Cache" "$root/Default/GPUCache" \
      "$root/Default/Service Worker/CacheStorage"
done

echo "=== 6. Trash + thumbnails ==="
zap "$HOME/.local/share/Trash" "$HOME/.cache/thumbnails"

after=$(df -k "$HOME" | awk 'NR==2{print $4}')
echo
printf "Reclaimed: %.1f GB\n" "$(echo "($after - $before) / 1048576" | bc -l)"
df -h "$HOME" | tail -1
