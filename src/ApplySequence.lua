local function ApplySequence(reason)
    Defer(0, function()
        Debug('apply (%s)', reason)
        ResetFade()
        PatchClassDefaults()
        HookFadeFrame()
        ObjectIndex.start()
        -- A full pass is reserved for explicit configuration/diagnostic requests.
        -- Normal startup/load relies on the indexed per-instance updates.
        if reason == 'reload key' or reason == 'toggle key' or reason == 'scan key' then
            ApplyAll(true)
        else
            -- Resume indexed instances whose jobs were retired during loading.
            ObjectIndex.prune(true)
        end
        -- Only retry class readiness. Construction events own per-instance updates;
        -- there are no full-tree replay passes at 2, 6 and 15 seconds.
        for _, seconds in ipairs(S.followUps) do
            if seconds > 0 then
                Defer(math.floor(seconds * 1000), function()
                    ObjectIndex.start()
                    PatchClassDefaults()
                    HookFadeFrame()
                end, false, 'class-readiness-' .. seconds)
            end
        end
        local generation = applyGeneration
        if Work.heartbeatGeneration == generation then return end
        Work.heartbeatGeneration = generation
        Heartbeat(generation)
        ForceHeartbeat(generation)
        SweepHeartbeat(generation)
        MenuSweepHeartbeat(generation)
        IdentifyBlink(generation)
        AutoFadeHeartbeat(generation)
    end, false, 'apply')
end
