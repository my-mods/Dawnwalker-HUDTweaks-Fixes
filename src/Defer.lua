-- All delayed game-object work runs on the game thread. The legacy setting cannot
-- opt back into unsafe widget access. Keep each caller's existing delay/cadence.
local timerWarning = false
local function Defer(ms, fn, gameThread)
    local generation = applyGeneration
    local function run()
        if generation ~= applyGeneration then return end
        pcall(fn)
    end
    if type(ExecuteInGameThreadWithDelay) == "function" then
        ExecuteInGameThreadWithDelay(ms, run)
    elseif type(ExecuteInGameThread) == "function" and type(ExecuteWithDelay) == "function" then
        -- The asynchronous timer only queues work; it never reads a widget.
        ExecuteWithDelay(ms, function() ExecuteInGameThread(run) end)
    elseif not timerWarning then
        timerWarning = true
        Log("Delayed HUD updates require game-thread scheduling; update UE4SS.")
    end
end
