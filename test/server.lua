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

local handlers = {}
local deleted = {}
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

Kora = { callback = {}, notify = {} }
local notifications = {}
function Kora.notify.send(source, payload) notifications[#notifications + 1] = { source = source, payload = payload } end
local keyCalls = { given = {}, removed = {} }
local keysResult = true
function Kora.callback.register(name, handler) callbacks[name] = handler end

exports = {
    kora_core = {
        getPlayerData = function() return nil end,
        getPlayer = function(_, source) return source == 1 and { source = source } or nil end,
        getMetaData = function(_, _, key) return metadata[key] end,
        setMetaData = function(_, _, key, value) metadata[key] = value; return true end,
        randomStr = function() idCounter = idCounter + 1; return ('JOB%d'):format(idCounter) end,
        randomInt = function() return '001' end,
        addMoney = function(_, _, account, amount) paid = { account = account, amount = amount }; return true end,
        removeMoney = function() return true end,
    },
    kora_vehiclekeys = {
        giveKeys = function(_, source, plate, allow)
            keyCalls.given[#keyCalls.given + 1] = { source = source, plate = plate, allow = allow }
            return keysResult
        end,
        removeKeys = function(_, source, plate) keyCalls.removed[#keyCalls.removed + 1] = { source = source, plate = plate } end,
    },
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
function GetEntityAttachedTo() return 0 end
function DeleteEntity(entity) deleted[#deleted + 1] = entity; entities[entity] = nil end
function AddEventHandler(name, handler) handlers[name] = handler end
function GetCurrentResourceName() return 'kora_truckerjob' end

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
assert(#keyCalls.given == 1 and keyCalls.given[1].source == 1, 'dispatching a truck must give the player keys')
assert(keyCalls.given[1].plate == ('TRK%s'):format(job.id):sub(1, 8), 'keys must be issued for the final truck plate')
playerCoords = vector3(Config.Coords.TrailerLocator.x, Config.Coords.TrailerLocator.y, Config.Coords.TrailerLocator.z)
local trailerNetId = assert(callbacks['qbtruckerjob:server:vehicleRequested'](1, 'trailer', job.id, 1))
local trailer = NetworkGetEntityFromNetworkId(trailerNetId)

local invalid = callbacks['qbtruckerjob:server:jobCompleted'](1, job.id, true, trailerNetId + 1)
assert(not invalid, 'completion must reject a different trailer')
entities[trailer].coords = vector3(acceptedJob.coords.x, acceptedJob.coords.y, acceptedJob.coords.z)
entities[trailer].heading = acceptedJob.coords.w
playerCoords = entities[trailer].coords
Config.ContractCooldown = 60
local fakeNow = os.time()
local realTime = os.time
os.time = function() return fakeNow end
local completed, result = callbacks['qbtruckerjob:server:jobCompleted'](1, job.id, true, trailerNetId)
assert(completed and result.payout > 0 and paid.amount == result.payout, 'verified delivery should pay through qbcore')
assert(metadata.rep.trucker.XP > 0, 'verified delivery should persist trucking XP')

-- Contract cooldown: completing a job blocks the next accept until the configured time passes.
playerCoords = vector3(Config.Coords.JobStation.x, Config.Coords.JobStation.y, Config.Coords.JobStation.z)
local blocked, blockedMessage = callbacks['qbtruckerjob:server:jobAccepted'](1, dashboard.jobs[4].id)
assert(not blocked and blockedMessage:find('1m 00s', 1, true), 'cooldown should reject with the remaining time')
assert(notifications[#notifications].source == 1 and notifications[#notifications].payload.type == 'error', 'cooldown should notify the player')
fakeNow = fakeNow + 61
assert(callbacks['qbtruckerjob:server:jobAccepted'](1, dashboard.jobs[4].id), 'cooldown should expire')

-- Keys are removed when the truck is returned, and a key failure removes the truck.
assert(callbacks['qbtruckerjob:server:jobAccepted'](6, dashboard.jobs[8].id))
local keyedTruck = assert(callbacks['qbtruckerjob:server:vehicleRequested'](6, 'truck', dashboard.jobs[8].id, 3))
-- Return must be refused while the truck is away from the return point, whatever the player position.
local returnPoint = vector3(Config.Coords.TruckReturn.x, Config.Coords.TruckReturn.y, Config.Coords.TruckReturn.z)
playerCoords = returnPoint
local notifiedBefore = #notifications
local refused = callbacks['qbtruckerjob:server:vehicleReturned'](6, 'truck', keyedTruck)
assert(not refused and #notifications == notifiedBefore + 1 and #keyCalls.removed == 0, 'a far truck must not be returned, keys kept')
assert(DoesEntityExist(NetworkGetEntityFromNetworkId(keyedTruck)), 'a refused return must keep the truck')
local keyedEntity = NetworkGetEntityFromNetworkId(keyedTruck)
entities[keyedEntity].coords = vector3(returnPoint.x + Config.Return.maxDistance + 5, returnPoint.y, returnPoint.z)
assert(not callbacks['qbtruckerjob:server:vehicleReturned'](6, 'truck', keyedTruck), 'just outside maxDistance is refused')
Config.Return.requireVehicleInZone = false
assert(callbacks['qbtruckerjob:server:vehicleReturned'](6, 'truck', keyedTruck), 'requireVehicleInZone=false keeps the old behaviour')
Config.Return.requireVehicleInZone = true
playerCoords = vector3(Config.Coords.JobStation.x, Config.Coords.JobStation.y, Config.Coords.JobStation.z)
local wreckJob = dashboard.jobs[8].id
local wreck = assert(callbacks['qbtruckerjob:server:vehicleRequested'](6, 'truck', wreckJob, 3))
entities[NetworkGetEntityFromNetworkId(wreck)].health = 0
assert(callbacks['qbtruckerjob:server:vehicleReturned'](6, 'truck', wreck), 'a wrecked truck can be handed back from anywhere')
keyedTruck = assert(callbacks['qbtruckerjob:server:vehicleRequested'](6, 'truck', wreckJob, 3))
entities[NetworkGetEntityFromNetworkId(keyedTruck)].coords = returnPoint
assert(callbacks['qbtruckerjob:server:vehicleReturned'](6, 'truck', keyedTruck))
assert(#keyCalls.removed == 3 and keyCalls.removed[3].source == 6 and keyCalls.removed[3].plate == keyCalls.given[#keyCalls.given].plate, 'returning the truck must remove its keys')
playerCoords = vector3(Config.Coords.JobStation.x, Config.Coords.JobStation.y, Config.Coords.JobStation.z)
keysResult = false
local keyDeletions = #deleted
assert(not callbacks['qbtruckerjob:server:vehicleRequested'](6, 'truck', dashboard.jobs[8].id, 3), 'failed key issue must reject the truck')
assert(#deleted == keyDeletions + 1, 'failed key issue must delete the spawned truck')
keysResult = true
Config.GiveKeys = false
local givenBefore = #keyCalls.given
local unkeyed = callbacks['qbtruckerjob:server:vehicleRequested'](6, 'truck', dashboard.jobs[8].id, 3)
assert(unkeyed and #keyCalls.given == givenBefore, 'GiveKeys=false must skip the keys resource')
entities[NetworkGetEntityFromNetworkId(unkeyed)].coords = returnPoint
callbacks['qbtruckerjob:server:vehicleReturned'](6, 'truck', unkeyed)
Config.GiveKeys = nil

-- Resource stop deletes every tracked truck/trailer, including completed jobs.
playerCoords = vector3(Config.Coords.JobStation.x, Config.Coords.JobStation.y, Config.Coords.JobStation.z)
local secondJob = dashboard.jobs[2]
assert(callbacks['qbtruckerjob:server:jobAccepted'](2, secondJob.id))
local secondTruckNetId = assert(callbacks['qbtruckerjob:server:vehicleRequested'](2, 'truck', secondJob.id, 2))
playerCoords = vector3(Config.Coords.TrailerLocator.x, Config.Coords.TrailerLocator.y, Config.Coords.TrailerLocator.z)
local secondTrailerNetId = assert(callbacks['qbtruckerjob:server:vehicleRequested'](2, 'trailer', secondJob.id, 2))
entities[NetworkGetEntityFromNetworkId(secondTruckNetId)].coords = returnPoint
assert(callbacks['qbtruckerjob:server:vehicleReturned'](2, 'truck', secondTruckNetId))
assert(not DoesEntityExist(NetworkGetEntityFromNetworkId(secondTruckNetId)), 'normal return should delete its assigned vehicle')
playerCoords = vector3(Config.Coords.JobStation.x, Config.Coords.JobStation.y, Config.Coords.JobStation.z)
assert(callbacks['qbtruckerjob:server:jobAccepted'](3, dashboard.jobs[3].id)) -- No vehicles requested yet.
local foreignVehicle = 9000
entities[foreignVehicle] = { coords = vector3(10000, 10000, 10000), heading = 0, health = 1000 }
local stop = assert(handlers.onResourceStop, 'server must register resource-stop vehicle cleanup')
local deletionsBeforeStop = #deleted
stop('another-resource')
assert(#deleted == deletionsBeforeStop, 'stopping another resource must not delete any trucking vehicles')
assert(DoesEntityExist(NetworkGetEntityFromNetworkId(truckNetId)) and DoesEntityExist(trailer), 'completed job vehicles remain tracked until return or stop')
assert(DoesEntityExist(NetworkGetEntityFromNetworkId(secondTrailerNetId)), 'second player trailer should still exist before stop')
stop(GetCurrentResourceName())
assert(not DoesEntityExist(NetworkGetEntityFromNetworkId(truckNetId)), 'stop must delete the completed job truck')
assert(not DoesEntityExist(trailer), 'stop must delete the completed job trailer')
assert(not DoesEntityExist(NetworkGetEntityFromNetworkId(secondTrailerNetId)), 'stop must clean every player vehicle record')
assert(DoesEntityExist(foreignVehicle), 'stop must preserve vehicles this resource did not create')
assert(#deleted == deletionsBeforeStop + 3, 'stop must delete only the three remaining tracked vehicles')
stop(GetCurrentResourceName())
assert(#deleted == deletionsBeforeStop + 3, 'existing missing-entity guard prevents duplicate deletion')

-- Abandoning only starts the cooldown when configured.
Config.ContractCooldown = 60
assert(callbacks['qbtruckerjob:server:jobCompleted'](1, dashboard.jobs[4].id, false)) -- abandon: no cooldown by default
assert(callbacks['qbtruckerjob:server:jobAccepted'](1, dashboard.jobs[5].id), 'abandoning must not start the cooldown by default')
Config.CooldownOnAbandon = true
assert(callbacks['qbtruckerjob:server:jobCompleted'](1, dashboard.jobs[5].id, false))
assert(not callbacks['qbtruckerjob:server:jobAccepted'](1, dashboard.jobs[6].id), 'abandon cooldown applies when configured')
Config.CooldownOnAbandon = false
Config.ContractCooldown = 0
fakeNow = fakeNow + 61
assert(callbacks['qbtruckerjob:server:jobAccepted'](1, dashboard.jobs[6].id))
assert(callbacks['qbtruckerjob:server:jobCompleted'](1, dashboard.jobs[6].id, false))
assert(callbacks['qbtruckerjob:server:jobAccepted'](1, dashboard.jobs[7].id), 'cooldown 0 means off')
assert(callbacks['qbtruckerjob:server:jobCompleted'](1, dashboard.jobs[7].id, false))
os.time = realTime

-- A skill-1 trucker always sees a contract they qualify for, even when every open one is taken.
metadata.rep.trucker.skills = { distance = 1, cargo = 1, time = 1 }
local function openQualifying()
    local list = assert(callbacks['qbtruckerjob:server:dashboardRequested'](1)).jobs
    local open = {}
    for _, listed in ipairs(list) do
        if not listed.active and listed.distanceLevel == 1 and listed.cargoLevel == 1 and not listed.timeLevel then open[#open + 1] = listed end
    end
    return open
end
local taker = 100
Config.GuaranteeQualifiedJob = false
while #openQualifying() > 0 do
    taker = taker + 1
    assert(callbacks['qbtruckerjob:server:jobAccepted'](taker, openQualifying()[1].id))
end
Config.GuaranteeQualifiedJob = true
assert(#openQualifying() >= 1, 'a new trucker must always have a qualifying contract listed')

print('qbtruckerjob server smoke tests passed')
