#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${NVIM_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/nvim}"
lock_name="nvim-pack-lock.json"

command -v nvim >/dev/null 2>&1 || { echo "error: nvim not found in PATH" >&2; exit 1; }
[ -d "$config_dir" ] || { echo "error: config dir not found: $config_dir" >&2; exit 1; }

# If this nvim already has 'packlockfile', the whole dance is obsolete.
has_opt="$(nvim --clean --headless \
    -c 'call writefile([string(exists("&packlockfile"))], "/dev/stderr")' \
    -c 'quit' 2>&1 | tr -d '[:space:]' || true)"
if [ "$has_opt" = "1" ]
then
    echo "note: this nvim has 'packlockfile' — set it in init.lua and retire this script."
    echo
fi

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# -L resolves store symlinks into real files so the copy is writable.
cp -rL "$config_dir" "$tmp_root/nvim"
chmod -R u+w "$tmp_root"

tmp_lock="$tmp_root/nvim/$lock_name"
before="(absent)"
if [ -f "$tmp_lock" ]
then
    before="$(sha256sum "$tmp_lock" | cut -d' ' -f1)"
fi

echo "config source : $config_dir"
echo "scratch config: $tmp_root/nvim"
echo
echo "Neovim will open the vim.pack confirmation tabpage."
echo "  :write  confirm the updates"
echo "  :quit   discard them"
echo

# XDG_CONFIG_HOME is overridden for this process only; stdpath('data') is
# untouched, so plugins still install to their real location.
XDG_CONFIG_HOME="$tmp_root" nvim +'lua vim.pack.update()'

if [ ! -f "$tmp_lock" ]
then
    echo "error: no lockfile was produced — nothing to copy" >&2
    exit 1
fi

after="$(sha256sum "$tmp_lock" | cut -d' ' -f1)"
if [ "$before" = "$after" ]
then
    echo
    echo "lockfile unchanged — nothing to do."
    exit 0
fi

cp "$tmp_lock" "$repo_dir/$lock_name"
chmod u+w "$repo_dir/$lock_name"

echo
echo "wrote $repo_dir/$lock_name"

if git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1
then
    git -C "$repo_dir" --no-pager diff --stat -- "$lock_name" || true
fi

cat <<'EOF'

Next steps, in this order:
  1. commit the lockfile
  2. nixos-rebuild switch  (so the store copy matches)
  3. restart nvim

Do not skip step 2 before restarting: the store still holds the OLD lockfile,
and vim.pack aligns installed plugins with the lockfile on its first call.
EOF
