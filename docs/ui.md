---
title: Freight Dispatch app
sidebar_position: 9
---

# Freight Dispatch app

## Opening

Use the `kora_target` option **Open freight dispatch** on the sphere at `Config.Coords.JobStation` (radius 0.75, distance 2.5). The client also exposes the `openDispatch` export (see [Exports](./api/exports.md)). The zone is re-registered when `kora_target` starts. The app id is `kora_truckerjob:dispatch`; its title is "Freight Dispatch".

The app data is loaded from the server when opened (rate limited to 5 requests per 5 seconds). If it cannot be loaded, a notification is shown.

## Tabs

**Contracts** - searchable card list (12 per page, search by cargo or contract id). Each card shows cargo label, image, contract id, distance in km, estimated pay, cargo level and the expedited level if any. Badges: "Available", "Locked" (skills too low), "Taken", "Your active job". **Accept contract** is disabled when locked, taken or when the player already has an active contract. While a contract is active the tab shows **Cancel active contract** (with confirmation, no pay or XP).

**Skills** - total XP, unspent skill points, progress toward the next skill point (per 1000 XP) and one card per skill with a **Spend one skill point** button. See [Skills and progression](./progression.md).

**Trucks** - the fleet cards with price, top speed, image and badge (Selected, Owned, For sale). Buttons: **Purchase for $...** (confirmation, bank funds) and **Use this truck**.

## World elements

| Element | Details |
| --- | --- |
| Depot blip | "Freight Depot", sprite 477, colour 2, short range, category "Trucking" |
| Truck return blip | "Truck Return", sprite 477, colour 2, visible after a contract until the truck is returned |
| Route blip | Yellow route to the trailer locator, then to the delivery point |
| Trailer blip | Sprite 479 on the dispatched trailer |
| Trailer locator | Sphere zone with text prompt plus eye-target option "Dispatch assigned trailer" |
| Drop-off | 75 m zone, 3 x 3 x 5 marker (green parked correctly, red not) |

## Prompts and keybinds

| Keybind name | Default | When registered |
| --- | --- | --- |
| `kora_truckerjob_dispatch` | `E` | While inside the trailer locator zone |
| `kora_truckerjob_detach` | `H` | While the delivery zone is active |

Players can rebind them in the game key binding settings. If the keybind options are `false` the resource polls `Config.TrailerPickup.key` and `Config.Delivery.detachKey` per frame instead. See [Configuration](./configuration.md).

Texts are English literals in the code and config; the resource has no locale files.
