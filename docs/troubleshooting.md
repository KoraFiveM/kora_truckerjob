---
title: Troubleshooting
sidebar_position: 13
---

# Troubleshooting

## "Vehicle keys could not be issued."

`Config.GiveKeys` is on and the call to `giveKeys` on `Config.KeysResource` failed or returned something other than `true`. Start `kora_vehiclekeys` (it is not a declared dependency), fix `Config.KeysResource`, or set `Config.GiveKeys = false`. The truck that was spawned is deleted.

## "That bay is no longer available." / "There are no available truck bays."

A vehicle is parked within 3 m of the bay. Remove it or add bays to `Config.Coords.TruckSpawns` / `TrailerSpawns`.

## No contracts qualify

New players have all skills at 1, so they can take only contracts with distance level 1, cargo level 1 and no expedited level. With `Config.GuaranteeQualifiedJob` and `Config.MinStarterJobs` the board keeps such contracts. Contracts are in memory only and refill at one per `Config.JobGenerationTimer` minutes after a restart.

## "Park the trailer fully inside the delivery marker."

The server needs the trailer within 5 m of the drop-off point, within 10 degrees of its heading and detached. The marker turns green only when the client check passes, so this message means the position changed or was borderline.

## "The assigned trailer could not be verified."

The trailer is not the one the server spawned for the player (or no longer exists). The player must deliver the dispatched trailer.

## Payout is lower than the estimate

The app estimate is `distance * PayPerMeter`. Late and damaged deliveries are reduced (see [Contracts](./contracts.md#payout-and-penalties)). `LateDeliveryPenalty` and `DamagePenalty` are divisors.

## A contract disappeared after disconnecting

A disconnect removes the player's contract and deletes the truck and trailer. This is by design.

## The truck cannot be returned

The truck must be within `Config.Return.maxDistance` of `Config.Coords.TruckReturn` when the player exits it inside the return zone. A wrecked or deleted truck can always be handed back. Check `Config.Return` in [Configuration](./configuration.md).

## Prompts show the wrong key

`Config.TrailerPickup.prompt` and `Config.Delivery.detachKeyLabel` are fixed texts. If you change `keybind` or `detachKeybind`, update them as well; players can also rebind the keys.

## Starting fuel is not applied

The resource in `Config.FuelResource` must be `started` and export `SetFuel`. Otherwise it is silently skipped.
