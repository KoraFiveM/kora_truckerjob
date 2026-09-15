local APP_ID = 'qbtruckerjob:dispatch'
local appActive = false
local dashboard
local currentJob
local currentTruck
local currentTrailer
local trailerTarget
local dropOffZone
local truckReturnZone
local isInDropoffZone = false
local returningTruck = false
local routeBlip
local trailerBlip
local truckReturnBlip
local returnPrompt
local appDefinition
local jobStationTarget

local function notify(message, type_)
    QB.notify.send({ title = 'Trucking', message = message, type = type_ or 'info' })
end

local function money(value)
    return ('$%s'):format(math.floor(tonumber(value) or 0))
end

local function distanceLabel(metres)
    return ('%.1f km'):format((tonumber(metres) or 0) / 1000)
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
    if returnPrompt then QB.textui.hide(returnPrompt); returnPrompt = nil end
end

local function clearTrailerTarget()
    if trailerTarget then exports.qbtarget:removeZone(trailerTarget); trailerTarget = nil end
end

local function clearDropoffZone()
    isInDropoffZone = false
    if dropOffZone then dropOffZone.remove(); dropOffZone = nil end
end

local function clearTruckReturn()
    clearPrompt()
    returningTruck = false
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

local function trailerIsParked(coords, heading, trailer)
    if not trailer or trailer == 0 or not DoesEntityExist(trailer) then return false end
    local difference = math.abs((GetEntityHeading(trailer) - heading + 180.0) % 360.0 - 180.0)
    return #(GetEntityCoords(trailer) - coords) <= 5.0 and difference <= 10.0
end

local function releaseTrailer()
    if not currentTrailer then return end
    local netId = NetworkGetNetworkIdFromEntity(currentTrailer)
    QB.callback.trigger('qbtruckerjob:server:vehicleReturned', 'trailer', netId)
    currentTrailer = nil
    removeBlip(trailerBlip)
    trailerBlip = nil
end

