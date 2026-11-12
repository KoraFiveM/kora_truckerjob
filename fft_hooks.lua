-- Optional FFT development hooks (client). Listed last in fxmanifest.lua and
-- inert unless `setr fft_kora_hooks true`. No other file references FFT.
if GetConvar('fft_kora_hooks', 'false') ~= 'true' then return end

local RUNNER = 'fft'
local VERSION = 1
local MAX_JOBS = 60

local function session()
    if GetResourceState(RUNNER) ~= 'started' then return nil end
    local id = LocalPlayer.state.fftSession
    return type(id) == 'string' and id or nil
end

local actions = {}

-- Read-only summary of the freight board. Contract ids are generated at random
-- on the server and the dispatch app's item list is too deep for kora_lib's
-- hook summary, so a suite cannot otherwise learn which contract to act on.
-- This is the same callback the dispatch app triggers when it opens; it shares
-- that callback's rate limit (5 per 5 s) and changes nothing.
function actions.dashboard()
    local snapshot, err = Kora.callback.trigger('kora_truckerjob:server:dashboardRequested')
    if type(snapshot) ~= 'table' then
        return false, type(err) == 'string' and err or 'Freight dispatch is unavailable', 'rejected'
    end

    local jobs = {}
    for index, job in ipairs(type(snapshot.jobs) == 'table' and snapshot.jobs or {}) do
        if index > MAX_JOBS then break end
        jobs[#jobs + 1] = {
            id = tostring(job.id),
            active = job.active == true,
            distance = tonumber(job.distance),
            distanceLevel = tonumber(job.distanceLevel),
            cargoLevel = tonumber(job.cargoLevel),
            timeLevel = tonumber(job.timeLevel),
        }
    end

    local rep = type(snapshot.rep) == 'table' and snapshot.rep or {}
    local skills = type(rep.skills) == 'table' and rep.skills or {}
    local trucks = {}
    for name, owned in pairs(type(rep.trucks) == 'table' and rep.trucks or {}) do
        if owned and #trucks < 16 then trucks[#trucks + 1] = tostring(name) end
    end
    table.sort(trucks)

    return {
        jobs = jobs,
        activeJobId = type(snapshot.activeJobId) == 'string' and snapshot.activeJobId or nil,
        rep = {
            skills = {
                distance = tonumber(skills.distance), cargo = tonumber(skills.cargo), time = tonumber(skills.time),
            },
            skillPoints = tonumber(rep.skillPoints),
            XP = tonumber(rep.XP),
            activeTruck = type(rep.activeTruck) == 'string' and rep.activeTruck or nil,
            trucks = trucks,
        },
    }
end

exports('fftVersion', function() return VERSION end)
exports('fftAction', function(action, ...)
    if GetInvokingResource() ~= RUNNER or not session() then
        return false, 'FFT hooks are disabled or session is not authorised'
    end
    local handler = actions[action]
    if not handler then return false, 'Unsupported FFT action: ' .. tostring(action) end
    return handler(...)
end)
