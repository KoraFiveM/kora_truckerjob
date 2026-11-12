---
title: kora_truckerjob
sidebar_position: 1
---

# kora_truckerjob

`kora_truckerjob` is a freight (trucking) job for Kora servers. Anyone can open the **Freight Dispatch** app at the depot, accept a generated delivery contract, collect a depot truck and the assigned trailer, drive to the drop-off, reverse the trailer into a marked bay, detach it and get paid. Completed contracts earn XP; every 1000 XP gives a skill point that unlocks longer routes, more demanding cargo and tighter time limits. Players can also buy better trucks with bank money. Contracts, vehicles, payouts, XP and purchases are all decided by the server.

Current version: see `version` in `fxmanifest.lua`.

## Features

- **Generated contracts** - a shared board of up to `Config.MaxJobs` contracts is generated at resource start and topped up on a timer. See [Contracts](./contracts.md).
- **Skills and XP** - three skills (Distance, Cargo, Expedited), level 1 to 4, raised with skill points earned from XP. See [Skills and progression](./progression.md).
- **Truck fleet** - four configurable trucks; the free Hauler is always owned, others are bought with bank money. See [Truck fleet](./progression.md#truck-fleet).
- **Server-owned vehicles** - the truck and trailer are created by the server, tied to the player and deleted on return, abandon, disconnect or resource stop. See [How to use](./how-to-use.md).
- **Delivery bay** - the trailer must be parked inside a marker, aligned and detached; the server re-checks position and heading before paying.
- **Truck return** - the truck can be handed back at the return point after a contract, or kept for the next one.
- **Optional contract cooldown, keys and fuel integration** - see [Configuration](./configuration.md).

## Documentation map

- [Installation](./installation.md) - install steps, dependencies, start order, manifest reference and optional resources
- [How to use](./how-to-use.md) - player and admin walkthrough: dispatch, contract generation, accepting, delivery, abandoning, truck return, skills, plus a step-by-step journey
- [API reference](./api/index.md) - overview of the resource's exports
  - [Client export](./api/exports.md) - `openDispatch`, the FFT test hook exports and the exports used from other resources
- [Contracts](./contracts.md) - how contracts are generated, qualified for, timed and paid, and the default cargo types
- [Skills and progression](./progression.md) - XP, skill points, skill levels and the truck fleet
- [Configuration](./configuration.md) - every `Config` option
- [Freight Dispatch app](./ui.md) - the NUI app, target zones, prompts, keybinds and blips
- [Events and callbacks](./events.md) - server callbacks, game events and other integration points
- [Data storage](./database.md) - where player data is stored (no SQL tables)
- [Testing](./testing.md) - offline tests and QA scenarios
- [Troubleshooting](./troubleshooting.md) - known caveats and common problems

This resource registers no commands, no items and no ACE permissions, so there is no commands page.
