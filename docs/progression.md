---
title: Skills and progression
sidebar_position: 7
---

# Skills and progression

Progress is stored per character in `kora_core` metadata (see [Data storage](./database.md)).

## XP and skill points

Every completed contract adds XP (see [Contracts](./contracts.md#xp)). Each time total XP crosses a multiple of 1000, the player gains one skill point. The Skills tab shows total XP, unspent points and progress toward the next point.

## Skills

| Skill | App label | Unlocks |
| --- | --- | --- |
| `distance` | Distance | Contracts with a higher distance level (longer routes) |
| `cargo` | Cargo | Contracts with a higher cargo level (fragile and specialist loads) |
| `time` | Expedited | Contracts with an expedited level |

All skills start at level 1 and are capped at level 4. **Spend one skill point** raises one skill by one level and costs one skill point. Level 1 has no restriction for distance and cargo; expedited contracts need at least expedited level 2 (their level is 2 to 4).

## Truck fleet

`Config.Trucks` lists the trucks (`name` is the vehicle model, `label` a fallback display name, `price` in dollars). The label shown is the `kora_core` shared vehicle name for the model when present, otherwise `label`.

| Truck | Price |
| --- | --- |
| `hauler` (default, `Config.DefaultTruck`) | 0 |
| `phantom` | 25000 |
| `packer` | 50000 |
| `phantom3` | 100000 |

- The `Config.DefaultTruck` is always owned and selected for new players.
- **Purchase** charges the price from the player's **bank** (reason `trucker-purchase-truck`) and requires the player to be within 15 m of the job station. The charge is refunded if the data cannot be saved. Trucks with price 0 cannot be purchased, and owned trucks cannot be bought again.
- **Use this truck** selects an owned truck; it is dispatched for the next contract. Selecting also requires being within 15 m of the job station.
- The top speed shown in the app is the model's estimated maximum speed in mph.
- Truck images are `html/images/trucks/<name>.webp`.

Invalid or missing stored values are repaired on every read (skills to 1, an unknown active truck to the default, and so on).
