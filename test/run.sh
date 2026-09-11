#!/usr/bin/env sh
set -eu

resource_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
luac -p "$resource_root/config.lua" "$resource_root/server.lua" "$resource_root/client/client.lua" "$resource_root/fxmanifest.lua"
lua "$resource_root/test/server.lua" "$resource_root"
