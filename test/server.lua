local resourceRoot = (... or '.'):gsub('/+$', '')

local vectorMeta = {}
vectorMeta.__index = vectorMeta
vectorMeta.__sub = function(left, right)
    return setmetatable({ x = left.x - right.x, y = left.y - right.y, z = left.z - right.z }, vectorMeta)
end
vectorMeta.__len = function(value)
    return math.sqrt(value.x * value.x + value.y * value.y + value.z * value.z)
end

function vector3(x, y, z)
    if type(x) == 'table' then return setmetatable({ x = x.x, y = x.y, z = x.z }, vectorMeta) end
    return setmetatable({ x = x, y = y, z = z }, vectorMeta)
end

function vector4(x, y, z, w)
    return setmetatable({ x = x, y = y, z = z, w = w }, vectorMeta)
end

local callbacks = {}
local threads = {}
local metadata = { rep = { trucker = {
    skills = { distance = 4, cargo = 4, time = 4 },
    trucks = { hauler = true }, activeTruck = 'hauler', skillPoints = 0, XP = 0,
} } }
local entities = {}
local playerCoords
local nextEntity = 200
local idCounter = 0
local paid

QB = { callback = {} }
function QB.callback.register(name, handler) callbacks[name] = handler end

exports = {
    qbcore = {
        getPlayer = function(_, source) return source == 1 and { source = source } or nil end,
        getMetaData = function(_, _, key) return metadata[key] end,
        setMetaData = function(_, _, key, value) metadata[key] = value; return true end,
        randomStr = function() idCounter = idCounter + 1; return ('JOB%d'):format(idCounter) end,
        randomInt = function() return '001' end,
        addMoney = function(_, _, account, amount) paid = { account = account, amount = amount }; return true end,
        removeMoney = function() return true end,
    },
    qbvehiclekeys = { giveKeys = function() return true end },
}

function CreateThread(handler) threads[#threads + 1] = coroutine.create(handler) end
function Wait() coroutine.yield() end
function GetPlayerPed() return 10 end
function GetEntityCoords(entity) return entity == 10 and playerCoords or entities[entity].coords end
function GetEntityHeading(entity) return entities[entity].heading end
function GetEntityHealth(entity) return entities[entity].health end
function DoesEntityExist(entity) return entities[entity] ~= nil end
function GetAllVehicles()
    local result = {}
    for entity in pairs(entities) do result[#result + 1] = entity end
    return result
end
function joaat(value) return value end
function CreateVehicleServerSetter(_, _, x, y, z, heading)
    nextEntity = nextEntity + 1
    entities[nextEntity] = { coords = vector3(x, y, z), heading = heading, health = 1000 }
    return nextEntity
end
function GetPlayerRoutingBucket() return 0 end
function SetEntityRoutingBucket() end
function SetVehicleNumberPlateText() end
function NetworkGetNetworkIdFromEntity(entity) return entity + 1000 end
function NetworkGetEntityFromNetworkId(netId) return netId - 1000 end
function IsEntityAttached() return false end
function DeleteEntity(entity) entities[entity] = nil end
function AddEventHandler() end

assert(loadfile(resourceRoot .. '/config.lua'))()
playerCoords = vector3(Config.Coords.JobStation.x, Config.Coords.JobStation.y, Config.Coords.JobStation.z)
assert(loadfile(resourceRoot .. '/server.lua'))()
assert(coroutine.resume(threads[1]))

local dashboard = assert(callbacks['qbtruckerjob:server:dashboardRequested'](1))
assert(#dashboard.jobs == Config.MaxJobs, 'expected the configured initial job count')
local job = dashboard.jobs[1]
local accepted, acceptedJob = callbacks['qbtruckerjob:server:jobAccepted'](1, job.id)
assert(accepted and acceptedJob.id == job.id, 'eligible nearby player should accept a job')
local duplicate = callbacks['qbtruckerjob:server:jobAccepted'](1, dashboard.jobs[2].id)
assert(not duplicate, 'a player must not accept a second active job')

local truckNetId = assert(callbacks['qbtruckerjob:server:vehicleRequested'](1, 'truck', job.id, 1))
assert(truckNetId > 0, 'accepted job should dispatch a truck')
playerCoords = vector3(Config.Coords.TrailerLocator.x, Config.Coords.TrailerLocator.y, Config.Coords.TrailerLocator.z)
local trailerNetId = assert(callbacks['qbtruckerjob:server:vehicleRequested'](1, 'trailer', job.id, 1))
local trailer = NetworkGetEntityFromNetworkId(trailerNetId)

local invalid = callbacks['qbtruckerjob:server:jobCompleted'](1, job.id, true, trailerNetId + 1)
assert(not invalid, 'completion must reject a different trailer')
entities[trailer].coords = vector3(acceptedJob.coords.x, acceptedJob.coords.y, acceptedJob.coords.z)
entities[trailer].heading = acceptedJob.coords.w
playerCoords = entities[trailer].coords
local completed, result = callbacks['qbtruckerjob:server:jobCompleted'](1, job.id, true, trailerNetId)
assert(completed and result.payout > 0 and paid.amount == result.payout, 'verified delivery should pay through qbcore')
assert(metadata.rep.trucker.XP > 0, 'verified delivery should persist trucking XP')

print('qbtruckerjob server smoke tests passed')
