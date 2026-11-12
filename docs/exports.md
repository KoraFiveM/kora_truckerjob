---
title: Exports
sidebar_position: 9
---

# Exports

## Provided

| Export | Side | Description |
| --- | --- | --- |
| `openDispatch` | client | Opens the Freight Dispatch app, the same function the job station target runs. Does nothing if it is already opening. Takes no arguments and does not check distance. Example below |

```lua
exports.kora_truckerjob:openDispatch()
```

### FFT test hooks

`fft_hooks.lua` (client) is inert unless the convar `fft_kora_hooks` is `true`, for example `setr fft_kora_hooks true`. When enabled it adds:

| Export | Description |
| --- | --- |
| `fftVersion` | Returns the hook protocol version (`1`) |
| `fftAction(action, ...)` | Only usable by the resource named `fft` and only while the player has the state bag `fftSession` set. Supports `dashboard`, a read-only summary (contracts with id, distance and levels; skills, skill points, XP, trucks) built from the dashboard callback |

Anything else returns `false` and a message.

## Used from other resources

| Export | Resource | Side | Use |
| --- | --- | --- | --- |
| `getMetaData`, `setMetaData` | `kora_core` | server | Stores trucker data in the `rep` metadata |
| `getPlayer`, `getPlayerData` | `kora_core` | server | Character check, citizen id for the cooldown |
| `addMoney`, `removeMoney` | `kora_core` | server | Cash payout, bank truck purchase and refund |
| `randomStr`, `randomInt` | `kora_core` | server | Contract id (3 letters plus 3 digits) |
| `addSphereZone`, `removeZone` | `kora_target` | client | Job station and trailer locator eye zones |
| `giveKeys`, `removeKeys` | `Config.KeysResource` | server | Truck keys |
| `SetFuel` | `Config.FuelResource` | client | Starting fuel |