local function startTruckReturn()
    if truckReturnZone or not currentTruck then return end

    truckReturnBlip = AddBlipForCoord(Config.Coords.TruckReturn.x, Config.Coords.TruckReturn.y, Config.Coords.TruckReturn.z)
    SetBlipSprite(truckReturnBlip, 477)
    SetBlipColour(truckReturnBlip, 2)
    SetBlipScale(truckReturnBlip, 0.8)
    SetBlipAsShortRange(truckReturnBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Truck Return')
    EndTextCommandSetBlipName(truckReturnBlip)

    truckReturnZone = QB.zones.sphere({
        coords = Config.Coords.TruckReturn,
        radius = 10.0,
        debug = Config.Debug,
        onEnter = function()
            if currentTrailer or returningTruck then return end
            returnPrompt = QB.textui.show('Exit the vehicle to return the truck', {
                icon = 'Truck', position = 'right-center',
            })
            returningTruck = true
            CreateThread(function()
                while returningTruck and truckReturnZone and truckReturnZone.isInside() do
                    if GetVehiclePedIsIn(PlayerPedId(), false) ~= currentTruck then
                        local netId = NetworkGetNetworkIdFromEntity(currentTruck)
                        local returned = QB.callback.trigger('qbtruckerjob:server:vehicleReturned', 'truck', netId)
                        if returned then
                            currentTruck = nil
                            clearTruckReturn()
                            notify('Truck returned to the depot.', 'success')
                        end
                        return
                    end
                    Wait(250)
                end
            end)
        end,
        onExit = function()
            clearPrompt()
            returningTruck = false
        end,
    })
end

local function finishJob(successful)
    if not currentJob then return false, 'You do not have an active job.' end
    local jobId = currentJob.id
    local trailerNetId = currentTrailer and NetworkGetNetworkIdFromEntity(currentTrailer) or nil
    local completed, result = QB.callback.trigger('qbtruckerjob:server:jobCompleted', jobId, successful, trailerNetId)
    if not completed then return false, result or 'The job could not be completed.' end

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
        local details = { ('Paid %s and earned %d XP.'):format(money(result.payout), result.xp) }
        if result.late then details[#details + 1] = 'A late-delivery penalty was applied.' end
        if result.damaged then details[#details + 1] = 'A cargo-damage penalty was applied.' end
        if result.skillPointsGained > 0 then details[#details + 1] = 'You gained a skill point.' end
        notify(table.concat(details, '\n'), 'success')
        if dropOffZone then
            -- Keep the delivered trailer visible until the driver leaves the yard.
            return true
        end
    else
        releaseTrailer()
        clearDropoffZone()
    end

    startTruckReturn()
    return true
end

local function watchDelivery(job)
    local coords = vector3(job.coords.x, job.coords.y, job.coords.z - 1.0)
    CreateThread(function()
        while isInDropoffZone and currentJob and currentJob.id == job.id do
            local parked = trailerIsParked(coords, job.coords.w, currentTrailer)
            local colour = parked and { r = 0, g = 185, b = 0 } or { r = 255, g = 0, b = 0 }
            DrawMarker(30, coords, 0.0, 0.0, 1.0, 0.0,
                job.coords.w > 180 and 540 - job.coords.w or 180 - job.coords.w,
                0.0, 3.0, 3.0, 5.0, colour.r, colour.g, colour.b, 185,
                false, false, 2, false, nil, nil, false)
            if parked and not IsEntityAttached(currentTrailer) then
                local completed, err = finishJob(true)
                if completed then return end
                notify(err, 'error')
                Wait(1000)
            end
            Wait(0)
        end
    end)
end

local function createDropoffZone(job)
    clearDropoffZone()
    dropOffZone = QB.zones.sphere({
        coords = vector3(job.coords.x, job.coords.y, job.coords.z),
        radius = 75.0,
        debug = Config.Debug,
        onEnter = function()
            isInDropoffZone = true
            watchDelivery(job)
        end,
        onExit = function()
            isInDropoffZone = false
            if currentJob then return end
            releaseTrailer()
            clearDropoffZone()
            startTruckReturn()
        end,
    })
end

local function dispatchTrailer()
    if not currentJob or currentTrailer then return end
    local spawnId = findSpawnPoint('trailer')
    if not spawnId then return notify('There are no available trailer bays.', 'error') end

    local netId, err = QB.callback.trigger('qbtruckerjob:server:vehicleRequested', 'trailer', currentJob.id, spawnId)
    if not netId then return notify(err or 'The trailer could not be dispatched.', 'error') end
    local trailer = networkEntity(netId)
    if not trailer then
        QB.callback.trigger('qbtruckerjob:server:vehicleReturned', 'trailer', netId)
        return notify('The trailer did not enter the network.', 'error')
    end

    currentTrailer = trailer
    clearTrailerTarget()
    removeBlip(routeBlip)
    routeBlip = nil
    SetTrailerLegsLowered(currentTrailer)
    notify(('Your trailer is in Bay K%d.'):format(spawnId), 'success')

    setRoute(currentJob.coords)
    trailerBlip = AddBlipForEntity(currentTrailer)
    SetBlipSprite(trailerBlip, 479)
    createDropoffZone(currentJob)
end

local function createTrailerTarget()
    clearTrailerTarget()
    setRoute(Config.Coords.TrailerLocator)
    trailerTarget = exports.qbtarget:addSphereZone({
        coords = Config.Coords.TrailerLocator,
        radius = 0.75,
        distance = 2.5,
        debug = Config.Debug,
        options = {
            {
                label = 'Dispatch assigned trailer',
                icon = 'Truck',
                onSelect = dispatchTrailer,
            },
        },
    })
end

local function spawnTruck(jobId)
    local spawnId = findSpawnPoint('truck')
    if not spawnId then return false, 'There are no available truck bays.' end
    local netId, err = QB.callback.trigger('qbtruckerjob:server:vehicleRequested', 'truck', jobId, spawnId)
    if not netId then return false, err or 'The truck could not be dispatched.' end
    local truck = networkEntity(netId)
    if not truck then
        QB.callback.trigger('qbtruckerjob:server:vehicleReturned', 'truck', netId)
        return false, 'The truck did not enter the network.'
    end

    currentTruck = truck
    if type(Config.FuelResource) == 'string' and GetResourceState(Config.FuelResource) == 'started' then
        pcall(function() exports[Config.FuelResource]:SetFuel(currentTruck, math.random(50, 70)) end)
    end
    return true
end

local function acceptJob(jobId)
    if currentJob then return false, 'You already have an active job.' end
    local accepted, job = QB.callback.trigger('qbtruckerjob:server:jobAccepted', jobId)
    if not accepted then return false, job or 'This job could not be accepted.' end

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
        notify('Continue using your current truck.', 'info')
    end
    createTrailerTarget()
    return true
end

local skillDefinitions = {
    distance = { label = 'Distance', icon = 'Route', description = 'Unlock longer delivery routes.' },
    cargo = { label = 'Cargo', icon = 'Package', description = 'Unlock fragile and specialist loads.' },
    time = { label = 'Expedited', icon = 'Clock', description = 'Unlock tighter delivery windows.' },
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
            { label = 'Distance', value = distanceLabel(job.distance) },
            { label = 'Estimated pay', value = money(job.distance * Config.PayPerMeter) },
            { label = 'Cargo level', value = job.cargoLevel },
        }
        if job.timeLevel then metadata[#metadata + 1] = { label = 'Expedited level', value = job.timeLevel } end
        result[#result + 1] = {
            id = job.id,
            label = job.cargo.label,
            description = ('Contract %s · %s'):format(job.id, distanceLabel(job.distance)),
            image = ('nui://qbtruckerjob/html/images/cargo/%s'):format(job.image),
            badge = job.active and (job.id == dashboard.activeJobId and 'Your active job' or 'Taken')
                or eligible and 'Available' or 'Locked',
            tone = job.active and 'neutral' or eligible and 'success' or 'warning',
            metadata = metadata,
            actions = {
                { id = 'trucker:accept', label = 'Accept contract', icon = 'Check', variant = 'primary', disabled = not eligible },
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
            badge = ('Level %d / 4'):format(level),
            metadata = { { label = 'Current level', value = level }, { label = 'Maximum', value = 4 } },
            actions = {
                { id = 'trucker:upgrade', label = 'Spend one skill point', icon = 'ArrowUp', variant = 'primary',
                    disabled = level >= 4 or dashboard.rep.skillPoints < 1 },
            },
        }
    end
    return result
end

local function truckItems()
    local result = {}
    for _, truck in ipairs(Config.Trucks) do
        local registryVehicle = QB.shared.get('vehicles', truck.name)
        local label = registryVehicle and registryVehicle.name or truck.label or truck.name
        local owned = dashboard.rep.trucks[truck.name] == true
        local selected = dashboard.rep.activeTruck == truck.name
        local actions = {}
        if not owned then
            actions[1] = { id = 'trucker:purchase', label = ('Purchase for %s'):format(money(truck.price)),
                icon = 'ShoppingCart', variant = 'primary', confirm = ('Purchase %s with bank funds?'):format(label) }
        elseif not selected then
            actions[1] = { id = 'trucker:select', label = 'Use this truck', icon = 'Check', variant = 'primary' }
        end
        result[#result + 1] = {
            id = truck.name,
            label = label,
            description = truck.price == 0 and 'Depot starter truck' or ('Purchase price: %s'):format(money(truck.price)),
            image = ('nui://qbtruckerjob/html/images/trucks/%s.webp'):format(truck.name),
            badge = selected and 'Selected' or owned and 'Owned' or 'For sale',
            tone = selected and 'success' or owned and 'primary' or 'neutral',
            metadata = {
                { label = 'Top speed', value = ('%.0f mph'):format(GetVehicleModelEstimatedMaxSpeed(joaat(truck.name)) * 2.236936) },
                { label = 'Price', value = money(truck.price) },
            },
            actions = actions,
        }
    end
    return result
end

appDefinition = function()
    local rep = dashboard.rep
    local xpProgress = rep.XP % 1000
    local activeActions = dashboard.activeJobId and {
        { id = 'trucker:cancel', label = 'Cancel active contract', icon = 'X', variant = 'destructive',
            confirm = 'Cancel this contract? No payment or XP will be awarded.' },
    } or nil

    return {
        id = APP_ID,
        title = 'Freight Dispatch',
        description = dashboard.activeJobId and ('Active contract: %s'):format(dashboard.activeJobId) or 'Los Santos freight network',
        icon = 'Truck',
        width = 1180,
        height = 780,
        navigation = {
            {
                id = 'contracts', label = 'Contracts', icon = 'ClipboardList', badge = #(dashboard.jobs or {}),
                content = {
                    title = 'Available freight contracts',
                    description = 'Contracts are filtered by your current skill levels and reserved when accepted.',
                    actions = activeActions,
                    scrollable = false,
                    blocks = {
                        { type = 'list', id = 'contracts', layout = 'cards', searchable = true, scrollable = true,
                            searchPlaceholder = 'Search cargo or contract ID…', pageSize = 12, items = jobItems(),
                            empty = 'No freight contracts are available right now.' },
                    },
                },
            },
            {
                id = 'skills', label = 'Skills', icon = 'TrendingUp', badge = rep.skillPoints,
                content = {
                    title = 'Driver progression',
                    description = ('You have %d unspent skill point%s.'):format(rep.skillPoints, rep.skillPoints == 1 and '' or 's'),
                    blocks = {
                        { type = 'stats', items = {
                            { label = 'Total XP', value = math.floor(rep.XP), icon = 'Star', tone = 'primary' },
                            { label = 'Skill points', value = rep.skillPoints, icon = 'Sparkles', tone = rep.skillPoints > 0 and 'success' or 'neutral' },
                        } },
                        { type = 'progress', title = 'Next skill point', items = {
                            { label = 'Experience milestone', value = xpProgress, max = 1000,
                                detail = ('%d / 1,000 XP'):format(xpProgress), icon = 'Gauge', tone = 'primary' },
                        } },
                        { type = 'list', id = 'skills', layout = 'cards', items = skillItems() },
                    },
                },
            },
            {
                id = 'trucks', label = 'Trucks', icon = 'Truck',
                content = {
                    title = 'Depot fleet',
                    description = 'Buy trucks with bank funds and choose which tractor the depot dispatches.',
                    blocks = {
                        { type = 'list', id = 'trucks', layout = 'cards', items = truckItems() },
                    },
                },
            },
        },
        footer = 'Contracts, rewards, skills, and vehicle access are verified by the server.',
        onAction = function(actionId, context)
            local itemId = context and context.itemId
            if actionId == 'trucker:accept' then
                local accepted, err = acceptJob(itemId)
                if not accepted then return { notice = { tone = 'destructive', message = err } } end
                return { close = true, notice = { tone = 'success', message = 'Contract accepted.' } }
            elseif actionId == 'trucker:cancel' then
                local cancelled, err = finishJob(false)
                if not cancelled then return { notice = { tone = 'destructive', message = err } } end
            elseif actionId == 'trucker:upgrade' then
                local upgraded, repOrError = QB.callback.trigger('qbtruckerjob:server:skillUpgraded', itemId)
                if not upgraded then return { notice = { tone = 'destructive', message = repOrError or 'Skill upgrade failed.' } } end
                dashboard.rep = repOrError
            elseif actionId == 'trucker:purchase' then
                local purchased, repOrError = QB.callback.trigger('qbtruckerjob:server:truckPurchased', itemId)
                if not purchased then return { notice = { tone = 'destructive', message = repOrError or 'Truck purchase failed.' } } end
                dashboard.rep = repOrError
            elseif actionId == 'trucker:select' then
                local selected, repOrError = QB.callback.trigger('qbtruckerjob:server:truckSelected', itemId)
                if not selected then return { notice = { tone = 'destructive', message = repOrError or 'Truck selection failed.' } } end
                dashboard.rep = repOrError
            else
                error('That trucking action is no longer available.')
            end

            local updated = appDefinition()
            return {
                update = { navigation = updated.navigation, description = updated.description },
                notice = { tone = 'success', message = actionId == 'trucker:cancel'
                    and 'Contract cancelled. Return your truck to the depot.' or 'Changes saved.' },
            }
        end,
    }
end

local function openDispatch()
    if appActive then return end
    appActive = true
    CreateThread(function()
        local ok, err = pcall(function()
            local snapshot, loadError = QB.callback.trigger('qbtruckerjob:server:dashboardRequested')
            if not snapshot then return notify(loadError or 'Freight dispatch is unavailable.', 'error') end
            dashboard = snapshot
            if dashboard.activeJobId and not currentJob then
                for _, job in ipairs(dashboard.jobs) do
                    if job.id == dashboard.activeJobId then currentJob = job; break end
                end
            end
            QB.nui.registerApp(appDefinition())
            QB.nui.openApp(APP_ID)
        end)
        dashboard = nil
        appActive = false
        if not ok then
            print(('^1[qbtruckerjob]^7 Freight dispatch failed: %s'):format(tostring(err)))
            notify('The freight dispatch interface could not be opened.', 'error')
        end
    end)
end

local function registerJobStationTarget()
    if jobStationTarget then exports.qbtarget:removeZone(jobStationTarget) end
    jobStationTarget = exports.qbtarget:addSphereZone({
        coords = vector3(Config.Coords.JobStation.x, Config.Coords.JobStation.y, Config.Coords.JobStation.z),
        radius = 0.75,
        distance = 2.5,
        debug = Config.Debug,
        options = {
            {
                label = 'Open freight dispatch',
                icon = 'Truck',
                onSelect = openDispatch,
            },
        },
    })
end

registerJobStationTarget()

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'qbtarget' then registerJobStationTarget() end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkVehicleUndrivable' then return end
    local entity = args[1]
    if currentTrailer and entity == currentTrailer and currentJob then
        notify('Your trailer was destroyed.', 'error')
        finishJob(false)
    elseif currentTruck and entity == currentTruck then
        local netId = NetworkGetNetworkIdFromEntity(currentTruck)
        QB.callback.trigger('qbtruckerjob:server:vehicleReturned', 'truck', netId)
        currentTruck = nil
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
