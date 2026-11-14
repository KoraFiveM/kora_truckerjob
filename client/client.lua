local APP_ID = 'kora_truckerjob:dispatch'
local appActive = false
local dashboard
local currentJob
local currentTruck
local currentTruckNetId
local deliveryPrompt
local currentTrailer
local trailerTarget
local trailerZone
local trailerPrompt
local trailerKeybind
local deliveryWatch = 0
local dropOffZone
local truckReturnZone
local isInDropoffZone = false
local inReturnZone = false
local returnPending = false
local awayNotified = false
local routeBlip
local trailerBlip
local truckReturnBlip
local returnPrompt
local jobStationTarget

local function notify(message, type_)
    Kora.notify.send({ title = Kora.lang('Title.trucking'), message = message, type = type_ or 'info' })
end

local function money(value)
    return ('$%s'):format(math.floor(tonumber(value) or 0))
end

local function distanceLabel(metres)
    return Kora.lang('Format.distance_km', (tonumber(metres) or 0) / 1000)
end

local function removeBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

local function setRoute(coords)
    removeBlip(routeBlip)
    routeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipColour(routeBlip, 5)
    SetBlipRoute(routeBlip, true)
end

local function clearPrompt()
    if returnPrompt then Kora.textui.hide(returnPrompt.id); returnPrompt = nil end
end

local function setReturnPrompt(state, text)
    if returnPrompt and returnPrompt.state == state then return end
    clearPrompt()
    returnPrompt = { state = state, id = Kora.textui.show(text, { icon = 'Truck', position = 'right-center' }) }
end

local function clearTrailerPrompt()
    if trailerPrompt then Kora.textui.hide(trailerPrompt); trailerPrompt = nil end
    if trailerKeybind then trailerKeybind.remove(); trailerKeybind = nil end
end

local function clearTrailerTarget()
    if trailerTarget then exports.kora_target:removeZone(trailerTarget); trailerTarget = nil end
    clearTrailerPrompt()
    if trailerZone then trailerZone.remove(); trailerZone = nil end
end

local function clearDeliveryPrompt()
    if deliveryPrompt then Kora.textui.hide(deliveryPrompt.id); deliveryPrompt = nil end
end

local function setDeliveryPrompt(state, text)
    if deliveryPrompt and deliveryPrompt.state == state then return end
    clearDeliveryPrompt()
    deliveryPrompt = { state = state, id = Kora.textui.show(text, { icon = 'Truck', position = 'right-center' }) }
end

local function clearDropoffZone()
    clearDeliveryPrompt()
    isInDropoffZone = false
    if dropOffZone then dropOffZone.remove(); dropOffZone = nil end
end

local function clearTruckReturn()
    clearPrompt()
    inReturnZone = false
    removeBlip(truckReturnBlip)
    truckReturnBlip = nil
    if truckReturnZone then truckReturnZone.remove(); truckReturnZone = nil end
end

local function findSpawnPoint(kind)
    local locations = kind == 'trailer' and Config.Coords.TrailerSpawns or Config.Coords.TruckSpawns
    for index, coords in ipairs(locations) do
        if not IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 3.0) then return index end
    end
end

local function networkEntity(netId)
    if type(netId) ~= 'number' or netId <= 0 then return nil end
    local expires = GetGameTimer() + 5000
    while GetGameTimer() < expires do
        if NetworkDoesNetworkIdExist(netId) then
            local entity = NetworkGetEntityFromNetworkId(netId)
            if entity ~= 0 and DoesEntityExist(entity) then return entity end
        end
        Wait(25)
    end
end

