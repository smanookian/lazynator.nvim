#!/usr/bin/env bash
# Run the headless tests in a throwaway data dir.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache"
nvim --headless --clean -u tests/init.lua -l tests/run.lua "$@"
