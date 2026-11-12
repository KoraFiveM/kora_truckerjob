---
title: Configuration
sidebar_position: 8
---

# Configuration

All options are in `config.lua` (a shared script, loaded on client and server). At the end the file calls `Kora.config.adopt(Config)` when available, which registers the table with `kora_lib`; `.gitignore` mentions generated per-server overrides in `config.local.lua`. Check the `kora_lib` documentation for how overrides are applied.

## General

| Option | Default | Description |
| --- | --- | --- |
| `Debug` | `false` | Draws debug for the zones created by the resource |
| `FuelResource` | `'LegacyFuel'` | Resource whose `SetFuel` export is called on the new truck (client) when it is started. Any failure is ignored |
| `JobGenerationTimer` | `2` | Minutes between generated contracts |
| `MaxJobs` | `50` | Size of the contract board |
| `MinStarterJobs` | `3` | Starter contracts (cargo level 1, distance level 1, not expedited) kept available |
| `GuaranteeQualifiedJob` | `true` | Add a starter contract when the player opened the dispatch and nothing qualifies. Only an explicit `false` disables it |
| `ContractCooldown` | `0` | Seconds to wait after a completed contract (0 = off) |
| `CooldownOnAbandon` | `false` | Also start the cooldown after a cancelled or failed contract |
| `GiveKeys` | `true` | Give keys for the truck's plate. Only an explicit `false` disables it |
| `KeysResource` | `'kora_vehiclekeys'` | Resource exporting `giveKeys(source, plate, true)` and `removeKeys(source, plate)` |
| `TimedChanceGenerator` | `15` | Percent chance that a random contract is expedited |
| `XPReward` | `75` | Base XP per completed contract |
| `Multipliers.FragileXPMultiplier` | `1.5` | XP multiplier for cargo level above 1, when on time and undamaged |
| `Multipliers.TimedXPMultiplier` | `1.5` | XP multiplier for expedited contracts, when on time and undamaged |
| `PayPerMeter` | `1.7` | Cash per metre of straight-line distance from the job station |
| `LateDeliveryPenalty` | `10` | Divisor: late payout loses `floor(payout / value)`; 10 is 10 percent |
| `DamagePenaltyThreshold` | `30` | Trailer health percent at or below which the damage penalty applies |
| `DamagePenalty` | `10` | Divisor for the damage penalty, as above |
| `DefaultTruck` | `'hauler'` | Free truck every player owns |
| `Trucks` | see [Truck fleet](./progression.md#truck-fleet) | List of `{ name, label, price }` |

## Return

`Config.Return` (the truck return behaviour):

| Option | Default | Description |
| --- | --- | --- |
| `requireVehicleInZone` | `true` | The truck itself must be near the return point. `false` only requires the player to be in the zone |
| `maxDistance` | `15.0` | Metres from `Config.Coords.TruckReturn` the truck may be, checked on the server (the client pre-check uses it too) |
| `zoneRadius` | `30.0` | Radius of the client zone that shows the return prompts. Keep `maxDistance` smaller than or equal to it |
| `exitPrompt` | `'Exit the vehicle to return the truck'` | Text shown while driving the truck in the zone |
| `awayMessage` | `'Bring the truck to the return point first.'` | Shown in the zone without the truck near the return point |
| `awayMode` | `'textui'` | `'textui'` stays up while in the zone, `'notify'` shows one notification per zone entry, `false` shows nothing |
| `outsideHint` | `true` | Notify when the player leaves the job truck outside the zone |
| `outsideMessage` | `'Return the truck to the depot return point.'` | Text of that hint |
| `returnedMessage` | `'Truck returned to the depot.'` | Notification after a successful return |

## Trailer pickup

`Config.TrailerPickup`:

| Option | Default | Description |
| --- | --- | --- |
| `zoneRadius` | `8.0` | Radius around `Config.Coords.TrailerLocator` where the prompt shows. `0` disables the prompt and zone (eye target only) |
| `allowInVehicle` | `true` | Show the prompt while in a vehicle. `false` is on foot only |
| `key` | `38` | Control id (E) used only when `keybind` is false or empty (per-frame polling) |
| `keybind` | `'E'` | Rebindable key name, registered while inside the zone as `kora_truckerjob_dispatch`. `false` uses `key` |
| `prompt` | `'Press E to dispatch your assigned trailer'` | Prompt text. It is not updated when the keybind changes |
| `targetRadius` | `1.25` | Radius of the `kora_target` sphere at the locator |

## Delivery

`Config.Delivery`:

| Option | Default | Description |
| --- | --- | --- |
| `showMarker` | `true` | Draw the drop-off marker (green aligned, red not) |
| `textUI` | `true` | Show guidance text in the delivery area. Only an explicit `false` hides it |
| `notifyOnArrival` | `true` | Notify on entering the 75 m delivery zone. Only an explicit `false` disables it |
| `detachKey` | `74` | Control id (H), used only when `detachKeybind` is false or empty |
| `detachKeybind` | `'H'` | Rebindable key name `kora_truckerjob_detach`, registered only while the delivery bay is active |
| `checkInterval` | `250` | Milliseconds between parked and attached checks |
| `detachKeyLabel` | `'H'` | Key name inserted for `{key}` in the texts. Not updated when the keybind changes |
| `approachText` | `'Reverse the trailer into the marker'` | Shown until the trailer is lined up |
| `detachText` | `'Press {key} to detach the trailer and deliver'` | Shown when parked but hitched |
| `arrivalMessage` | `'Back the trailer into the marked bay (it turns green when aligned), then detach it with {key}.'` | Arrival notification |

## Lost vehicles

| Option | Default | Description |
| --- | --- | --- |
| `TruckLost.enabled` | `true` | Poll for a deleted truck and close the contract (no penalty) |
| `TruckLost.checkInterval` | `1000` | Milliseconds between checks |
| `TruckLost.message` | `'Your truck is gone. The contract has been closed.'` | Notification |
| `TrailerLost.enabled` | `true` | Poll for a destroyed or deleted trailer and fail the contract |
| `TrailerLost.checkInterval` | `1000` | Milliseconds between checks |
| `TrailerLost.message` | `'Your trailer was destroyed.'` | Notification |

Destroyed vehicles are also detected through the `CEventNetworkVehicleUndrivable` game event regardless of these switches; that path shows a fixed message.

## Coordinates

`Config.Coords`:

| Key | Type | Description |
| --- | --- | --- |
| `JobStation` | `vector4` | Depot: target zone, blip, distance origin for contracts, range checks (15 or 20 m) |
| `TrailerLocator` | `vector3` | Where trailers are dispatched (server checks 12 m) |
| `TruckSpawns` | list of `vector4` | Truck bays (default 4) |
| `TruckReturn` | `vector3` | Return point |
| `TrailerSpawns` | list of `vector4` | Trailer bays (default 20), named "Bay K" plus index |
| `Deliveries` | list of `vector4` | Drop-off points; `w` is the heading the trailer must match (10 degree tolerance) |

The distance level thresholds (1500, 3000, 5000, 7000 m) and the ranges mentioned above are constants in `server.lua`, not config. Deliveries do not have separate configuration per distance level; they are bucketed automatically.

## Cargo types

`Config.DeliveryTypes` is keyed by cargo level 1 to 4 (the number of levels also sets the highest random cargo level; skills cap at 4). Each entry:

| Key | Description |
| --- | --- |
| `trailer` | Trailer model name that is spawned |
| `jobLabels` | List of cargo names; one is chosen at random per contract |
| `image` | File in `html/images/cargo/` shown on the contract card |

An image must also be listed by the manifest `files` glob `html/images/**/*.webp`. The default pools are described in [Contracts](./contracts.md#cargo-types).
