function HookNewObjects()
    ObjectIndex.start()
    ObjectIndex.widget = function(obj, names)
        if not S.hookNewWidgets or not S.enabled or suspended then return end
        local chosen
        for _, spec in ipairs(rootSpecs) do
            for _, name in ipairs(names) do
                if spec.class == name then chosen = spec.key; break end
            end
            if chosen then break end
        end
        if not chosen then return end
        -- One readiness chain per instance; the upstream zero-delay retry is redundant.
        Defer(0, function()
            if not IsValidObject(obj) then return end
            TweakInstance(obj, chosen)
            for _, seconds in ipairs(S.newObjectFollowUps or {}) do
                if seconds > 0 then
                    Defer(math.floor(seconds * 1000), function()
                        if IsValidObject(obj) then TweakInstance(obj, chosen) end
                    end, false, {obj, seconds})
                end
            end
        end, false, obj)
    end
end