local function vehicleIsGone(entity, netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return true end
    if netId and not NetworkDoesNetworkIdExist(netId) then return true end
    return false
end

local function trailerIsParked(coords, heading, trailer)
    if not trailer or trailer == 0 or not DoesEntityExist(trailer) then return false end
    local difference = math.abs((GetEntityHeading(trailer) - heading + 180.0) % 360.0 - 180.0)
    return #(GetEntityCoords(trailer) - coords) <= 5.0 and difference <= 10.0
end

local function releaseTrailer()
    if not currentTrailer then return end
    if DoesEntityExist(currentTrailer) then
        local netId = NetworkGetNetworkIdFromEntity(currentTrailer)
        Kora.callback.trigger('kora_truckerjob:server:vehicleReturned', 'trailer', netId)
    end
    currentTrailer = nil
    removeBlip(trailerBlip)
    trailerBlip = nil
end

-- Client pre-check only: the server re-checks the truck's position before it deletes anything.
local function truckIsAtReturn()
    local settings = Config.Return or {}
    if settings.requireVehicleInZone == false then return true end
    if vehicleIsGone(currentTruck, currentTruckNetId) then return true end -- the server accepts a truck that no longer exists
    return #(GetEntityCoords(currentTruck) - Config.Coords.TruckReturn) <= (settings.maxDistance or 15.0)
end

local function showTruckAway(message)
    local settings = Config.Return or {}
    local text = message or settings.awayMessage or Kora.lang('Error.truck_return_required')
    if settings.awayMode == 'notify' then
        clearPrompt()
        if not awayNotified then
            awayNotified = true
            notify(text, 'error')
        end
    elseif settings.awayMode ~= false then
        setReturnPrompt('away', text)
    end
end

local function attemptTruckReturn()
    if returnPending then return end
    returnPending = true
    clearPrompt()
    local netId = currentTruckNetId
    CreateThread(function()
        local returned, err = Kora.callback.trigger('kora_truckerjob:server:vehicleReturned', 'truck', netId)
        returnPending = false
        if returned then
            if currentTruckNetId == netId then
                currentTruck = nil
                currentTruckNetId = nil
            end
            clearTruckReturn()
            notify((Config.Return or {}).returnedMessage or Kora.lang('Notify.truck_returned'), 'success')
        elseif inReturnZone then
            showTruckAway(err)
        end
    end)
end

-- Runs only on return-zone enter and on cached vehicle/seat changes, never on a timer, so each
-- message is shown once per state instead of being re-sent while the player stands in the zone.
local function refreshTruckReturn()
    if returnPending then return end
    if not truckReturnZone or not inReturnZone or not currentTruck or (currentTrailer and currentJob) then return clearPrompt() end

    local settings = Config.Return or {}
    if Kora.cache.vehicle() == currentTruck then
        if Kora.cache.seat() == -1 then
            setReturnPrompt('exit', settings.exitPrompt or Kora.lang('Prompt.exit_to_return'))
        else
            clearPrompt()
        end
    elseif truckIsAtReturn() then
        attemptTruckReturn()
    else
        showTruckAway()
    end
end

local function startTruckReturn()
    if truckReturnZone or not currentTruck then return end

    truckReturnBlip = AddBlipForCoord(Config.Coords.TruckReturn.x, Config.Coords.TruckReturn.y, Config.Coords.TruckReturn.z)
    SetBlipSprite(truckReturnBlip, 477)
    SetBlipColour(truckReturnBlip, 2)
    SetBlipScale(truckReturnBlip, 0.8)
    SetBlipAsShortRange(truckReturnBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Kora.lang('Title.truck_return'))
    EndTextCommandSetBlipName(truckReturnBlip)

    truckReturnZone = Kora.zones.sphere({
        coords = Config.Coords.TruckReturn,
        radius = (Config.Return or {}).zoneRadius or 10.0,
        debug = Config.Debug,
        onEnter = function()
            inReturnZone = true
            awayNotified = false
            refreshTruckReturn()
        end,
        onExit = function()
            inReturnZone = false
            clearPrompt()
        end,
    })
end

-- Seat updates before vehicle in the kora_lib cache, so only react here to seat swaps inside the truck;
-- getting in or out is handled by the vehicle change that follows.
Kora.cache.onChange('seat', function()
    if truckReturnZone and currentTruck and Kora.cache.vehicle() == currentTruck then refreshTruckReturn() end
end)

Kora.cache.onChange('vehicle', function(vehicle, previous)
    if not truckReturnZone then return end
    refreshTruckReturn()
    -- Leaving the job truck outside the return zone shows no zone prompt, so explain where to take it.
    local settings = Config.Return or {}
    if settings.outsideHint == false or inReturnZone or returnPending then return end
    if not currentTruck or previous ~= currentTruck or vehicle == currentTruck then return end
    notify(settings.outsideMessage or Kora.lang('Notify.return_truck_to_depot'), 'info')
end)

local function finishJob(successful)
    if not currentJob then return false, Kora.lang('Error.no_active_job') end
    local jobId = currentJob.id
    local trailerNetId = currentTrailer and DoesEntityExist(currentTrailer) and NetworkGetNetworkIdFromEntity(currentTrailer) or nil
    local completed, result = Kora.callback.trigger('kora_truckerjob:server:jobCompleted', jobId, successful, trailerNetId)
    if not completed then return false, result or Kora.lang('Error.job_complete_failed') end

    removeBlip(routeBlip)
    routeBlip = nil
    clearTrailerTarget()
    currentJob = nil
    if dashboard then
        dashboard.activeJobId = nil
        for index = #dashboard.jobs, 1, -1 do
            if dashboard.jobs[index].id == jobId then table.remove(dashboard.jobs, index); break end
        end
    end

    if successful then
        local details = { Kora.lang('Notify.delivery_paid_xp', money(result.payout), result.xp) }
        if result.late then details[#details + 1] = Kora.lang('Notify.late_penalty') end
        if result.damaged then details[#details + 1] = Kora.lang('Notify.damage_penalty') end
        if result.skillPointsGained > 0 then details[#details + 1] = Kora.lang('Notify.skill_point_gained') end
        notify(table.concat(details, '\n'), 'success')
    else
        releaseTrailer()
        clearDropoffZone()
    end

    startTruckReturn()
    return true
end

-- Marker drawing is the only thing that still needs a frame loop; parked/attached state, prompts and
-- completion are re-evaluated every Config.Delivery.checkInterval. With a detach keybind and no marker
-- the loop sleeps for the whole interval.
local function watchDelivery(job)
    local coords = vector3(job.coords.x, job.coords.y, job.coords.z - 1.0)
    local settings = Config.Delivery or {}
    local key = settings.detachKey or 74
    local keyLabel = settings.detachKeyLabel or 'H'
    local interval = settings.checkInterval or 250
    local keybindKey = settings.detachKeybind
    local showMarker = settings.showMarker ~= false
    deliveryWatch = deliveryWatch + 1
    local watchId = deliveryWatch

    local function trailerAttached()
        return currentTrailer and DoesEntityExist(currentTrailer) and IsEntityAttached(currentTrailer)
    end

    local function detachTrailer()
        if currentTruck and DoesEntityExist(currentTruck) then DetachVehicleFromTrailer(currentTruck) end
    end

    local bind
    if type(keybindKey) == 'string' and keybindKey ~= '' then
        bind = Kora.keybind.add({
            name = 'kora_truckerjob_detach',
            description = Kora.lang('Keybind.detach_trailer'),
            defaultKey = keybindKey,
            onReleased = function()
                if watchId == deliveryWatch and trailerIsParked(coords, job.coords.w, currentTrailer) and trailerAttached() then
                    detachTrailer()
                end
            end,
        })
    end
    local frameWait = (showMarker or not bind) and 0 or interval

    CreateThread(function()
        local parked, attached, nextCheck = false, false, 0
        while watchId == deliveryWatch and isInDropoffZone and currentJob and currentJob.id == job.id do
            if GetGameTimer() >= nextCheck then
                nextCheck = GetGameTimer() + interval
                parked = trailerIsParked(coords, job.coords.w, currentTrailer)
                attached = trailerAttached()
                if settings.textUI ~= false then
                    if parked and attached then
                        local text = (settings.detachText or Kora.lang('Prompt.detach_trailer')):gsub('{key}', keyLabel)
                        setDeliveryPrompt('detach', text)
                    elseif not parked then
                        setDeliveryPrompt('approach', settings.approachText or Kora.lang('Prompt.reverse_trailer'))
                    else
                        clearDeliveryPrompt()
                    end
                end
                if parked and not attached then
                    clearDeliveryPrompt()
                    local completed, err = finishJob(true)
                    if completed then break end
                    notify(err, 'error')
                    Wait(1000)
                end
            end
            if showMarker then
                local colour = parked and { r = 0, g = 185, b = 0 } or { r = 255, g = 0, b = 0 }
                DrawMarker(30, coords, 0.0, 0.0, 1.0, 0.0,
                    job.coords.w > 180 and 540 - job.coords.w or 180 - job.coords.w,
                    0.0, 3.0, 3.0, 5.0, colour.r, colour.g, colour.b, 185,
                    false, false, 2, false, nil, nil, false)
            end
            if not bind and parked and attached and IsControlJustReleased(0, key) then detachTrailer() end
            Wait(frameWait)
        end
        if bind then bind.remove() end
        -- A newer watch (zone re-entered quickly) owns the prompt now.
        if watchId == deliveryWatch then clearDeliveryPrompt() end
    end)
end

local function createDropoffZone(job)
    clearDropoffZone()
    dropOffZone = Kora.zones.sphere({
        coords = vector3(job.coords.x, job.coords.y, job.coords.z),
        radius = 75.0,
        debug = Config.Debug,
        onEnter = function()
            isInDropoffZone = true
            local settings = Config.Delivery or {}
            if settings.notifyOnArrival ~= false then
            local message = (settings.arrivalMessage or Kora.lang('Prompt.arrival_instructions'))
                    :gsub('{key}', settings.detachKeyLabel or 'H')
                notify(message, 'info')
            end
            watchDelivery(job)
        end,
        onExit = function()
            isInDropoffZone = false
            if currentJob then return end
            releaseTrailer()
            clearDropoffZone()
            startTruckReturn()
            if truckReturnZone and inReturnZone then refreshTruckReturn() end
        end,
    })
end

-- The event handler at the bottom only catches CEventNetworkVehicleUndrivable; a trailer that exploded or was deleted
-- without that event firing would leave the contract open forever, so poll for it like the truck.
local function watchTrailer(trailer)
    local settings = Config.TrailerLost or {}
    if settings.enabled == false then return end
    CreateThread(function()
        while currentTrailer == trailer and currentJob do
            if not DoesEntityExist(trailer) or IsEntityDead(trailer) then
                notify(settings.message or Kora.lang('Error.trailer_destroyed'), 'error')
                if finishJob(false) then return end
            end
            Wait(settings.checkInterval or 1000)
        end
    end)
end

local function dispatchTrailer()
    if not currentJob or currentTrailer then return end
    local spawnId = findSpawnPoint('trailer')
    if not spawnId then return notify(Kora.lang('Error.no_trailer_bays'), 'error') end

    local netId, err = Kora.callback.trigger('kora_truckerjob:server:vehicleRequested', 'trailer', currentJob.id, spawnId)
    if not netId then return notify(err or Kora.lang('Error.trailer_dispatch_failed'), 'error') end
    local trailer = networkEntity(netId)
    if not trailer then
        Kora.callback.trigger('kora_truckerjob:server:vehicleReturned', 'trailer', netId)
        return notify(Kora.lang('Error.trailer_network_failed'), 'error')
    end

    currentTrailer = trailer
    clearTrailerTarget()
    removeBlip(routeBlip)
    routeBlip = nil
    SetTrailerLegsLowered(currentTrailer)
    notify(Kora.lang('Notify.trailer_in_bay', spawnId), 'success')

    setRoute(currentJob.coords)
    trailerBlip = AddBlipForEntity(currentTrailer)
    SetBlipSprite(trailerBlip, 479)
    createDropoffZone(currentJob)
    watchTrailer(currentTrailer)
end

local function createTrailerZone()
    local settings = Config.TrailerPickup or {}
    if settings.zoneRadius == 0 then return end
    local key = settings.key or 38
    local keybindKey = settings.keybind
    local dispatching = false

    local function tryDispatch()
        if dispatching then return end
        dispatching = true
        local ok, err = pcall(dispatchTrailer)
        dispatching = false
        if not ok then error(err, 0) end
    end

    trailerZone = Kora.zones.sphere({
        coords = Config.Coords.TrailerLocator,
        radius = settings.zoneRadius or 8.0,
        debug = Config.Debug,
        onEnter = function()
            if trailerPrompt or currentTrailer then return end
            if settings.allowInVehicle == false and GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then return end
            trailerPrompt = Kora.textui.show(settings.prompt or Kora.lang('Prompt.dispatch_trailer'), {
                icon = 'Truck', position = 'right-center',
            })
            if type(keybindKey) == 'string' and keybindKey ~= '' then
                -- Registered only while inside the zone, so no frame loop is needed to read the key.
                trailerKeybind = Kora.keybind.add({
                    name = 'kora_truckerjob_dispatch',
                    description = Kora.lang('Keybind.dispatch_trailer'),
                    defaultKey = keybindKey,
                    onReleased = function()
                        if not trailerPrompt then return end
                        tryDispatch()
                        if currentTrailer then clearTrailerPrompt() end
                    end,
                })
                return
            end
            CreateThread(function()
                while trailerPrompt and trailerZone and trailerZone.isInside() do
                    if IsControlJustReleased(0, key) then
                        tryDispatch()
                        if currentTrailer then break end
                    end
                    Wait(0)
                end
                clearTrailerPrompt()
            end)
        end,
        onExit = function()
            clearTrailerPrompt()
        end,
    })
end

local function createTrailerTarget()
    clearTrailerTarget()
    setRoute(Config.Coords.TrailerLocator)
    createTrailerZone()
    trailerTarget = exports.kora_target:addSphereZone({
        coords = Config.Coords.TrailerLocator,
        radius = (Config.TrailerPickup or {}).targetRadius or 0.75,
        distance = 2.5,
        debug = Config.Debug,
        options = {
            {
                label = Kora.lang('Target.dispatch_trailer'),
                icon = 'Truck',
                onSelect = dispatchTrailer,
            },
        },
    })
end

-- The truck was deleted/despawned behind our back: clean up and close the job without touching dead network ids.
local function handleTruckLost()
    local netId = currentTruckNetId
    currentTruck = nil
    currentTruckNetId = nil
    clearTruckReturn()
    if netId then Kora.callback.trigger('kora_truckerjob:server:vehicleReturned', 'truck', netId) end
    local settings = Config.TruckLost or {}
    notify(settings.message or Kora.lang('Error.truck_lost'), 'error')
    if currentJob then finishJob(false) end
    removeBlip(routeBlip)
    routeBlip = nil
end

local function watchTruck(truck)
    local settings = Config.TruckLost or {}
    if settings.enabled == false then return end
    CreateThread(function()
        while currentTruck == truck do
            if vehicleIsGone(truck, currentTruckNetId) then
                handleTruckLost()
                return
            end
            Wait(settings.checkInterval or 1000)
        end
    end)
end

local function spawnTruck(jobId)
    local spawnId = findSpawnPoint('truck')
    if not spawnId then return false, Kora.lang('Error.no_truck_bays') end
    local netId, err = Kora.callback.trigger('kora_truckerjob:server:vehicleRequested', 'truck', jobId, spawnId)
    if not netId then return false, err or Kora.lang('Error.truck_dispatch_failed') end
    local truck = networkEntity(netId)
    if not truck then
        Kora.callback.trigger('kora_truckerjob:server:vehicleReturned', 'truck', netId)
        return false, Kora.lang('Error.truck_network_failed')
    end

    currentTruck = truck
    currentTruckNetId = netId
    if type(Config.FuelResource) == 'string' and GetResourceState(Config.FuelResource) == 'started' then
        pcall(function() exports[Config.FuelResource]:SetFuel(currentTruck, math.random(50, 70)) end)
    end
    watchTruck(truck)
    return true
end

local function acceptJob(jobId)
    if currentJob then return false, Kora.lang('Error.active_job_exists') end
    local accepted, job = Kora.callback.trigger('kora_truckerjob:server:jobAccepted', jobId)
    if not accepted then return false, job or Kora.lang('Error.job_accept_failed') end

    currentJob = job
    if dashboard then dashboard.activeJobId = job.id end
    clearTruckReturn()
    if not currentTruck then
        local spawned, spawnError = spawnTruck(job.id)
        if not spawned then
            finishJob(false)
            return false, spawnError
        end
    else
        notify(Kora.lang('Notify.continue_current_truck'), 'info')
    end
    createTrailerTarget()
    return true
end

local skillDefinitions = {
    distance = { label = Kora.lang('Skill.distance'), icon = 'Route', description = Kora.lang('Skill.distance_description') },
    cargo = { label = Kora.lang('Skill.cargo'), icon = 'Package', description = Kora.lang('Skill.cargo_description') },
    time = { label = Kora.lang('Skill.expedited'), icon = 'Clock', description = Kora.lang('Skill.expedited_description') },
}

local function jobItems()
    local result = {}
    local rep = dashboard.rep
    for _, job in ipairs(dashboard.jobs or {}) do
        local eligible = not job.active and not dashboard.activeJobId
            and job.distanceLevel <= rep.skills.distance
            and job.cargoLevel <= rep.skills.cargo
            and (not job.timeLevel or job.timeLevel <= rep.skills.time)
        local metadata = {
            { label = Kora.lang('Menu.distance'), value = distanceLabel(job.distance) },
            { label = Kora.lang('Menu.estimated_pay'), value = money(job.distance * Config.PayPerMeter) },
            { label = Kora.lang('Menu.cargo_level'), value = job.cargoLevel },
        }
        if job.timeLevel then metadata[#metadata + 1] = { label = Kora.lang('Menu.expedited_level'), value = job.timeLevel } end
        result[#result + 1] = {
            id = job.id,
            label = job.cargo.label,
            description = Kora.lang('Menu.contract_description', job.id, distanceLabel(job.distance)),
            image = ('nui://kora_truckerjob/html/images/cargo/%s'):format(job.image),
            badge = job.active and (job.id == dashboard.activeJobId and Kora.lang('Menu.active_job') or Kora.lang('Menu.taken'))
                or eligible and Kora.lang('Menu.available') or Kora.lang('Menu.locked'),
            tone = job.active and 'neutral' or eligible and 'success' or 'warning',
            metadata = metadata,
            actions = {
                { id = 'trucker:accept', label = Kora.lang('Menu.accept_contract'), icon = 'Check', variant = 'primary', disabled = not eligible },
            },
        }
    end
    return result
end

local function skillItems()
    local result = {}
    for _, key in ipairs({ 'distance', 'cargo', 'time' }) do
        local definition = skillDefinitions[key]
        local level = dashboard.rep.skills[key]
        result[#result + 1] = {
            id = key,
            label = definition.label,
            description = definition.description,
            icon = definition.icon,
            badge = Kora.lang('Menu.skill_level', level),
            metadata = { { label = Kora.lang('Menu.current_level'), value = level }, { label = Kora.lang('Menu.maximum'), value = 4 } },
            actions = {
                { id = 'trucker:upgrade', label = Kora.lang('Menu.spend_skill_point'), icon = 'ArrowUp', variant = 'primary',
                    disabled = level >= 4 or dashboard.rep.skillPoints < 1 },
            },
        }
    end
    return result
end

local function truckItems()
    local result = {}
    for _, truck in ipairs(Config.Trucks) do
        local registryVehicle = Kora.shared.get('vehicles', truck.name)
        local label = registryVehicle and registryVehicle.name or truck.label or truck.name
        local owned = dashboard.rep.trucks[truck.name] == true
        local selected = dashboard.rep.activeTruck == truck.name
        local actions = {}
        if not owned then
            actions[1] = { id = 'trucker:purchase', label = Kora.lang('Menu.purchase_for', money(truck.price)),
                icon = 'ShoppingCart', variant = 'primary', confirm = Kora.lang('Menu.purchase_confirm', label) }
        elseif not selected then
            actions[1] = { id = 'trucker:select', label = Kora.lang('Menu.use_truck'), icon = 'Check', variant = 'primary' }
        end
        result[#result + 1] = {
            id = truck.name,
            label = label,
            description = truck.price == 0 and Kora.lang('Menu.starter_truck') or Kora.lang('Menu.purchase_price', money(truck.price)),
            image = ('nui://kora_truckerjob/html/images/trucks/%s.webp'):format(truck.name),
            badge = selected and Kora.lang('Menu.selected') or owned and Kora.lang('Menu.owned') or Kora.lang('Menu.for_sale'),
            tone = selected and 'success' or owned and 'primary' or 'neutral',
            metadata = {
                { label = Kora.lang('Menu.top_speed'), value = Kora.lang('Format.speed_mph', GetVehicleModelEstimatedMaxSpeed(joaat(truck.name)) * 2.236936) },
                { label = Kora.lang('Menu.price'), value = money(truck.price) },
            },
            actions = actions,
        }
    end
    return result
end

local function appDefinition()
    local rep = dashboard.rep
    local xpProgress = rep.XP % 1000
    local activeActions = dashboard.activeJobId and {
        { id = 'trucker:cancel', label = Kora.lang('Menu.cancel_contract'), icon = 'X', variant = 'destructive',
            confirm = Kora.lang('Menu.cancel_confirm') },
    } or nil

    return {
        id = APP_ID,
        title = Kora.lang('Title.freight_dispatch'),
        description = dashboard.activeJobId and Kora.lang('Menu.active_contract', dashboard.activeJobId) or Kora.lang('Menu.freight_network'),
        icon = 'Truck',
        width = 1180,
        height = 780,
        navigation = {
            {
                id = 'contracts', label = Kora.lang('Menu.contracts'), icon = 'ClipboardList', badge = #(dashboard.jobs or {}),
                content = {
                    title = Kora.lang('Menu.available_contracts'),
                    description = Kora.lang('Menu.contracts_description'),
                    actions = activeActions,
                    scrollable = false,
                    blocks = {
                        { type = 'list', id = 'contracts', layout = 'cards', searchable = true, scrollable = true,
                            searchPlaceholder = Kora.lang('Menu.search_contracts'), pageSize = 12, items = jobItems(),
                            empty = Kora.lang('Menu.no_contracts') },
                    },
                },
            },
            {
                id = 'skills', label = Kora.lang('Menu.skills'), icon = 'TrendingUp', badge = rep.skillPoints,
                content = {
                    title = Kora.lang('Menu.driver_progression'),
                    description = Kora.lang('Menu.unspent_skill_points', rep.skillPoints, rep.skillPoints == 1 and '' or 's'),
                    blocks = {
                        { type = 'stats', items = {
                            { label = Kora.lang('Menu.total_xp'), value = math.floor(rep.XP), icon = 'Star', tone = 'primary' },
                            { label = Kora.lang('Menu.skill_points'), value = rep.skillPoints, icon = 'Sparkles', tone = rep.skillPoints > 0 and 'success' or 'neutral' },
                        } },
                        { type = 'progress', title = Kora.lang('Menu.next_skill_point'), items = {
                            { label = Kora.lang('Menu.experience_milestone'), value = xpProgress, max = 1000,
                                detail = Kora.lang('Format.xp_progress', xpProgress), icon = 'Gauge', tone = 'primary' },
                        } },
                        { type = 'list', id = 'skills', layout = 'cards', items = skillItems() },
                    },
                },
            },
            {
                id = 'trucks', label = Kora.lang('Menu.trucks'), icon = 'Truck',
                content = {
                    title = Kora.lang('Menu.depot_fleet'),
                    description = Kora.lang('Menu.depot_fleet_description'),
                    blocks = {
                        { type = 'list', id = 'trucks', layout = 'cards', items = truckItems() },
                    },
                },
            },
        },
        footer = Kora.lang('Menu.server_verified_footer'),
        onAction = function(actionId, context)
            local itemId = context and context.itemId
            if actionId == 'trucker:accept' then
                local accepted, err = acceptJob(itemId)
                if not accepted then return { notice = { tone = 'destructive', message = err } } end
                return { close = true, notice = { tone = 'success', message = Kora.lang('Notify.contract_accepted') } }
            elseif actionId == 'trucker:cancel' then
                local cancelled, err = finishJob(false)
                if not cancelled then return { notice = { tone = 'destructive', message = err } } end
            elseif actionId == 'trucker:upgrade' then
                local upgraded, repOrError = Kora.callback.trigger('kora_truckerjob:server:skillUpgraded', itemId)
                if not upgraded then return { notice = { tone = 'destructive', message = repOrError or Kora.lang('Error.skill_upgrade_failed') } } end
                dashboard.rep = repOrError
            elseif actionId == 'trucker:purchase' then
                local purchased, repOrError = Kora.callback.trigger('kora_truckerjob:server:truckPurchased', itemId)
                if not purchased then return { notice = { tone = 'destructive', message = repOrError or Kora.lang('Error.truck_purchase_failed') } } end
                dashboard.rep = repOrError
            elseif actionId == 'trucker:select' then
                local selected, repOrError = Kora.callback.trigger('kora_truckerjob:server:truckSelected', itemId)
                if not selected then return { notice = { tone = 'destructive', message = repOrError or Kora.lang('Error.truck_selection_failed') } } end
                dashboard.rep = repOrError
            else
                error('That trucking action is no longer available.')
            end

            local updated = appDefinition()
            return {
                update = { navigation = updated.navigation, description = updated.description },
                notice = { tone = 'success', message = actionId == 'trucker:cancel'
                    and Kora.lang('Notify.contract_cancelled_return') or Kora.lang('Notify.changes_saved') },
            }
        end,
    }
end

local function openDispatch()
    if appActive then return end
    appActive = true
    CreateThread(function()
        local ok, err = pcall(function()
            local snapshot, loadError = Kora.callback.trigger('kora_truckerjob:server:dashboardRequested')
            if not snapshot then return notify(loadError or Kora.lang('Error.dispatch_unavailable'), 'error') end
            dashboard = snapshot
            if dashboard.activeJobId and not currentJob then
                for _, job in ipairs(dashboard.jobs) do
                    if job.id == dashboard.activeJobId then currentJob = job; break end
                end
            end
            Kora.nui.registerApp(appDefinition())
            Kora.nui.openApp(APP_ID)
        end)
        dashboard = nil
        appActive = false
        if not ok then
            print(('^1[kora_truckerjob]^7 Freight dispatch failed: %s'):format(tostring(err)))
            notify(Kora.lang('Error.dispatch_open_failed'), 'error')
        end
    end)
end

local function registerJobStationTarget()
    if jobStationTarget then exports.kora_target:removeZone(jobStationTarget) end
    jobStationTarget = exports.kora_target:addSphereZone({
        coords = vector3(Config.Coords.JobStation.x, Config.Coords.JobStation.y, Config.Coords.JobStation.z),
        radius = 0.75,
        distance = 2.5,
        debug = Config.Debug,
        options = {
            {
                label = Kora.lang('Target.open_dispatch'),
                icon = 'Truck',
                onSelect = openDispatch,
            },
        },
    })
end

registerJobStationTarget()

CreateThread(function()
    Kora.blips.create(Config.Coords.JobStation, {
        sprite = 477,
        color = 2,
        scale = 0.8,
        shortRange = true,
        category = Kora.lang('Title.trucking'),
        name = Kora.lang('Title.freight_depot'),
        info = {
            title = Kora.lang('Title.freight_depot'),
            rows = {
                { kind = 'wrappedText', value = Kora.lang('Blip.freight_depot_description') },
            },
        },
    })
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'kora_target' then registerJobStationTarget() end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkVehicleUndrivable' then return end
    local entity = args[1]
    if currentTrailer and entity == currentTrailer and currentJob then
        notify(Kora.lang('Error.trailer_destroyed'), 'error')
        finishJob(false)
    elseif currentTruck and entity == currentTruck then
        local netId = currentTruckNetId
        currentTruck = nil
        currentTruckNetId = nil
        if netId then Kora.callback.trigger('kora_truckerjob:server:vehicleReturned', 'truck', netId) end
        clearTruckReturn()
        if currentJob then finishJob(false) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeBlip(routeBlip)
    removeBlip(trailerBlip)
    removeBlip(truckReturnBlip)
end)

exports('openDispatch', openDispatch)
