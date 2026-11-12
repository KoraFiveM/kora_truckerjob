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
local binds = {}
local detached

function GetCurrentResourceName() return 'kora_truckerjob' end
function GetResourceState() return 'missing' end
function PlayerPedId() return 1 end
function GetVehiclePedIsIn() return pedInside and TRUCK or 0 end
local truckCoords, trailerCoords = vector3(0, 0, 0), vector3(0, 0, 0)
function GetEntityCoords(entity)
    return entity == TRUCK and truckCoords or entity == TRAILER and trailerCoords or vector3(0, 0, 0)
end
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
local holdApp = false
local cacheState, cacheHandlers = { vehicle = false, seat = false }, {}
local function setCache(key, value)
    local old = cacheState[key]
    if old == value then return end
    cacheState[key] = value
    for _, handler in ipairs(cacheHandlers[key] or {}) do handler(value, old) end
end
Kora = {
    cache = {
        vehicle = function() return cacheState.vehicle end,
        seat = function() return cacheState.seat end,
        onChange = function(key, handler)
            cacheHandlers[key] = cacheHandlers[key] or {}
            table.insert(cacheHandlers[key], handler)
        end,
    },
    keybind = { add = function(opts)
        local bind = { opts = opts }
        bind.remove = function() if binds[opts.name] == bind then binds[opts.name] = nil end end
        binds[opts.name] = bind
        return bind
    end },
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
    nui = { registerApp = function(def) Kora.app = def end, openApp = function() while holdApp do Wait(100) end end },
    callback = { trigger = function(name, ...)
        local args = { ... }
        calls[#calls + 1] = { name = name, args = args }
        if name == 'kora_truckerjob:server:dashboardRequested' then
            return { rep = { XP = 0, skillPoints = 0, skills = { distance = 4, cargo = 4, time = 4 }, trucks = {}, activeTruck = 'hauler' }, jobs = {} }
        elseif name == 'kora_truckerjob:server:jobAccepted' then
            return true, { id = 'J1', coords = { x = 10.0, y = 10.0, z = 5.0, w = 90.0 } }
        elseif name == 'kora_truckerjob:server:vehicleRequested' then
            return args[1] == 'truck' and 10 or 11
        elseif name == 'kora_truckerjob:server:jobCompleted' then
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
assert(count(calls, 'kora_truckerjob:server:vehicleRequested') == 1, 'only the truck is requested on accept')

-- Arrival in the delivery area: notification, marker, text UI.
local dropZone
for _, zone in ipairs(zones) do if zone.opts.radius == 75.0 then dropZone = zone end end
-- Dispatch the trailer through the pickup prompt.
local trailerZone
for _, zone in ipairs(zones) do if zone.opts.radius == Config.TrailerPickup.zoneRadius then trailerZone = zone end end
assert(trailerZone, 'trailer pickup zone exists')
trailerZone.opts.onEnter()
assert(binds.kora_truckerjob_dispatch, 'dispatch key is a keybind registered on zone enter, not a polling loop')
CreateThread(function() binds.kora_truckerjob_dispatch.opts.onReleased() end)
tick(); tick()
assert(count(calls, 'kora_truckerjob:server:vehicleRequested') == 2, 'releasing the key dispatches the trailer')
assert(not binds.kora_truckerjob_dispatch, 'dispatch keybind removed once the trailer is dispatched')
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
assert(count(calls, 'kora_truckerjob:server:jobCompleted') == 1, 'job closed once')
local failedCall
for _, call in ipairs(calls) do if call.name == 'kora_truckerjob:server:jobCompleted' then failedCall = call end end
assert(failedCall.args[2] == false, 'job ended as a failure, not a payout')
local releases = 0
for _, call in ipairs(calls) do
    if call.name == 'kora_truckerjob:server:vehicleReturned' and call.args[1] == 'truck' then releases = releases + 1 end
end
assert(releases == 1, 'server told to release the truck once')
assert(#removedBlips > 0, 'blips removed')

-- Truck return zone: event-driven prompts, no repeating notifications.
truckAlive = true
holdApp = true -- keep the dispatch open so the dashboard stays loaded for cancel
exported.openDispatch(); tick(); tick()
CreateThread(function() assert(Kora.app.onAction('trucker:accept', { itemId = 'J1' }).close) end)
tick(); tick()
CreateThread(function() Kora.app.onAction('trucker:cancel', { itemId = 'J1' }) end)
tick(); tick()
holdApp = false
local returnZone
for _, zone in ipairs(zones) do if zone.opts.radius == Config.Return.zoneRadius then returnZone = zone end end
assert(returnZone, 'return zone created after cancelling')
local function shown(text)
    local total = 0
    for _, prompt in ipairs(prompts) do if prompt == text then total = total + 1 end end
    return total
end
local function returnCalls()
    local total = 0
    for _, call in ipairs(calls) do
        if call.name == 'kora_truckerjob:server:vehicleReturned' and call.args[1] == 'truck' then total = total + 1 end
    end
    return total
end

-- On foot, truck parked elsewhere: no exit prompt, the away message shows once and stays.
truckCoords = vector3(0, 0, 0)
local noticesAtEntry, returnsAtEntry, hiddenAtEntry = #notices, returnCalls(), #hidden
returnZone.opts.onEnter()
for _ = 1, 50 do tick(500) end
assert(shown(Config.Return.exitPrompt) == 0, 'exit prompt never shown on foot')
assert(shown(Config.Return.awayMessage) == 1 and prompts[#prompts] == Config.Return.awayMessage, 'away message shown once as text UI')
assert(#notices == noticesAtEntry and #hidden == hiddenAtEntry, 'nothing re-sent while standing in the zone')
assert(returnCalls() == returnsAtEntry, 'server not asked while the truck is away')
returnZone.opts.onExit()
assert(#hidden == hiddenAtEntry + 1, 'away text UI hidden when leaving the zone')

-- notify mode: one notification per zone visit.
Config.Return.awayMode = 'notify'
returnZone.opts.onEnter()
for _ = 1, 50 do tick(500) end
setCache('vehicle', 777); setCache('vehicle', false) -- hopping in and out of another car does not re-notify
assert(#notices == noticesAtEntry + 1 and notices[#notices] == Config.Return.awayMessage, 'notify mode notifies once')
returnZone.opts.onExit()
Config.Return.awayMode = 'textui'

-- Driving the truck in shows the exit prompt; passenger seat does not; getting out returns it.
truckCoords = vector3(Config.Coords.TruckReturn)
setCache('seat', -1); setCache('vehicle', TRUCK)
assert(returnCalls() == returnsAtEntry, 'entering the truck outside the zone does nothing')
local promptsBefore = shown(Config.Return.exitPrompt)
returnZone.opts.onEnter()
assert(shown(Config.Return.exitPrompt) == promptsBefore + 1, 'exit prompt shown in the driver seat')
setCache('seat', 0)
assert(#hidden == hiddenAtEntry + 2, 'exit prompt hidden in a passenger seat')
setCache('seat', -1)
assert(shown(Config.Return.exitPrompt) == promptsBefore + 2, 'exit prompt back in the driver seat')
setCache('seat', false); setCache('vehicle', false)
tick(); tick()
assert(returnCalls() == returnsAtEntry + 1, 'leaving the truck in the zone returns it once')
assert(notices[#notices] == Config.Return.returnedMessage, 'player told the truck was returned')
setCache('vehicle', 777); setCache('vehicle', false)
tick()
assert(returnCalls() == returnsAtEntry + 1, 'no further return attempts after the truck is gone')

-- Delivery bay: the detach key is a keybind, state is polled at checkInterval, completion fires once detached.
local function lastZone(radius)
    for index = #zones, 1, -1 do if zones[index].opts.radius == radius then return zones[index] end end
end
truckAlive, trailerAlive = true, true
holdApp = true
exported.openDispatch(); tick(); tick()
CreateThread(function() assert(Kora.app.onAction('trucker:accept', { itemId = 'J1' }).close) end)
tick(); tick()
holdApp = false
Config.Delivery.textUI, Config.Delivery.showMarker, Config.Delivery.notifyOnArrival = true, true, false
local pickup = lastZone(Config.TrailerPickup.zoneRadius)
pickup.opts.onEnter()
CreateThread(function() binds.kora_truckerjob_dispatch.opts.onReleased() end)
tick(); tick()
local bay = lastZone(75.0)
bay.opts.onEnter()
assert(binds.kora_truckerjob_detach, 'detach key registered while the bay is active')
local completedBefore = count(calls, 'kora_truckerjob:server:jobCompleted')
trailerCoords = vector3(10, 10, 4) -- lined up in the marker, still hitched
local markersBefore = markers
tick(0); tick(0)
assert(prompts[#prompts] == 'Press H to detach the trailer and deliver', 'detach guidance shown: ' .. tostring(prompts[#prompts]))
binds.kora_truckerjob_detach.opts.onReleased()
assert(detached, 'detach key detaches the trailer when parked')
tick(300); tick(300)
assert(count(calls, 'kora_truckerjob:server:jobCompleted') == completedBefore + 1, 'job completes once the trailer is detached')
assert(not binds.kora_truckerjob_detach, 'detach keybind removed when the watch ends')
assert(markers > markersBefore, 'marker still drawn')

print('kora_truckerjob client tests passed')
