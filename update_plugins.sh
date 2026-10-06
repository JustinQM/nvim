#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lock_name="nvim-pack-lock.json"

command -v nvim >/dev/null 2>&1 || { echo "error: nvim not found in PATH" >&2; exit 1; }
[ -f "$repo_dir/init.lua" ] || { echo "error: no init.lua in $repo_dir" >&2; exit 1; }
if [ -e "$repo_dir/$lock_name" ] && [ ! -w "$repo_dir/$lock_name" ]
then
    echo "error: $repo_dir/$lock_name is not writable." >&2
    echo "       Run this script from the repo checkout, not the deployed ~/.config/nvim." >&2
    exit 1
fi

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

# Use the repo (not the deployed store copy) so plugins added to init.lua since
# the last rebuild are included. -L turns any store symlinks into real files.
mkdir "$tmp_root/nvim"
find "$repo_dir" -mindepth 1 -maxdepth 1 ! -name .git ! -name .jj \
    -exec cp -rL {} "$tmp_root/nvim/" \;
chmod -R u+w "$tmp_root"

tmp_lock="$tmp_root/nvim/$lock_name"
before="(absent)"
if [ -f "$tmp_lock" ]
then
    before="$(sha256sum "$tmp_lock" | cut -d' ' -f1)"
fi

echo "config source : $repo_dir"
echo "scratch config: $tmp_root/nvim"
echo
echo "Neovim will open the vim.pack confirmation tabpage."
echo "  :write  confirm the updates"
echo "  :quit   discard them"
echo

# XDG_CONFIG_HOME is overridden for this process only; stdpath('data') is
# untouched, so plugins still install to their real location. Start in the
# scratch dir so nothing in the current directory (sessions, exrc) gets loaded.
(cd "$tmp_root" && XDG_CONFIG_HOME="$tmp_root" nvim +'lua vim.pack.update()')

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
