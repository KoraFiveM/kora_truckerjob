local resourceRoot = (... or '.'):gsub('/+$', '')

-- Minimal client harness: stubs the natives/Kora helpers client.lua touches and runs CreateThread bodies as coroutines.
local vectorMeta = {}
vectorMeta.__index = vectorMeta
vectorMeta.__sub = function(l, r) return setmetatable({ x = l.x - r.x, y = l.y - r.y, z = l.z - r.z }, vectorMeta) end
vectorMeta.__len = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector3(x, y, z)
    if type(x) == 'table' then return setmetatable({ x = x.x, y = x.y, z = x.z }, vectorMeta) end
    return setmetatable({ x = x, y = y, z = z }, vectorMeta)
end
function vector4(x, y, z, w) return setmetatable({ x = x, y = y, z = z, w = w }, vectorMeta) end

local now, threads = 0, {}
function GetGameTimer() return now end
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = 0 } end
function Wait(ms) coroutine.yield(ms or 0) end
local function tick(ms)
    now = now + (ms or 100)
    for index = #threads, 1, -1 do
        local thread = threads[index]
        if coroutine.status(thread.co) == 'dead' then
            table.remove(threads, index)
        elseif thread.wake <= now then
            local ok, result = coroutine.resume(thread.co)
            assert(ok, result)
            thread.wake = now + (tonumber(result) or 0)
        end
    end
end

local truckAlive, trailerAlive = true, true
local TRUCK, TRAILER = 500, 501
local deadEntityQueries, removedBlips, calls, notices, prompts, hidden, markers = 0, {}, {}, {}, {}, {}, 0
local pedInside = false
local controlReleased = false
local detached

function GetCurrentResourceName() return 'kora_truckerjob' end
function GetResourceState() return 'missing' end
function PlayerPedId() return 1 end
function GetVehiclePedIsIn() return pedInside and TRUCK or 0 end
function GetEntityCoords() return vector3(0, 0, 0) end
function GetEntityHeading() return 90.0 end
function IsAnyVehicleNearPoint() return false end
function DoesEntityExist(entity)
    if entity == TRUCK then return truckAlive end
    if entity == TRAILER then return trailerAlive end
    return false
end
function NetworkDoesNetworkIdExist(id) return (id == 10 and truckAlive) or (id == 11 and trailerAlive) end
function NetworkGetEntityFromNetworkId(id) return id == 10 and TRUCK or TRAILER end
function NetworkGetNetworkIdFromEntity(entity)
    if not DoesEntityExist(entity) then deadEntityQueries = deadEntityQueries + 1 end
    return entity == TRUCK and 10 or 11
