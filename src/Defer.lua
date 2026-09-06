-- One shared game-thread dispatcher; checkpoints never retain borrowed structs.
local Work = {forced = {}, fading = {}, queue = {}, keyed = {}, active = {}, token = 0, due = nil,
    frame = nil, units = 0, started = 0, current = nil, clock = nil, attempts = 0,
    stats = {slices = 0, maxMs = 0, maxUnits = 0, coalesced = 0}}
local Pump, Arm
local function BudgetStep()
    if Work.current ~= coroutine.running() then return end
    while Work.units >= 128 or os.clock() - Work.started >= 0.001 do coroutine.yield() end
    Work.units = Work.units + 1
end
local function Defer(ms, fn, urgent, key, persistent)
    local old = key ~= nil and Work.keyed[key] or nil
    if old and (old.generation == false or old.generation == applyGeneration) then
        Work.stats.coalesced = Work.stats.coalesced + 1
        return
    end
    local job = {fn = fn, due = os.clock() + math.max(ms, 0) / 1000,
        generation = (not persistent) and applyGeneration, lane = urgent and 1 or 2, key = key}
    Work.queue[#Work.queue + 1] = job
    if key ~= nil then Work.keyed[key] = job end
    Arm(ms)
end
Arm = function(ms)
    local due = os.clock() + math.max(ms, 1) / 1000
    if Work.due and Work.due <= due then return end
    Work.token = Work.token + 1
    local token = Work.token
    Work.due = due
    local run = function()
        if token ~= Work.token then return end
        Work.due = nil
        Pump()
    end
    if type(ExecuteInGameThreadWithDelay) == 'function' then
        ExecuteInGameThreadWithDelay(math.max(ms, 1), run)
    elseif type(ExecuteInGameThread) == 'function' and type(ExecuteWithDelay) == 'function' then
        ExecuteWithDelay(math.max(ms, 1), function() ExecuteInGameThread(run) end)
    else
        Work.due = nil
        if not Work.warned then Log('HUD scheduling requires game-thread callbacks.'); Work.warned = true end
    end
end
local function FrameNumber()
    if Work.clock == nil then
        if Work.attempts >= 3 then return nil end
        Work.attempts = Work.attempts + 1
        local ok, lib = pcall(StaticFindObject, '/Script/Engine.Default__KismetSystemLibrary')
        if ok then Work.clock = lib end
    end
    local ok, frame = pcall(function()
        if Work.clock and Work.clock:IsValid() then return Work.clock:GetFrameCount() end
    end)
    if ok and type(frame) == 'number' then return frame end
    Work.clock = nil
    return nil
end
Pump = function()
    local frame = FrameNumber()
    if frame == nil then
        if Work.attempts < 3 then Arm(250)
        elseif not Work.warned then
            Log('HUD updates paused: frame counter unavailable; check UE4SS compatibility.')
            Work.warned = true
        end
        return
    end
    -- Timer expiry is not proof of a new frame: share the budget across all wakes.
    if frame == Work.frame then Arm(16); return end
    Work.frame, Work.units, Work.started = frame, 0, os.clock()
    local now = os.clock()
    for lane = 1, 2 do
        local job = Work.active[lane]
        if job and job.generation ~= false and job.generation ~= applyGeneration then
            if job.key ~= nil and Work.keyed[job.key] == job then Work.keyed[job.key] = nil end
            Work.active[lane] = nil
        end
        while Work.units < 128 and os.clock() - Work.started < 0.001 do
            job = Work.active[lane]
            if not job then
                for i = #Work.queue, 1, -1 do
                    local candidate = Work.queue[i]
                    if candidate.generation ~= false and candidate.generation ~= applyGeneration then
                        if candidate.key ~= nil and Work.keyed[candidate.key] == candidate then Work.keyed[candidate.key] = nil end
                        table.remove(Work.queue, i)
                    end
                end
                for i, candidate in ipairs(Work.queue) do
                    if candidate.lane == lane and candidate.due <= now then
                        job = table.remove(Work.queue, i)
                        job.thread = coroutine.create(job.fn)
                        Work.active[lane] = job
                        break
                    end
                end
            end
            if not job then break end
            Work.units = Work.units + 1
            Work.current = job.thread
            local ok, err = coroutine.resume(job.thread)
            Work.current = nil
            if not ok or coroutine.status(job.thread) == 'dead' then
                if job.key ~= nil and Work.keyed[job.key] == job then Work.keyed[job.key] = nil end
                Work.active[lane] = nil
                if not ok then Log('HUD job stopped: %s', tostring(err)) end
            else break end
        end
    end
    Work.stats.slices = Work.stats.slices + 1
    Work.stats.maxMs = math.max(Work.stats.maxMs, (os.clock() - Work.started) * 1000)
    Work.stats.maxUnits = math.max(Work.stats.maxUnits, Work.units)
    local delay = (Work.active[1] or Work.active[2]) and 1 or nil
    for _, job in ipairs(Work.queue) do
        local remaining = math.max(1, math.ceil((job.due - os.clock()) * 1000))
        delay = delay and math.min(delay, remaining) or remaining
    end
    if delay then Arm(delay) end
end

local function RetireWork()
    applyGeneration = applyGeneration + 1
    for _, job in pairs(Work.active) do
        if job.thread == Work.current then job.generation = applyGeneration end
    end
    if Work.clock == nil then Work.attempts = 0; Work.warned = false end
end
