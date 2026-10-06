#!/usr/bin/env bash
# Run tests/lazyvim inside a real LazyVim with the neo-tree extra (like Omarchy).
# Uses $LAZYVIM_HOME if set (a HOME that already has LazyVim and this plugin installed),
# otherwise installs the LazyVim starter into a throwaway HOME (needs network, for CI).
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -n "${LAZYVIM_HOME:-}" ]]; then
  export HOME="$LAZYVIM_HOME"
else
  export HOME="$(mktemp -d)"
  trap 'rm -rf "$HOME"' EXIT
  git clone --quiet --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
  printf '{ "extras": ["lazyvim.plugins.extras.editor.neo-tree"], "install_version": 8, "news": {}, "version": 8 }\n' \
    >"$HOME/.config/nvim/lazyvim.json"
  printf 'return { "smanookian/lazynator.nvim", dir = "%s", opts = {} }\n' "$repo" \
    >"$HOME/.config/nvim/lua/plugins/lazynator.lua"
fi
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"

if [[ -z "${LAZYVIM_HOME:-}" ]]; then
  nvim --headless "+Lazy! sync" +qa
fi

cd "$(mktemp -d)"
nvim --headless -u "$XDG_CONFIG_HOME/nvim/init.lua" -l "$repo/tests/run.lua" "$repo/tests/lazyvim/lazyvim_spec.lua"