end
function SetTrailerLegsLowered() end
function AddBlipForCoord() return 900 end
function AddBlipForEntity() return 901 end
function DoesBlipExist() return true end
function RemoveBlip(blip) removedBlips[#removedBlips + 1] = blip end
function SetBlipSprite() end function SetBlipColour() end function SetBlipScale() end
function SetBlipAsShortRange() end function SetBlipRoute() end
function BeginTextCommandSetBlipName() end function AddTextComponentSubstringPlayerName() end
function EndTextCommandSetBlipName() end
function DrawMarker() markers = markers + 1 end
function IsEntityAttached() return not detached end
function IsControlJustReleased() return controlReleased end
function DetachVehicleFromTrailer() detached = true end
function GetVehicleModelEstimatedMaxSpeed() return 1 end
function joaat() return 1 end
function AddEventHandler() end

local zones = {}
local nextPrompt = 0
Kora = {
    notify = { send = function(payload) notices[#notices + 1] = payload.message end },
    textui = {
        show = function(text) nextPrompt = nextPrompt + 1; prompts[#prompts + 1] = text; return nextPrompt end,
        hide = function(id) hidden[#hidden + 1] = id end,
    },
    zones = { sphere = function(opts)
        local zone = { opts = opts, remove = function() end, isInside = function() return true end }
        zones[#zones + 1] = zone
        return zone
    end },
    blips = { create = function() end },
    shared = { get = function() end },
    nui = { registerApp = function(def) Kora.app = def end, openApp = function() end },
    callback = { trigger = function(name, ...)
        local args = { ... }
        calls[#calls + 1] = { name = name, args = args }
        if name == 'qbtruckerjob:server:dashboardRequested' then
            return { rep = { XP = 0, skillPoints = 0, skills = { distance = 4, cargo = 4, time = 4 }, trucks = {}, activeTruck = 'hauler' }, jobs = {} }
        elseif name == 'qbtruckerjob:server:jobAccepted' then
            return true, { id = 'J1', coords = { x = 10.0, y = 10.0, z = 5.0, w = 90.0 } }
        elseif name == 'qbtruckerjob:server:vehicleRequested' then
            return args[1] == 'truck' and 10 or 11
        elseif name == 'qbtruckerjob:server:jobCompleted' then
            return true, args[2] and { payout = 1, xp = 1, skillPointsGained = 0 } or { failed = true }
        end
        return true
    end },
}

dofile(resourceRoot .. '/config.lua')
local source = assert(io.open(resourceRoot .. '/client/client.lua')):read('a')
local chunk = assert(load(source, '@client.lua'))
local exported = {}
exports = setmetatable({}, { __call = function(_, name, fn) exported[name] = fn end,
    __index = function() return setmetatable({}, { __index = function() return function() return 'zone' end end }) end })
chunk()

local function count(list, name)
    local total = 0
    for _, call in ipairs(list) do if call.name == name then total = total + 1 end end
    return total
end

-- Accept a contract: truck spawns and the watchdog starts.
exported.openDispatch(); tick(); tick()
assert(Kora.app, 'dispatch app registered')
CreateThread(function() assert(Kora.app.onAction('trucker:accept', { itemId = 'J1' }).close) end)
tick(); tick()
assert(count(calls, 'qbtruckerjob:server:vehicleRequested') == 1, 'only the truck is requested on accept')

-- Arrival in the delivery area: notification, marker, text UI.
local dropZone
for _, zone in ipairs(zones) do if zone.opts.radius == 75.0 then dropZone = zone end end
-- Dispatch the trailer through the pickup prompt.
local trailerZone
for _, zone in ipairs(zones) do if zone.opts.radius == Config.TrailerPickup.zoneRadius then trailerZone = zone end end
assert(trailerZone, 'trailer pickup zone exists')
trailerZone.opts.onEnter()
controlReleased = true
tick(); tick()
controlReleased = false
for _, zone in ipairs(zones) do if zone.opts.radius == 75.0 then dropZone = zone end end
assert(dropZone, 'drop-off zone created after dispatch')
dropZone.opts.onEnter()
assert(notices[#notices]:find('detach it with H', 1, true), 'arrival notification names the key')
tick(); tick()
assert(markers > 0, 'drop-zone marker is drawn')
assert(prompts[#prompts] == 'Reverse the trailer into the marker', 'approach guidance shown: ' .. tostring(prompts[#prompts]))

-- Config can switch the guidance off.
Config.Delivery.textUI, Config.Delivery.showMarker, Config.Delivery.notifyOnArrival = false, false, false
local before = { #prompts, markers, #notices }
dropZone.opts.onExit()
dropZone.opts.onEnter()
tick(); tick()
assert(#prompts == before[1] and markers == before[2] and #notices == before[3], 'delivery guidance is config-gated')

-- The truck is deleted mid-job: no queries on the dead entity, blips removed, job ended, no spam.
truckAlive = false
local noticesBefore = #notices
tick(1000); tick(1000); tick(1000)
assert(deadEntityQueries == 0, 'never asks for the network id of a deleted truck')
assert(#notices == noticesBefore + 1 and notices[#notices] == Config.TruckLost.message, 'player is told once')
assert(count(calls, 'qbtruckerjob:server:jobCompleted') == 1, 'job closed once')
local failedCall
for _, call in ipairs(calls) do if call.name == 'qbtruckerjob:server:jobCompleted' then failedCall = call end end
assert(failedCall.args[2] == false, 'job ended as a failure, not a payout')
local releases = 0
for _, call in ipairs(calls) do
    if call.name == 'qbtruckerjob:server:vehicleReturned' and call.args[1] == 'truck' then releases = releases + 1 end
end
assert(releases == 1, 'server told to release the truck once')
assert(#removedBlips > 0, 'blips removed')
print('qbtruckerjob client tests passed')
