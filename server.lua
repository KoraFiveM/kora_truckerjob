local jobs = {}
local jobCount = 0
local spawnedVehicles = {}
local cooldowns = {} -- [citizenid or source] = os.time() the player may accept the next contract

local skillDistances = { 1500, 3000, 5000, 7000 }

local function isInteger(value)
    return type(value) == 'number' and value % 1 == 0
end

local function coordsTable(coords)
    return { x = coords.x, y = coords.y, z = coords.z, w = coords.w or 0.0 }
end

local function playerIsNear(source, coords, maximumDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z)) <= maximumDistance
end

local function truckDefinition(spawnName)
    if type(spawnName) ~= 'string' then return nil end
    for _, truck in ipairs(Config.Trucks) do
        if truck.name == spawnName then return truck end
    end
end

local function normaliseTruckerRep(source)
    local rep = exports.kora_core:getMetaData(source, 'rep') or {}
    local trucker = type(rep.trucker) == 'table' and rep.trucker or {}
    local skills = type(trucker.skills) == 'table' and trucker.skills or {}
    local changed = rep.trucker ~= trucker or trucker.skills ~= skills

    for _, skill in ipairs({ 'distance', 'cargo', 'time' }) do
        local level = tonumber(skills[skill])
        if not level or level % 1 ~= 0 or level < 1 or level > 4 then
            skills[skill] = 1
            changed = true
        elseif skills[skill] ~= level then
            skills[skill] = level
            changed = true
        end
    end

    if type(trucker.trucks) ~= 'table' then
        trucker.trucks = {}
        changed = true
    end
    if type(trucker.activeTruck) ~= 'string' then
        trucker.activeTruck = Config.DefaultTruck
        changed = true
    end
    if not isInteger(trucker.skillPoints) or trucker.skillPoints < 0 then
        trucker.skillPoints = 0
        changed = true
    end
    if type(trucker.XP) ~= 'number' or trucker.XP < 0 then
        trucker.XP = 0
        changed = true
    end

    trucker.skills = skills
    if not trucker.trucks[Config.DefaultTruck] then
        trucker.trucks[Config.DefaultTruck] = true
        changed = true
    end
    if not truckDefinition(trucker.activeTruck) or not trucker.trucks[trucker.activeTruck] then
        trucker.activeTruck = Config.DefaultTruck
        changed = true
    end
    rep.trucker = trucker

    if changed then exports.kora_core:setMetaData(source, 'rep', rep) end
    return rep, trucker
end

local function setTruckerRep(source, rep, trucker)
    rep.trucker = trucker
    return exports.kora_core:setMetaData(source, 'rep', rep)
end

local function clientJob(id, job)
    return {
        id = id,
        coords = coordsTable(job.coords),
        distance = job.distance,
        distanceLevel = job.distanceLevel,
        cargo = job.cargo,
        image = job.image,
        cargoLevel = job.cargoLevel,
        timeLevel = job.timeLevel,
        active = job.active ~= false,
        deadline = job.deadline,
    }
end

local function activeJobFor(source)
    for id, job in pairs(jobs) do
        if job.active == source then return id, job end
    end
end

