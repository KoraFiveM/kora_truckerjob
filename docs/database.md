---
title: Data storage
sidebar_position: 11
---

# Data storage

The resource has no SQL tables, no SQL files and does not use a database resource directly.

## Persistent player data

Trucker progress is stored in the `rep` metadata of the character through `kora_core` (`getMetaData(source, 'rep')` and `setMetaData`). The `trucker` key inside it holds:

| Field | Type | Description |
| --- | --- | --- |
| `skills` | table | `distance`, `cargo`, `time`, each 1 to 4 |
| `skillPoints` | integer | Unspent skill points |
| `XP` | number | Total experience |
| `trucks` | table | Owned truck models as `name = true` |
| `activeTruck` | string | Truck dispatched for new contracts |

Other keys in `rep` are preserved. Persistence is handled by `kora_core`.

## In-memory state (server)

| State | Lifetime |
| --- | --- |
| Contract board | Until resource restart |
| Spawned truck, trailer, plate per player | Until return, disconnect or resource stop |
| Contract cooldowns | Until resource restart |
