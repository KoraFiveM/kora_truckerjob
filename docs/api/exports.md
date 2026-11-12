---
title: "Client export"
sidebar_position: 2
---


# Client export

One convenience export to open the dispatch panel from another client resource (for example a different NPC or menu entry point).

Namespace: `exports.kora_truckerjob` · Source: `client/client.lua`

## How it works

Internally identical to selecting the depot's kora_target option.

## Functions

One export.

### `exports.kora_truckerjob:openDispatch()`

Opens the freight dispatch AppShell panel — the same action as targeting the depot NPC/zone.

**Parameters**



**Returns**

- **No return value.**

**Example**

```lua
exports.kora_truckerjob:openDispatch()
```

**Representative console output**

```text
A no-op if the panel is already open or the dashboard request fails (shows an error notification instead).
```

## Limits and related APIs

Client only. Does not bypass any of the server-side checks in the callbacks above.

The server callbacks are listed in [Events and callbacks](../events.md).

## Behaviour notes

`openDispatch` takes no arguments and does not check distance to the depot. It does nothing if the app is already opening.

## FFT test hooks

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