local function jobsForClient(source)
    local result = {}
    local activeJobId = activeJobFor(source)
    for id, job in pairs(jobs) do result[#result + 1] = clientJob(id, job) end
    table.sort(result, function(left, right)
        if left.active ~= right.active then return not left.active end
        if left.distance ~= right.distance then return left.distance < right.distance end
        return left.id < right.id
    end)
    return result, activeJobId
end

local function jobDistanceLevel(distance)
    for level = 1, #skillDistances do
        if distance <= skillDistances[level] then return level end
    end
    return #skillDistances
end

local function deliveryDistance(coords)
    local station = Config.Coords.JobStation
    return math.floor(#(vector3(coords.x, coords.y, coords.z) - vector3(station.x, station.y, station.z)))
end

local deliveriesByLevel

local function deliveryPool(level)
    if not deliveriesByLevel then
        deliveriesByLevel = {}
        for _, coords in ipairs(Config.Coords.Deliveries) do
            local bucket = jobDistanceLevel(deliveryDistance(coords))
            deliveriesByLevel[bucket] = deliveriesByLevel[bucket] or {}
            local list = deliveriesByLevel[bucket]
            list[#list + 1] = coords
        end
    end

    local pool = deliveriesByLevel[level]
    if not pool or #pool == 0 then return Config.Coords.Deliveries end
    return pool
end

---@param job table
---@return boolean -- takeable by a trucker with every skill still at level 1
local function isStarterJob(job)
    return job.distanceLevel == 1 and job.cargoLevel == 1 and not job.timeLevel
end

local function starterJobCount()
    local count = 0
    for _, job in pairs(jobs) do
        if not job.active and isStarterJob(job) then count = count + 1 end
    end
    return count
end

---Pure: can a trucker with these skill levels take this job?
---@param job table
---@param skills table
---@return boolean
local function jobQualifies(job, skills)
    if job.distanceLevel > skills.distance then return false end
    if job.cargoLevel > skills.cargo then return false end
    if job.timeLevel and job.timeLevel > skills.time then return false end
    return true
end

local function hasQualifyingJob(skills)
    for _, job in pairs(jobs) do
        if not job.active and jobQualifies(job, skills) then return true end
    end
    return false
end

---Pure: seconds left of a cooldown, 0 when it is over or never started.
---@param expiresAt? integer
---@param now integer
---@return integer
local function cooldownRemaining(expiresAt, now)
    if not expiresAt or expiresAt <= now then return 0 end
    return expiresAt - now
end

local function formatDuration(seconds)
    if seconds >= 60 then return Kora.lang('Format.minutes_seconds', seconds // 60, seconds % 60) end
    return Kora.lang('Format.seconds', seconds)
end

local function cooldownKey(source)
    return exports.kora_core:getPlayerData(source, { 'citizenid' }) or source
end

local function startCooldown(source)
    local seconds = tonumber(Config.ContractCooldown) or 0
    if seconds > 0 then cooldowns[cooldownKey(source)] = os.time() + seconds end
end

---@param starter? boolean -- force a job every trucker can take
local function generateJob(starter)
    local pool = starter and deliveryPool(1) or Config.Coords.Deliveries
    local deliveryCoords = pool[math.random(1, #pool)]
    local cargoLevel = starter and 1 or math.random(1, #Config.DeliveryTypes)
    local cargoOptions = Config.DeliveryTypes[cargoLevel]
    local cargo = cargoOptions[math.random(1, #cargoOptions)]
    local distance = deliveryDistance(deliveryCoords)
    local id

    repeat
        id = exports.kora_core:randomStr(3) .. exports.kora_core:randomInt(3)
    until not jobs[id]

    jobs[id] = {
        coords = deliveryCoords,
        distance = distance,
        distanceLevel = jobDistanceLevel(distance),
        cargo = {
            label = cargo.jobLabels[math.random(1, #cargo.jobLabels)],
            trailer = cargo.trailer,
        },
        image = cargo.image,
        cargoLevel = cargoLevel,
        timeLevel = not starter and math.random(1, 100) <= Config.TimedChanceGenerator
            and math.random(2, 4) or nil,
        created = os.time(),
        active = false,
    }
    jobCount = jobCount + 1
end

local function evictOldestJob()
    local oldestId, oldest, oldestOtherId, oldestOther
    for id, job in pairs(jobs) do
        if not job.active then
            if not oldest or job.created < oldest.created then oldestId, oldest = id, job end
            if not isStarterJob(job) and (not oldestOther or job.created < oldestOther.created) then
                oldestOtherId, oldestOther = id, job
            end
        end
    end

    local id = oldestOtherId or oldestId
    if not id then return false end
    jobs[id] = nil
    jobCount = jobCount - 1
    return true
end

---Makes sure a trucker's skills can take at least one open contract (tier 1 jobs need no skills).
---@param skills table
local function ensureQualifyingJob(skills)
    if Config.GuaranteeQualifiedJob == false or hasQualifyingJob(skills) then return end
    if jobCount >= Config.MaxJobs and not evictOldestJob() then return end
    generateJob(true)
end

local function deleteEntity(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function keysResource()
    return Config.KeysResource or 'kora_vehiclekeys'
end

local function giveTruckKeys(source, plate)
    if Config.GiveKeys == false then return true end
    local ok, given = pcall(function() return exports[keysResource()]:giveKeys(source, plate, true) end)
    return ok and given == true
end

local function removeTruckKeys(source, state)
    if Config.GiveKeys == false or not state.plate then return end
    pcall(function() exports[keysResource()]:removeKeys(source, state.plate) end)
    state.plate = nil
end

local function vehicleAtSpawn(coords)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and #(GetEntityCoords(vehicle) - vector3(coords.x, coords.y, coords.z)) < 3.0 then
            return true
        end
    end
    return false
end

local function spawnVehicle(source, model, vehicleType, coords, plate)
    if vehicleAtSpawn(coords) then return nil, Kora.lang('Error.bay_unavailable') end

    local entity = CreateVehicleServerSetter(joaat(model), vehicleType, coords.x, coords.y, coords.z, coords.w)
    local attempts = 0
    while entity and entity ~= 0 and not DoesEntityExist(entity) and attempts < 100 do
        Wait(0)
        attempts = attempts + 1
    end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil, Kora.lang('Error.vehicle_create_failed') end

    SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(source))
    if plate then SetVehicleNumberPlateText(entity, plate) end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    attempts = 0
    while (not netId or netId == 0) and attempts < 100 do
        Wait(0)
        attempts = attempts + 1
        netId = NetworkGetNetworkIdFromEntity(entity)
    end
    if not netId or netId == 0 then
        DeleteEntity(entity)
        return nil, Kora.lang('Error.vehicle_network_failed')
    end
    return entity, netId
end

local function headingDifference(left, right)
    return math.abs((left - right + 180.0) % 360.0 - 180.0)
end

CreateThread(function()
    local starters = math.min(Config.MinStarterJobs, Config.MaxJobs)
    for _ = 1, starters do generateJob(true) end
    for _ = 1, Config.MaxJobs - starters do generateJob() end

    while true do
        Wait(Config.JobGenerationTimer * 60000)
        local starter = starterJobCount() < Config.MinStarterJobs
        if jobCount < Config.MaxJobs or evictOldestJob() then generateJob(starter) end
    end
end)

Kora.callback.register('kora_truckerjob:server:dashboardRequested', function(source)
    if not exports.kora_core:getPlayer(source) then return nil, Kora.lang('Error.character_unavailable') end
    local _, trucker = normaliseTruckerRep(source)
    ensureQualifyingJob(trucker.skills)
    local availableJobs, activeJobId = jobsForClient(source)
    return { jobs = availableJobs, activeJobId = activeJobId, rep = trucker }
end, { rateLimit = { max = 5, window = 5000 } })

Kora.callback.register('kora_truckerjob:server:jobAccepted', function(source, jobId)
    if type(jobId) ~= 'string' then return false, Kora.lang('Error.invalid_job') end
    if not playerIsNear(source, Config.Coords.JobStation, 15.0) then return false, Kora.lang('Error.too_far_depot') end

    local job = jobs[jobId]
    if not job then return false, Kora.lang('Error.job_unavailable') end
    if job.active then return false, Kora.lang('Error.job_taken') end
    if activeJobFor(source) then return false, Kora.lang('Error.active_job_exists') end

    local remaining = cooldownRemaining(cooldowns[cooldownKey(source)], os.time())
    if remaining > 0 then
        local message = Kora.lang('Notify.contract_cooldown', formatDuration(remaining))
        Kora.notify.send(source, { title = Kora.lang('Title.trucking'), message = message, type = 'error' })
        return false, message
    end

    local _, trucker = normaliseTruckerRep(source)
    if job.distanceLevel > trucker.skills.distance then return false, Kora.lang('Error.distance_skill_required') end
    if job.cargoLevel > trucker.skills.cargo then return false, Kora.lang('Error.cargo_skill_required') end
    if job.timeLevel and job.timeLevel > trucker.skills.time then return false, Kora.lang('Error.time_skill_required') end

    job.active = source
    local duration = 300 + math.floor(job.distance / 1000) * 60
    if job.timeLevel then duration = duration - 45 * job.timeLevel end
    job.deadline = os.time() + math.max(60, duration)
    spawnedVehicles[source] = spawnedVehicles[source] or {}
    spawnedVehicles[source].jobId = jobId
    return true, clientJob(jobId, job)
end, { rateLimit = { max = 3, window = 5000 } })

Kora.callback.register('kora_truckerjob:server:vehicleRequested', function(source, kind, jobId, spawnId)
    if kind ~= 'truck' and kind ~= 'trailer' then return nil, Kora.lang('Error.invalid_vehicle_type') end
    if type(jobId) ~= 'string' or not isInteger(spawnId) then return nil, Kora.lang('Error.invalid_vehicle_request') end

    local job = jobs[jobId]
    if not job or job.active ~= source then return nil, Kora.lang('Error.not_active_job') end
    local state = spawnedVehicles[source] or { jobId = jobId }
    spawnedVehicles[source] = state

    if kind == 'truck' then
        if not playerIsNear(source, Config.Coords.JobStation, 20.0) then return nil, Kora.lang('Error.too_far_depot') end
        local coords = Config.Coords.TruckSpawns[spawnId]
        if not coords then return nil, Kora.lang('Error.invalid_truck_bay') end
        if state.truck and DoesEntityExist(state.truck) then return nil, Kora.lang('Error.truck_in_use') end

        local _, trucker = normaliseTruckerRep(source)
        local truck = truckDefinition(trucker.activeTruck)
        if not truck or not trucker.trucks[truck.name] then return nil, Kora.lang('Error.selected_truck_unavailable') end
        local plate = ('TRK%s'):format(jobId):sub(1, 8)
        local entity, netId = spawnVehicle(source, truck.name, 'automobile', coords, plate)
        if not entity then return nil, netId end
        -- Server-side spawn: the plate set by spawnVehicle is final, so keys are issued for it here.
        if not giveTruckKeys(source, plate) then
            DeleteEntity(entity)
            return nil, Kora.lang('Error.vehicle_keys_failed')
        end
        state.truck = entity
        state.plate = plate
        return netId
    end

    if not playerIsNear(source, Config.Coords.TrailerLocator, 12.0) then return nil, Kora.lang('Error.too_far_trailer_office') end
    local coords = Config.Coords.TrailerSpawns[spawnId]
    if not coords then return nil, Kora.lang('Error.invalid_trailer_bay') end
    if state.trailer and DoesEntityExist(state.trailer) then return nil, Kora.lang('Error.trailer_already_dispatched') end
    local entity, netId = spawnVehicle(source, job.cargo.trailer, 'trailer', coords)
    if not entity then return nil, netId end
    state.trailer = entity
    return netId
end, { rateLimit = { max = 4, window = 10000 } })

Kora.callback.register('kora_truckerjob:server:jobCompleted', function(source, jobId, successful, trailerNetId)
    if type(jobId) ~= 'string' or type(successful) ~= 'boolean' then return false, Kora.lang('Error.invalid_completion') end
    local job = jobs[jobId]
    if not job or job.active ~= source then return false, Kora.lang('Error.not_active_job') end

    local state = spawnedVehicles[source] or {}
    if not successful then
        deleteEntity(state.trailer)
        state.trailer = nil
        jobs[jobId] = nil
        jobCount = jobCount - 1
        if Config.CooldownOnAbandon then startCooldown(source) end
        return true, { failed = true }
    end

    if not isInteger(trailerNetId) or trailerNetId <= 0 then return false, Kora.lang('Error.trailer_verify_failed') end
    local trailer = NetworkGetEntityFromNetworkId(trailerNetId)
    if not trailer or trailer == 0 or trailer ~= state.trailer or not DoesEntityExist(trailer) then
        return false, Kora.lang('Error.trailer_verify_failed')
    end
    if not playerIsNear(source, job.coords, 25.0) then return false, Kora.lang('Error.too_far_delivery') end
    if GetEntityAttachedTo(trailer) ~= 0
        or #(GetEntityCoords(trailer) - vector3(job.coords.x, job.coords.y, job.coords.z)) > 5.0
        or headingDifference(GetEntityHeading(trailer), job.coords.w) > 10.0 then
        return false, Kora.lang('Error.trailer_not_parked')
    end

    local payout = math.floor(job.distance * Config.PayPerMeter)
    local late = os.time() > job.deadline
    local damaged = GetEntityHealth(trailer) / 10 <= Config.DamagePenaltyThreshold
    if late then payout = payout - math.floor(payout / Config.LateDeliveryPenalty) end
    if damaged then payout = payout - math.floor(payout / Config.DamagePenalty) end

    local paid, payError = exports.kora_core:addMoney(source, 'cash', payout, 'trucker-completed-job')
    if not paid then return false, payError or Kora.lang('Error.payment_failed') end

    local rep, trucker = normaliseTruckerRep(source)
    local xpReward = Config.XPReward
    if job.cargoLevel > 1 and not late and not damaged then xpReward = xpReward * Config.Multipliers.FragileXPMultiplier end
    if job.timeLevel and not late and not damaged then xpReward = xpReward * Config.Multipliers.TimedXPMultiplier end
    xpReward = math.floor(xpReward)

    local previousMilestone = math.floor(trucker.XP / 1000)
    trucker.XP = trucker.XP + xpReward
    local skillPointsGained = math.floor(trucker.XP / 1000) - previousMilestone
    trucker.skillPoints = trucker.skillPoints + skillPointsGained
    local saved, saveError = setTruckerRep(source, rep, trucker)
    if not saved then
        print(('^1[kora_truckerjob]^7 Paid player %d but could not save trucking XP: %s'):format(source, saveError or 'unknown error'))
    end

    jobs[jobId] = nil
    jobCount = jobCount - 1
    startCooldown(source)
    return true, {
        payout = payout,
        xp = xpReward,
        late = late,
        damaged = damaged,
        skillPointsGained = skillPointsGained,
    }
end, { rateLimit = { max = 3, window = 10000 } })

Kora.callback.register('kora_truckerjob:server:skillUpgraded', function(source, skill)
    if skill ~= 'distance' and skill ~= 'cargo' and skill ~= 'time' then return false, Kora.lang('Error.invalid_skill') end
    local rep, trucker = normaliseTruckerRep(source)
    if trucker.skillPoints < 1 then return false, Kora.lang('Error.no_skill_points') end
    if trucker.skills[skill] >= 4 then return false, Kora.lang('Error.skill_max_level') end

    trucker.skills[skill] = trucker.skills[skill] + 1
    trucker.skillPoints = trucker.skillPoints - 1
    local saved, saveError = setTruckerRep(source, rep, trucker)
    if not saved then return false, saveError or Kora.lang('Error.skill_save_failed') end
    return true, trucker
end, { rateLimit = { max = 4, window = 5000 } })

Kora.callback.register('kora_truckerjob:server:truckPurchased', function(source, spawnName)
    local truck = truckDefinition(spawnName)
    if not truck or truck.price <= 0 then return false, Kora.lang('Error.truck_not_for_sale') end
    if not playerIsNear(source, Config.Coords.JobStation, 15.0) then return false, Kora.lang('Error.too_far_depot') end

    local rep, trucker = normaliseTruckerRep(source)
    if trucker.trucks[truck.name] then return false, Kora.lang('Error.truck_already_owned') end
    local paid, paymentError = exports.kora_core:removeMoney(source, 'bank', truck.price, 'trucker-purchase-truck')
    if not paid then return false, paymentError or Kora.lang('Error.not_enough_bank_money') end

    trucker.trucks[truck.name] = true
    local saved, saveError = setTruckerRep(source, rep, trucker)
    if not saved then
        exports.kora_core:addMoney(source, 'bank', truck.price, 'trucker-purchase-refund')
        return false, saveError or Kora.lang('Error.truck_purchase_save_failed')
    end
    return true, trucker
end, { rateLimit = { max = 2, window = 5000 } })

Kora.callback.register('kora_truckerjob:server:truckSelected', function(source, spawnName)
    local truck = truckDefinition(spawnName)
    if not truck then return false, Kora.lang('Error.truck_unavailable') end
    if not playerIsNear(source, Config.Coords.JobStation, 15.0) then return false, Kora.lang('Error.too_far_depot') end

    local rep, trucker = normaliseTruckerRep(source)
    if not trucker.trucks[truck.name] then return false, Kora.lang('Error.truck_not_owned') end
    trucker.activeTruck = truck.name
    local saved, saveError = setTruckerRep(source, rep, trucker)
    if not saved then return false, saveError or Kora.lang('Error.truck_selection_save_failed') end
    return true, trucker
end, { rateLimit = { max = 3, window = 5000 } })

-- A truck that is gone or wrecked can always be handed back: there is nothing left to return to the depot.
local function vehicleIsWrecked(entity)
    if not DoesEntityExist(entity) then return true end
    if GetEntityHealth(entity) <= 0 then return true end
    return GetVehicleEngineHealth ~= nil and GetVehicleEngineHealth(entity) <= 0
end

local function vehicleIsAtReturn(entity)
    local settings = Config.Return or {}
    if settings.requireVehicleInZone == false then return true end
    return #(GetEntityCoords(entity) - vector3(Config.Coords.TruckReturn.x, Config.Coords.TruckReturn.y, Config.Coords.TruckReturn.z))
        <= (settings.maxDistance or 15.0)
end

Kora.callback.register('kora_truckerjob:server:vehicleReturned', function(source, kind, netId)
    if kind ~= 'truck' and kind ~= 'trailer' then return false end
    if not isInteger(netId) or netId <= 0 then return false end
    local state = spawnedVehicles[source]
    local entity = state and state[kind]
    if not entity then return false end
    local exists = DoesEntityExist(entity)
    if exists and NetworkGetNetworkIdFromEntity(entity) ~= netId then return false end
    -- Only the truck must be brought back; trailers are also released when a contract is abandoned or fails.
    if kind == 'truck' and not vehicleIsWrecked(entity) and not vehicleIsAtReturn(entity) then
        -- No notify here: the client shows this once per return-zone visit (Config.Return.awayMode).
        return false, (Config.Return or {}).awayMessage or Kora.lang('Error.truck_return_required')
    end
    if exists then deleteEntity(entity) end
    state[kind] = nil
    if kind == 'truck' then removeTruckKeys(source, state) end
    return true
end, { rateLimit = { max = 4, window = 5000 } })

AddEventHandler('playerDropped', function()
    local source = source
    local jobId = activeJobFor(source)
    if jobId then
        jobs[jobId] = nil
        jobCount = jobCount - 1
    end
    local state = spawnedVehicles[source]
    if state then
        deleteEntity(state.truck)
        deleteEntity(state.trailer)
        removeTruckKeys(source, state)
    end
    spawnedVehicles[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, state in pairs(spawnedVehicles) do
        deleteEntity(state.truck)
        deleteEntity(state.trailer)
    end
end)
