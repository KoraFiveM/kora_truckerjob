---
title: Testing
sidebar_position: 12
---

# Testing

- `sh test/run.sh` syntax-checks `config.lua`, `server.lua`, `client/client.lua` and `fxmanifest.lua` with `luac -p`, then runs `test/server.lua` and `test/client.lua` with plain `lua` against stubbed FiveM and `kora_lib` functions. It does not start FiveM. It requires `luac` and `lua` on the path.
- `tests/checklist-jobs.feature` contains manual QA scenarios for `kora_qa` (registered with `qa_feature` in `fxmanifest.lua`): depot blip, dispatch app, contract list and generation, truck and trailer dispatch, delivery bay, penalties, truck return, skills, XP, trucks and lost vehicles.

Note that the penalties and XP scenarios say the penalties reduce "pay/XP". In the code, penalties reduce only pay; for XP they only remove the multipliers (see [Contracts](./contracts.md#xp)).
