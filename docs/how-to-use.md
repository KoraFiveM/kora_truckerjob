---
title: "How to use"
sidebar_position: 3
---


# How to use

Players open the dispatch board at the depot, pick a contract their trucker skills qualify for, fetch a truck and its matching trailer from marked bays, drive to the delivery point, park and detach the trailer for payout plus XP, then return the truck (or keep it for the next contract).

## Opening freight dispatch

- An `exports.kora_target` eye-zone at `Config.Coords.JobStation` shows `Open freight dispatch`; selecting it (or calling `exports.kora_truckerjob:openDispatch()`) fetches a snapshot via the `kora_truckerjob:server:dashboardRequested` callback and opens the kora_lib AppShell dispatch panel.
- The panel lists every contract on the board sorted by distance, untaken contracts first and taken ones (including the player's own active contract, badged "Your active job") after them, each showing distance, cargo label/image and any time-limited badge, plus the player's current trucker rep: skill levels, skill points, XP, owned/active trucks.
- On every dashboard request the server runs `ensureQualifyingJob`: if `Config.GuaranteeQualifiedJob` is on (default) and no open contract currently matches the player's skills, it generates a free tier-1 "starter" contract (distance level 1, cargo level 1, no time limit) so a brand-new trucker is never locked out, evicting the oldest unaccepted non-starter job first (any unaccepted job if none) if the pool is already full.

## Job generation

- A background thread seeds `Config.MinStarterJobs` starter contracts plus enough others to reach `Config.MaxJobs` on boot, then every `Config.JobGenerationTimer` minutes adds one more contract (a starter contract if the starter pool has dropped below `Config.MinStarterJobs`), evicting the oldest unaccepted contract first (non-starter contracts before starter ones) if the pool is already at `Config.MaxJobs`.
- Each contract's cargo and delivery point are chosen randomly: cargo level 1–4 picks one of `Config.DeliveryTypes[level]`'s trailer/label sets, and the delivery coordinates are a random entry from `Config.Coords.Deliveries`, distance-bucketed into a distance level (1500/3000/5000/7000 m thresholds) that gates who may accept it.
- `Config.TimedChanceGenerator` percent of newly generated non-starter contracts also get a random time-skill requirement (level 2–4), shortening the delivery deadline but paying an XP multiplier if met.

## Accepting and dispatching

- Accepting (`kora_truckerjob:server:jobAccepted`) requires being within 15 m of the depot, having no other active contract, having no active `Config.ContractCooldown` remaining, and meeting the contract's distance/cargo/time skill requirements. The deadline is `300 + floor(distance / 1000) * 60` seconds, reduced by `45 * timeLevel` seconds for a timed contract (floored to a 60 second minimum).
- The truck is requested separately (`kora_truckerjob:server:vehicleRequested`, kind `'truck'`): the player must be within 20 m of the depot and pick a free bay from `Config.Coords.TruckSpawns`; the server spawns the player's currently selected owned truck (`trucker.activeTruck`, from `Config.Trucks`) with a plate derived from the job id, and issues keys through `Config.KeysResource` unless `Config.GiveKeys` is false.
- The trailer is requested the same way (kind `'trailer'`) from `Config.Coords.TrailerLocator`, within 12 m, picking a free bay from `Config.Coords.TrailerSpawns`; its model is the one the contract's cargo entry specified. `Config.TrailerPickup` also drives an in-world prompt/keybind (`E` by default) at the locator so the player does not have to open the dispatch panel again just to summon the trailer.
- A player may only have one truck and one trailer in flight at a time; requesting again while one already exists from this session is refused.

## Delivery

- A marker and, with `Config.Delivery.textUI`, an on-screen prompt guide the driver into the delivery bay; the marker turns green once the trailer is aligned (`Config.Delivery.checkInterval` polling). Pressing the detach key (`Config.Delivery.detachKeybind`, default `H`) while parked and still hitched delivers the trailer.
- The server (`kora_truckerjob:server:jobCompleted`, `successful = true`) independently re-verifies the trailer by its network id, that it is detached, within 5 m of the contract's coordinates, and within 10° of the expected heading — a client claiming success with the trailer in the wrong spot is rejected.
- Payout is `floor(distance * Config.PayPerMeter)` cash, reduced by `floor(payout / Config.LateDeliveryPenalty)` if delivered after the deadline and by `floor(payout / Config.DamagePenalty)` if the trailer's health is at or below `Config.DamagePenaltyThreshold` percent (both penalties can apply together; the config values are divisors, so the default 10 removes 10 percent but 20 would remove 5 percent). XP is `Config.XPReward`, multiplied by `Config.Multipliers.FragileXPMultiplier` for cargo level > 1 and/or `Config.Multipliers.TimedXPMultiplier` for a timed contract — but only when delivered on time and undamaged.
- Every 1000 XP milestone crossed grants one trucker skill point (`floor(XP / 1000)` recalculated and diffed against the previous value), spendable with `kora_truckerjob:server:skillUpgraded`. A successful delivery also starts `Config.ContractCooldown` (0 = disabled by default).

## Abandoning or losing the job

- Calling completion with `successful = false` (abandon), the trailer being destroyed (`gameEventTriggered` `CEventNetworkVehicleUndrivable` on the client, `Config.TrailerLost`), or the truck going missing (`Config.TruckLost`, a periodic existence check) all close the contract with no payout and delete the trailer; `Config.CooldownOnAbandon` (default false) decides whether the contract cooldown still applies in these cases.
- A truck that is wrecked or missing can always be "returned" for cleanup even outside the return zone (`vehicleIsWrecked`) — there is nothing left to bring back.
- Disconnecting mid-job (`playerDropped`) immediately removes the player's contract from the board (it is not returned to the pool) and deletes any spawned truck/trailer and keys.

## Returning the truck

- A zone around `Config.Coords.TruckReturn` (radius `Config.Return.zoneRadius`) shows a prompt while the player is driving the job truck inside it. `Config.Return.requireVehicleInZone` (default true) means the truck itself, not just the player, must be within `Config.Return.maxDistance` of the return point — the player cannot walk into the zone alone and hand back a truck left elsewhere.
- Exiting the truck outside the return zone shows a one-time hint (`Config.Return.outsideHint`/`outsideMessage`) when the player leaves the job truck outside the return zone.
- Returning deletes the truck entity and revokes its keys. The contract itself is only completed by delivering the trailer — returning the truck is a separate wrap-up step that does not by itself pay out. It is not enforced: a player who still has the truck keeps using it for the next contract ("Continue using your current truck.").

## Trucker skills, trucks and rep

This job keeps its own levelling system, stored per character as kora_core metadata `rep.trucker` — it is unrelated to the kora_skills resource.

- Three skills, each leveled 1–4: `distance` (which distance-bucketed contracts you may accept), `cargo` (which cargo levels you may haul) and `time` (which timed-contract tiers you may accept). A new character starts at level 1 in all three.
- Skill points (from XP milestones) are spent one at a time with `kora_truckerjob:server:skillUpgraded(skill)`, capped at level 4 per skill.
- `Config.Trucks` lists purchasable trucks with a price (the default `hauler` is free and owned from the start). `kora_truckerjob:server:truckPurchased` deducts bank money and, if saving the purchase fails, refunds it automatically. `kora_truckerjob:server:truckSelected` switches which owned truck is dispatched next; both require being at the depot.

## Step-by-step journey (detail)

The same journey in order, with the exact distances, prompts and server checks.

### 1. Open the dispatch

At the Freight Depot job station (`Config.Coords.JobStation`) use the `kora_target` option **Open freight dispatch**. The depot blip ("Freight Depot", sprite 477) is visible to everyone, no job is required. See [Freight Dispatch app](./ui.md).

### 2. Accept a contract

In the **Contracts** tab press **Accept contract** on an available contract. The server checks that:

- the player is within 15 m of the job station,
- the contract still exists and is not taken,
- the player has no active contract,
- the contract cooldown (`Config.ContractCooldown`) is over,
- the player's skill levels qualify (see [Contracts](./contracts.md#qualifying)).

The server reserves the contract for the player and sets a deadline. The app closes with "Contract accepted."

### 3. Truck

If the player does not already have a job truck, the client picks the first free bay in `Config.Coords.TruckSpawns` (no vehicle within 3 m) and asks the server for the truck. The server requires the player to be within 20 m of the job station, spawns the player's selected truck (see [Truck fleet](./progression.md#truck-fleet)) with the plate `TRK` plus the contract id, gives keys (if `Config.GiveKeys`) and the client sets random starting fuel (50 to 70) if the fuel resource is running. If the player still has the truck from a previous contract, it is reused ("Continue using your current truck.").

If no bay is free or the spawn fails, the contract is released again.

### 4. Trailer

A route to the trailer locator (`Config.Coords.TrailerLocator`) is set. Inside `Config.TrailerPickup.zoneRadius` a prompt ("Press E to dispatch your assigned trailer") appears and the rebindable key (default `E`) dispatches the trailer. The eye-target option **Dispatch assigned trailer** does the same. The server requires the player to be within 12 m of the locator and spawns the trailer model assigned to the contract in the first free bay of `Config.Coords.TrailerSpawns`. The player is told "Your trailer is in Bay K" plus the bay number. One trailer per contract.

### 5. Deliver

The route now points to the delivery coordinates. Within 75 m of the drop-off the client:

- notifies the player (`Config.Delivery.arrivalMessage`),
- draws a marker (green when the trailer is aligned, red otherwise),
- shows guidance text.

The trailer counts as parked when it is within 5 m of the drop-off point and within 10 degrees of its heading. Once parked, press the detach key (default `H`) to unhitch. When the trailer is parked and no longer attached, the client asks the server to complete the contract.

The server re-verifies everything: the trailer is the one it spawned, the player is within 25 m, the trailer is not attached and is within 5 m and 10 degrees. Then it pays cash and awards XP (see [Contracts](./contracts.md#payout-and-penalties)). The trailer stays at the drop-off until the player leaves the 75 m zone, which deletes it.

### 6. Return the truck

After completing or abandoning, a "Truck Return" blip (sprite 477, green) and a zone around `Config.Coords.TruckReturn` appear. Exit the truck inside the zone while the truck is within `Config.Return.maxDistance` of the return point. The server deletes the truck, removes the keys and the client notifies "Truck returned to the depot.". A truck that no longer exists or is wrecked can always be handed back. With `Config.Return.requireVehicleInZone = false` the position of the truck is not checked.

The truck can also simply be kept and used for the next contract.

### Ending a contract early

- **Cancel** - the **Cancel active contract** button in the app (with confirmation). No pay or XP; the trailer is deleted and the truck must still be returned.
- **Truck lost** - if the truck is deleted or becomes undriveable, the client reports it and closes the contract (`Config.TruckLost`).
- **Trailer lost** - if the trailer is destroyed, deleted or dead, the contract is closed as failed (`Config.TrailerLost`).
- **Disconnect** - the server removes the player's contract (it is not returned to the board), deletes the truck and trailer and removes keys.
- **Resource stop** - all spawned trucks and trailers are deleted.

Failed or cancelled contracts are removed from the board. They start the cooldown only if `Config.CooldownOnAbandon` is `true`.
