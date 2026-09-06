-- Cache discovered watch widgets and subscribe to their exact class. Empty or
-- unsupported classes retain the original probe cadence until they can be watched.
local shownCache, shownHooks = {}, {}
local function AnyShown(className)
    local cache = shownCache[className]
    if cache == nil or cache.generation ~= applyGeneration then
        cache = {generation = applyGeneration, objects = {}}
        shownCache[className] = cache
    end
    if not cache.seeded or not shownHooks[className] then
        local ok, list = pcall(FindAllOf, className)
        if not ok or (list ~= nil and type(list) ~= "table") then return nil end
        cache.objects = list or {}
        cache.seeded = true
        if not shownHooks[className] and type(NotifyOnNewObject) == "function" then
            for _, obj in pairs(cache.objects) do
                if IsValidObject(obj) and not IsDefaultObject(obj) then
                    local valid, path = pcall(function()
                        local cls = obj:GetClass()
                        -- A derived-class notification cannot cover a base-class watch.
                        if cls:GetFName():ToString() ~= className then return nil end
                        return string.match(cls:GetFullName(), "^%S+ (.+)$")
                    end)
                    if valid and path then
                        local registered = pcall(NotifyOnNewObject, path, function(created)
                            -- Construction notifications may run before the widget is ready.
                            Defer(0, function()
                                local current = shownCache[className]
                                if current == nil or current.generation ~= applyGeneration then return end
                                if IsValidObject(created) and not IsDefaultObject(created) then
                                    for _, known in pairs(current.objects) do
                                        if known == created then return end
                                    end
                                    current.objects[#current.objects + 1] = created
                                end
                            end)
                        end)
                        if registered then shownHooks[className] = true end
                        break
                    end
                end
            end
        end
    end
    local live, shown = {}, false
    for _, obj in pairs(cache.objects) do
        if IsValidObject(obj) and not IsDefaultObject(obj) then
            live[#live + 1] = obj
            if not shown and WidgetIsShown(obj) then shown = true end
        end
    end
    cache.objects = live
    return shown
end
