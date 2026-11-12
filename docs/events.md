---
title: Events and callbacks
sidebar_position: 10
---

# Events and callbacks

The resource registers no net events and no commands. Client and server talk through `kora_lib` callbacks. They are internal to the Freight Dispatch app and are not a public API; they are listed here for developers and testers.

## Server callbacks

Registered with `Kora.callback.register`, called with `Kora.callback.trigger(name, ...)`. All return `ok, resultOrError`, except where noted.

| Callback | Arguments | Rate limit | Behaviour |
| --- | --- | --- | --- |
| `kora_truckerjob:server:dashboardRequested` | none | 5 per 5 s | Returns `{ jobs, activeJobId, rep }` (the board and the player's trucker data). Needs a loaded character. May add a starter contract |
| `kora_truckerjob:server:jobAccepted` | `jobId` | 3 per 5 s | Reserves the contract. Near the job station (15 m), qualifies, no active job, cooldown over. Returns the contract |
| `kora_truckerjob:server:vehicleRequested` | `kind` (`'truck'` or `'trailer'`), `jobId`, `spawnId` | 4 per 10 s | Spawns the truck (near station, 20 m) or trailer (near locator, 12 m) in the bay with that index. Returns the network id |
| `kora_truckerjob:server:jobCompleted` | `jobId`, `successful`, `trailerNetId` | 3 per 10 s | `false` cancels or fails the contract. `true` verifies the trailer and position, then pays and awards XP. Returns `{ payout, xp, late, damaged, skillPointsGained }` or `{ failed = true }` |
| `kora_truckerjob:server:skillUpgraded` | `skill` (`distance`, `cargo`, `time`) | 4 per 5 s | Spends one skill point. Returns the updated trucker data |
| `kora_truckerjob:server:truckPurchased` | `spawnName` | 2 per 5 s | Buys a truck with bank money, near the station (15 m). Returns the updated data |
| `kora_truckerjob:server:truckSelected` | `spawnName` | 3 per 5 s | Selects an owned truck, near the station (15 m) |
| `kora_truckerjob:server:vehicleReturned` | `kind`, `netId` | 4 per 5 s | Deletes the player's tracked truck or trailer. A truck must be wrecked, gone or near the return point. Truck keys are removed. Returns `true`, or `false` plus a message |

The server only deletes vehicles it has tracked for that player and whose network id matches.

## Game and framework events listened

| Event | Side | Use |
| --- | --- | --- |
| `playerDropped` | server | Removes the player's contract, deletes the truck and trailer, removes keys |
| `onResourceStop` | server | Deletes all tracked trucks and trailers |
| `onResourceStop` | client | Removes the route, trailer and return blips |
| `onClientResourceStart` | client | Re-registers the job station target when `kora_target` starts |
| `gameEventTriggered` (`CEventNetworkVehicleUndrivable`) | client | Closes the contract when the trailer or truck becomes undriveable |

No events are emitted for other resources to listen to.
