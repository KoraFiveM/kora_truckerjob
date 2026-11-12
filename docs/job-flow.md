---
title: Job flow
sidebar_position: 3
---

# Job flow

## 1. Open the dispatch

At the Freight Depot job station (`Config.Coords.JobStation`) use the `kora_target` option **Open freight dispatch**. The depot blip ("Freight Depot", sprite 477) is visible to everyone, no job is required. See [Freight Dispatch app](./ui.md).

## 2. Accept a contract

In the **Contracts** tab press **Accept contract** on an available contract. The server checks that:

- the player is within 15 m of the job station,
- the contract still exists and is not taken,
- the player has no active contract,
- the contract cooldown (`Config.ContractCooldown`) is over,
- the player's skill levels qualify (see [Contracts](./contracts.md#qualifying)).

The server reserves the contract for the player and sets a deadline. The app closes with "Contract accepted."

## 3. Truck

If the player does not already have a job truck, the client picks the first free bay in `Config.Coords.TruckSpawns` (no vehicle within 3 m) and asks the server for the truck. The server requires the player to be within 20 m of the job station, spawns the player's selected truck (see [Truck fleet](./progression.md#truck-fleet)) with the plate `TRK` plus the contract id, gives keys (if `Config.GiveKeys`) and the client sets random starting fuel (50 to 70) if the fuel resource is running. If the player still has the truck from a previous contract, it is reused ("Continue using your current truck.").

If no bay is free or the spawn fails, the contract is released again.

## 4. Trailer

A route to the trailer locator (`Config.Coords.TrailerLocator`) is set. Inside `Config.TrailerPickup.zoneRadius` a prompt ("Press E to dispatch your assigned trailer") appears and the rebindable key (default `E`) dispatches the trailer. The eye-target option **Dispatch assigned trailer** does the same. The server requires the player to be within 12 m of the locator and spawns the trailer model assigned to the contract in the first free bay of `Config.Coords.TrailerSpawns`. The player is told "Your trailer is in Bay K" plus the bay number. One trailer per contract.

## 5. Deliver

The route now points to the delivery coordinates. Within 75 m of the drop-off the client:

- notifies the player (`Config.Delivery.arrivalMessage`),
- draws a marker (green when the trailer is aligned, red otherwise),
- shows guidance text.

The trailer counts as parked when it is within 5 m of the drop-off point and within 10 degrees of its heading. Once parked, press the detach key (default `H`) to unhitch. When the trailer is parked and no longer attached, the client asks the server to complete the contract.

The server re-verifies everything: the trailer is the one it spawned, the player is within 25 m, the trailer is not attached and is within 5 m and 10 degrees. Then it pays cash and awards XP (see [Contracts](./contracts.md#payout-and-penalties)). The trailer stays at the drop-off until the player leaves the 75 m zone, which deletes it.

## 6. Return the truck

After completing or abandoning, a "Truck Return" blip (sprite 477, green) and a zone around `Config.Coords.TruckReturn` appear. Exit the truck inside the zone while the truck is within `Config.Return.maxDistance` of the return point. The server deletes the truck, removes the keys and the client notifies "Truck returned to the depot.". A truck that no longer exists or is wrecked can always be handed back. With `Config.Return.requireVehicleInZone = false` the position of the truck is not checked.

The truck can also simply be kept and used for the next contract.

## Ending a contract early

- **Cancel** - the **Cancel active contract** button in the app (with confirmation). No pay or XP; the trailer is deleted and the truck must still be returned.
- **Truck lost** - if the truck is deleted or becomes undriveable, the client reports it and closes the contract (`Config.TruckLost`).
- **Trailer lost** - if the trailer is destroyed, deleted or dead, the contract is closed as failed (`Config.TrailerLost`).
- **Disconnect** - the server removes the player's contract (it is not returned to the board), deletes the truck and trailer and removes keys.
- **Resource stop** - all spawned trucks and trailers are deleted.

Failed or cancelled contracts are removed from the board. They start the cooldown only if `Config.CooldownOnAbandon` is `true`.
