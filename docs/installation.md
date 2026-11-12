---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Truckerjob is an open-to-anyone (no employment required) freight-hauling job: accept a generated delivery contract at the depot, dispatch a truck and the matching trailer, drive it to a delivery marker, back the trailer in and detach it for payment and XP. It has its own job-internal distance/cargo/time skill system, separate from kora_skills.

## Install Kora Truckerjob

1. **Add the folder** — Place `kora_truckerjob` in your resources directory (on the Kora recipe it is `resources/[kora]/kora_truckerjob`). It is marked `this_is_a_map 'yes'`, so it also carries its own trailer image assets under `files { 'html/images/**/*.webp' }`.

2. **Have the dependencies running** — The manifest declares `dependency 'kora_lib'`, `dependency 'kora_core'` and `dependency 'kora_target'`. kora_lib provides `Kora.nui`/`Kora.callback`/`Kora.blips`/`Kora.textui`, kora_core provides player identity, money and per-character metadata, and kora_target provides the depot eye-target.

3. **Start it** — Order only matters relative to its three dependencies.

   ```bash title="server.cfg"
   ensure kora_lib
   ensure kora_core
   ensure kora_target
   ensure kora_truckerjob
   ```

4. **Key delivery integration** — `Config.GiveKeys = true` (default) issues vehicle keys through `Config.KeysResource` (default `'kora_vehiclekeys'`). A commented-out `dependency 'kora_vehiclekeys'` line in the manifest shows it is not a declared dependency: `giveKeys`/`removeKeys` calls are wrapped in `pcall`, but with `Config.GiveKeys` on, a failed `giveKeys` (resource not running or the export fails) makes the truck request fail with "Vehicle keys could not be issued." and the spawned truck is deleted. Either start `kora_vehiclekeys` or set `Config.GiveKeys = false` and handle keys yourself.

5. **Nothing to configure in the database** — This resource keeps no SQL tables of its own. Per-character trucking progress (skills, XP, skill points, owned/active trucks) is stored in kora_core character metadata under the `rep.trucker` key, alongside any other resource's `rep` data.

## Manifest reference

```lua title="fxmanifest.lua"
dependencies { 'kora_lib', 'kora_core', 'kora_target' }
--dependency 'kora_vehiclekeys' -- optional; commented out, see Installation

shared_script '@kora_lib/init.lua'
shared_scripts { '@kora_core/init.lua', 'config.lua' }
client_scripts { 'client/client.lua', 'fft_hooks.lua' }
server_script 'server.lua'
files { 'html/images/**/*.webp' }
this_is_a_map 'yes'
```

## Dependency details


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


## Streamed map and images

The resource also streams `stream/hei_po1_06_strm_0.ymap`. The NUI images under `html/images/` are listed in the manifest `files` block and loaded as `nui://kora_truckerjob/html/images/...`.

## Optional FFT hooks

`fft_hooks.lua` is loaded last on the client and returns immediately unless the convar `fft_kora_hooks` is `true`. See [API reference: Client export](./api/exports.md#fft-test-hooks).

## Next steps

Review [Configuration](./configuration.md) and [Data storage](./database.md).
