# kora_truckerjob

A server-authoritative freight job for the qbcore2 stack. Players accept generated contracts, collect a depot truck and assigned trailer, deliver cargo, earn XP, upgrade skills, and build a personal truck fleet.

## Features

- Random job generation with different skill levels and cargo types.
- Timed and fragile job types with XP multipliers.
- Penalties for late deliveries and damaged cargo.
- Shared kora_lib AppShell for contracts, skills, and the truck fleet.
- kora_lib notifications, text prompts, callbacks, and zones.
- Modern kora_core metadata, money, and shared-vehicle APIs.
- Server-owned job vehicles and server-verified delivery payouts.
- Truck return system with kora_vehiclekeys integration.
- Configurable job settings.

## Installation

Start these resources first, in order:

```cfg
ensure kora_theme
ensure kora_lib
ensure kora_core
ensure kora_target
ensure kora_vehiclekeys
ensure kora_truckerjob
```

The configured fuel resource is optional. When it is running, newly dispatched trucks receive a randomized starting fuel level.

## Configuration

The script can be configured through the `config.lua` file. Below are some of the key configuration options:

- `FuelResource`: The fuel resource to use.
- `JobGenerationTimer`: How often a job is generated in minutes.
- `MaxJobs`: Maximum number of jobs that can be generated.
- `TimedChanceGenerator`: Chance for a timed job to be generated.
- `XPReward`: XP reward for completing a job.
- `Multipliers`: XP multipliers for fragile and timed jobs.
- `PayPerMeter`: Payment per meter traveled.
- `LateDeliveryPenalty`: Penalty percentage for late deliveries.
- `DamagePenaltyThreshold`: Health threshold for damage penalties.
- `DamagePenalty`: Penalty percentage for damaged cargo.
- `DefaultTruck`: Default truck for players to use.
- `Trucks`: List of available trucks and their prices.
- `DeliveryTypes`: Cargo and trailer choices grouped by required cargo-skill level.

## License
```
QBCore Framework
Copyright (C) 2021 Joshua Eger

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>
```
