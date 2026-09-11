local jobs = {}
local jobCount = 0
local spawnedVehicles = {}

local skillDistances = { 1500, 3000, 5000, 7000 }
local truckDefinition

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

local function normaliseTruckerRep(source)
    local rep = exports.qbcore:getMetaData(source, 'rep') or {}
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

    if changed then exports.qbcore:setMetaData(source, 'rep', rep) end
    return rep, trucker
end

local function setTruckerRep(source, rep, trucker)
    rep.trucker = trucker
    return exports.qbcore:setMetaData(source, 'rep', rep)
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

local function generateJob()
    local deliveryCoords = Config.Coords.Deliveries[math.random(1, #Config.Coords.Deliveries)]
    local cargoLevel = math.random(1, #Config.DeliveryTypes)
    local cargoOptions = Config.DeliveryTypes[cargoLevel]
    local cargo = cargoOptions[math.random(1, #cargoOptions)]
    local distance = math.floor(#(deliveryCoords - Config.Coords.JobStation))
    local id

    repeat
        id = exports.qbcore:randomStr(3) .. exports.qbcore:randomInt(3)
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
        timeLevel = math.random(1, 100) <= Config.TimedChanceGenerator and math.random(2, 4) or nil,
        active = false,
    }
    jobCount = jobCount + 1
end

local function deleteEntity(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
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
    if vehicleAtSpawn(coords) then return nil, 'That bay is no longer available.' end

    local entity = CreateVehicleServerSetter(joaat(model), vehicleType, coords.x, coords.y, coords.z, coords.w)
    local attempts = 0
    while entity and entity ~= 0 and not DoesEntityExist(entity) and attempts < 100 do
        Wait(0)
        attempts = attempts + 1
    end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil, 'Vehicle creation failed.' end

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
        return nil, 'Vehicle network registration failed.'
    end
    return entity, netId
end

truckDefinition = function(spawnName)
    if type(spawnName) ~= 'string' then return nil end
    for _, truck in ipairs(Config.Trucks) do
        if truck.name == spawnName then return truck end
    end
end

local function headingDifference(left, right)
    return math.abs((left - right + 180.0) % 360.0 - 180.0)
end

CreateThread(function()
    for _ = 1, Config.MaxJobs do generateJob() end
    while true do
        Wait(Config.JobGenerationTimer * 60000)
        if jobCount < Config.MaxJobs then generateJob() end
    end
end)

QB.callback.register('qbtruckerjob:server:dashboardRequested', function(source)
    if not exports.qbcore:getPlayer(source) then return nil, 'Your character is not available.' end
    local _, trucker = normaliseTruckerRep(source)
    local availableJobs, activeJobId = jobsForClient(source)
    return { jobs = availableJobs, activeJobId = activeJobId, rep = trucker }
end, { rateLimit = { max = 5, window = 5000 } })

QB.callback.register('qbtruckerjob:server:jobAccepted', function(source, jobId)
    if type(jobId) ~= 'string' then return false, 'Invalid job.' end
    if not playerIsNear(source, Config.Coords.JobStation, 15.0) then return false, 'You are too far from the depot.' end

    local job = jobs[jobId]
    if not job then return false, 'This job is no longer available.' end
    if job.active then return false, 'This job has already been taken.' end
    if activeJobFor(source) then return false, 'You already have an active job.' end

    local _, trucker = normaliseTruckerRep(source)
    if job.distanceLevel > trucker.skills.distance then return false, 'Increase your distance skill to take this job.' end
    if job.cargoLevel > trucker.skills.cargo then return false, 'Increase your cargo skill to handle this load.' end
    if job.timeLevel and job.timeLevel > trucker.skills.time then return false, 'Increase your time skill to take this expedited job.' end

    job.active = source
    local duration = 300 + math.floor(job.distance / 1000) * 60
    if job.timeLevel then duration = duration - 45 * job.timeLevel end
    job.deadline = os.time() + math.max(60, duration)
    spawnedVehicles[source] = spawnedVehicles[source] or {}
    spawnedVehicles[source].jobId = jobId
    return true, clientJob(jobId, job)
end, { rateLimit = { max = 3, window = 5000 } })

QB.callback.register('qbtruckerjob:server:vehicleRequested', function(source, kind, jobId, spawnId)
    if kind ~= 'truck' and kind ~= 'trailer' then return nil, 'Invalid vehicle type.' end
    if type(jobId) ~= 'string' or not isInteger(spawnId) then return nil, 'Invalid vehicle request.' end

    local job = jobs[jobId]
    if not job or job.active ~= source then return nil, 'This is not your active job.' end
    local state = spawnedVehicles[source] or { jobId = jobId }
    spawnedVehicles[source] = state

    if kind == 'truck' then
        if not playerIsNear(source, Config.Coords.JobStation, 20.0) then return nil, 'You are too far from the depot.' end
        local coords = Config.Coords.TruckSpawns[spawnId]
        if not coords then return nil, 'Invalid truck bay.' end
        if state.truck and DoesEntityExist(state.truck) then return nil, 'You already have a truck in use.' end

        local _, trucker = normaliseTruckerRep(source)
        local truck = truckDefinition(trucker.activeTruck)
        if not truck or not trucker.trucks[truck.name] then return nil, 'Your selected truck is unavailable.' end
        local plate = ('TRK%s'):format(jobId):sub(1, 8)
        local entity, netId = spawnVehicle(source, truck.name, 'automobile', coords, plate)
        if not entity then return nil, netId end
        if exports.qbvehiclekeys:giveKeys(source, plate) ~= true then
            DeleteEntity(entity)
            return nil, 'Vehicle keys could not be issued.'
        end
        state.truck = entity
        return netId
    end

    if not playerIsNear(source, Config.Coords.TrailerLocator, 12.0) then return nil, 'You are too far from the trailer office.' end
    local coords = Config.Coords.TrailerSpawns[spawnId]
    if not coords then return nil, 'Invalid trailer bay.' end
    if state.trailer and DoesEntityExist(state.trailer) then return nil, 'Your trailer has already been dispatched.' end
    local entity, netId = spawnVehicle(source, job.cargo.trailer, 'trailer', coords)
    if not entity then return nil, netId end
    state.trailer = entity
    return netId
end, { rateLimit = { max = 4, window = 10000 } })

QB.callback.register('qbtruckerjob:server:jobCompleted', function(source, jobId, successful, trailerNetId)
    if type(jobId) ~= 'string' or type(successful) ~= 'boolean' then return false, 'Invalid completion request.' end
    local job = jobs[jobId]
    if not job or job.active ~= source then return false, 'This job is not active.' end

    local state = spawnedVehicles[source] or {}
    if not successful then
        deleteEntity(state.trailer)
        state.trailer = nil
        jobs[jobId] = nil
        jobCount = jobCount - 1
        return true, { failed = true }
    end

    if not isInteger(trailerNetId) or trailerNetId <= 0 then return false, 'The assigned trailer could not be verified.' end
    local trailer = NetworkGetEntityFromNetworkId(trailerNetId)
    if not trailer or trailer == 0 or trailer ~= state.trailer or not DoesEntityExist(trailer) then
        return false, 'The assigned trailer could not be verified.'
    end
    if not playerIsNear(source, job.coords, 25.0) then return false, 'You are too far from the delivery point.' end
    if IsEntityAttached(trailer)
        or #(GetEntityCoords(trailer) - vector3(job.coords.x, job.coords.y, job.coords.z)) > 5.0
        or headingDifference(GetEntityHeading(trailer), job.coords.w) > 10.0 then
        return false, 'Park the trailer fully inside the delivery marker.'
    end

    local payout = math.floor(job.distance * Config.PayPerMeter)
    local late = os.time() > job.deadline
    local damaged = GetEntityHealth(trailer) / 10 <= Config.DamagePenaltyThreshold
    if late then payout = payout - math.floor(payout / Config.LateDeliveryPenalty) end
    if damaged then payout = payout - math.floor(payout / Config.DamagePenalty) end

    local paid, payError = exports.qbcore:addMoney(source, 'cash', payout, 'trucker-completed-job')
    if not paid then return false, payError or 'Payment failed.' end

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
        print(('^1[qbtruckerjob]^7 Paid player %d but could not save trucking XP: %s'):format(source, saveError or 'unknown error'))
    end

    jobs[jobId] = nil
    jobCount = jobCount - 1
    return true, {
        payout = payout,
        xp = xpReward,
        late = late,
        damaged = damaged,
        skillPointsGained = skillPointsGained,
    }
end, { rateLimit = { max = 3, window = 10000 } })

QB.callback.register('qbtruckerjob:server:skillUpgraded', function(source, skill)
    if skill ~= 'distance' and skill ~= 'cargo' and skill ~= 'time' then return false, 'Invalid skill.' end
    local rep, trucker = normaliseTruckerRep(source)
    if trucker.skillPoints < 1 then return false, 'You do not have enough skill points.' end
    if trucker.skills[skill] >= 4 then return false, 'That skill is already at its maximum level.' end

    trucker.skills[skill] = trucker.skills[skill] + 1
    trucker.skillPoints = trucker.skillPoints - 1
    local saved, saveError = setTruckerRep(source, rep, trucker)
    if not saved then return false, saveError or 'The skill upgrade could not be saved.' end
    return true, trucker
end, { rateLimit = { max = 4, window = 5000 } })

QB.callback.register('qbtruckerjob:server:truckPurchased', function(source, spawnName)
    local truck = truckDefinition(spawnName)
    if not truck or truck.price <= 0 then return false, 'That truck is not for sale.' end
    if not playerIsNear(source, Config.Coords.JobStation, 15.0) then return false, 'You are too far from the depot.' end

    local rep, trucker = normaliseTruckerRep(source)
    if trucker.trucks[truck.name] then return false, 'You already own this truck.' end
    local paid, paymentError = exports.qbcore:removeMoney(source, 'bank', truck.price, 'trucker-purchase-truck')
    if not paid then return false, paymentError or 'You do not have enough money in the bank.' end

    trucker.trucks[truck.name] = true
    local saved, saveError = setTruckerRep(source, rep, trucker)
    if not saved then
        exports.qbcore:addMoney(source, 'bank', truck.price, 'trucker-purchase-refund')
        return false, saveError or 'The truck purchase could not be saved.'
    end
    return true, trucker
end, { rateLimit = { max = 2, window = 5000 } })

QB.callback.register('qbtruckerjob:server:truckSelected', function(source, spawnName)
    local truck = truckDefinition(spawnName)
    if not truck then return false, 'That truck is unavailable.' end
    if not playerIsNear(source, Config.Coords.JobStation, 15.0) then return false, 'You are too far from the depot.' end

    local rep, trucker = normaliseTruckerRep(source)
    if not trucker.trucks[truck.name] then return false, 'You do not own this truck.' end
    trucker.activeTruck = truck.name
    local saved, saveError = setTruckerRep(source, rep, trucker)
    if not saved then return false, saveError or 'The truck selection could not be saved.' end
    return true, trucker
end, { rateLimit = { max = 3, window = 5000 } })

QB.callback.register('qbtruckerjob:server:vehicleReturned', function(source, kind, netId)
    if kind ~= 'truck' and kind ~= 'trailer' then return false end
    if not isInteger(netId) or netId <= 0 then return false end
    local state = spawnedVehicles[source]
    local entity = state and state[kind]
    if not entity or NetworkGetNetworkIdFromEntity(entity) ~= netId then return false end
    deleteEntity(entity)
    state[kind] = nil
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
    end
    spawnedVehicles[source] = nil
end)
