---
title: Contracts
sidebar_position: 6
---

# Contracts

## Generation

Contracts live in server memory only; they are lost on restart (and regenerated).

- At start, `Config.MaxJobs` contracts are generated: `Config.MinStarterJobs` (default 3) starter contracts plus random ones.
- Every `Config.JobGenerationTimer` minutes one new contract is generated. If the board is full, the oldest unaccepted contract is removed first (non-starter contracts are removed before starter ones). If fewer than `Config.MinStarterJobs` untaken starter contracts exist, the new one is a starter.
- When a player opens the dispatch and `Config.GuaranteeQualifiedJob` is not `false`, the server adds a starter contract if no untaken contract matches that player's skills (evicting the oldest if the board is full).
- Completed, failed and cancelled contracts leave the board; the board refills only through the timer.

The board is shared by all players. A taken contract shows as "Taken" to others.

Each random contract has:

| Field | Source |
| --- | --- |
| Delivery point | Random entry of `Config.Coords.Deliveries` |
| Distance | Straight-line distance in metres from `Config.Coords.JobStation` to the delivery point, rounded down |
| Distance level | 1 up to 1500 m, 2 up to 3000 m, 3 up to 5000 m, otherwise 4 (the last step, 7000 m, is also level 4). These thresholds are fixed in `server.lua` |
| Cargo level | Random key of `Config.DeliveryTypes` (1 to 4) |
| Cargo | Random entry for that level: trailer model, image and a random label from `jobLabels` |
| Expedited level | With `Config.TimedChanceGenerator` percent chance a random level 2 to 4, otherwise none |

A starter contract has cargo level 1, no expedited level, and its delivery point is chosen from points in distance level 1 (any point if there are none).

## Qualifying

A player may accept a contract when the distance level, cargo level and, if present, expedited level are each less than or equal to the player's matching skill (Distance, Cargo, Expedited). The app disables **Accept contract** and shows "Locked" otherwise; the server enforces the same rule. See [Skills and progression](./progression.md).

## Deadline

When accepted, the time limit in seconds is:

```text
300 + floor(distance / 1000) * 60 - 45 * expeditedLevel   (minimum 60)
```

The expedited term applies only to expedited contracts. The deadline is stored on the server; the app does not show a countdown.

## Payout and penalties

On a verified delivery the server computes:

```text
payout = floor(distance * Config.PayPerMeter)
```

- **Late** (completed after the deadline): `payout = payout - floor(payout / Config.LateDeliveryPenalty)`.
- **Damaged** (trailer health, on a 0 to 100 scale, at or below `Config.DamagePenaltyThreshold`): `payout = payout - floor(payout / Config.DamagePenalty)`.

Both can apply. With the default value 10 each removes 10 percent; note that the config value is a divisor, so 20 would remove 5 percent, not 20. The payout is added as **cash** (reason `trucker-completed-job`). The "Estimated pay" in the app is `distance * Config.PayPerMeter` without penalties.

## XP

Base XP is `Config.XPReward` (default 75). If the delivery was neither late nor damaged:

- a contract with cargo level above 1 multiplies it by `Config.Multipliers.FragileXPMultiplier`,
- an expedited contract multiplies it by `Config.Multipliers.TimedXPMultiplier`.

Both multipliers can apply. The result is rounded down. Penalties do not subtract XP; they only remove the multipliers. See [Skills and progression](./progression.md) for skill points.

## Cooldown

`Config.ContractCooldown` seconds (0 = off) must pass after a completed contract before another can be accepted; the player gets "Your next contract is available in ..." otherwise. `Config.CooldownOnAbandon` also starts it after a cancelled or failed contract. The cooldown is kept in server memory per character (citizen id) and is cleared on resource restart.

## Cargo types

Default cargo per cargo level, from `Config.DeliveryTypes` (each entry has a trailer model, `jobLabels` and an `image`):

| Level | Trailer models |
| --- | --- |
| 1 | `trailers`, `docktrailer`, `trailers4` |
| 2 | `trailers3`, `trailerlogs`, `trailers2` |
| 3 | `tr2`, `trflat`, `tvtrailer`, `tanker2` |
| 4 | `tanker`, `tr3`, `tr4`, `trailerlarge` |

Cargo images are `html/images/cargo/<image>`; see [Configuration](./configuration.md#cargo-types).
