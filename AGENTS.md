# kora_truckerjob agent guide

`kora_truckerjob` is a Kora freight job: players accept generated delivery contracts in a `kora_lib` NUI app opened via `kora_target`, haul a server-spawned trailer with a depot truck, earn XP and skill points, and buy trucks. Layout: `fxmanifest.lua`, `config.lua` (shared config and coordinates), `client/client.lua` (app, zones, prompts, blips, delivery watch), `server.lua` (contract board, vehicle spawning, payout and progression authority), `fft_hooks.lua` (optional test hooks), `test/` (offline Lua tests), `tests/` (kora_qa feature files), `html/images/` (NUI images) and `stream/` (map ymap).

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first for an overview of features, configuration, commands, exports, events and database usage.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.
