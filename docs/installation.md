---
title: Installation
sidebar_position: 2
---

# Installation

## Dependencies

Declared in `fxmanifest.lua` (`dependencies`):

| Resource | Used for |
| --- | --- |
| `kora_lib` | `Kora.nui` app shell, callbacks, notifications, text prompts, zones, keybinds, blips, `Kora.cache`, `Kora.config.adopt` |
| `kora_core` | Player metadata (`getMetaData` / `setMetaData`), money (`addMoney` / `removeMoney`), `getPlayer`, `getPlayerData`, `randomStr`, `randomInt` |
| `kora_target` | Eye-target zones at the job station and the trailer locator |

Used but not declared as a dependency (the line `'kora_vehiclekeys'` is commented out in `fxmanifest.lua`):

| Resource | Used for |
| --- | --- |
| `kora_vehiclekeys` | `giveKeys` and `removeKeys` for the job truck, via `Config.KeysResource` |

Optional:

| Resource | Used for |
| --- | --- |
| Fuel resource named in `Config.FuelResource` (default `LegacyFuel`) | When running, a newly dispatched truck gets `SetFuel(truck, 50-70)` (client side) |

`Config.GiveKeys` is `true` by default. In that case the truck request fails with "Vehicle keys could not be issued." and the truck is deleted whenever the keys resource is not running or its `giveKeys` export fails. Either start `kora_vehiclekeys` or set `Config.GiveKeys = false` and handle keys yourself.

## Steps

1. Place the resource in your resources folder.
2. Start it after its dependencies:

   ```cfg
   ensure kora_lib
   ensure kora_core
   ensure kora_target
   ensure kora_vehiclekeys
   ensure kora_truckerjob
   ```

3. No SQL import and no items are needed. See [Data storage](./database.md).
4. Review [Configuration](./configuration.md).

The resource declares `this_is_a_map 'yes'` and streams `stream/hei_po1_06_strm_0.ymap`. The NUI images under `html/images/` are listed in the manifest `files` block and loaded as `nui://kora_truckerjob/html/images/...`.

## Optional FFT hooks

`fft_hooks.lua` is loaded last on the client and returns immediately unless the convar `fft_kora_hooks` is `true`. See [Exports](./exports.md#fft-test-hooks).
