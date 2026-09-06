-- Construction-driven index. No global object-array searches, including empty watches.
-- Captured objects are checked later, after construction, on the game thread.
local ObjectIndex = {classes = {}, entries = {}, hooks = {}, pending = {}, attempts = {}, owner = nil, world = nil}
local function SameOwner(a, b)
    return a == b or (a:IsValid() and b:IsValid() and a:GetAddress() == b:GetAddress())
end
local function CurrentEntry(entry)
    local ok, live = pcall(function()
        return entry.obj:IsValid()
            and (not entry.world or not ObjectIndex.world or SameOwner(entry.world, ObjectIndex.world))
            and (not entry.owner or not ObjectIndex.owner or SameOwner(entry.owner, ObjectIndex.owner))
    end)
    return ok and live
end
local function IndexedWorld(obj)
    for _ = 1, 8 do
        if not obj or not obj:IsValid() then return nil end
        if obj:GetClass():GetFName():ToString() == 'World' then return obj end
        obj = obj:GetOuter()
    end
end
function ObjectIndex.add(obj)
    BudgetStep()
    local ok, names, world, owner = pcall(function()
        if not obj or not obj:IsValid() then return nil end
        local full = obj:GetFullName()
        if string.find(full, 'Default__', 1, true) then return nil end
        local chain, cls, isWidget = {}, obj:GetClass(), false
        for _ = 1, 32 do
            if not cls or not cls:IsValid() then break end
            local name = cls:GetFName():ToString()
            chain[#chain + 1] = name
            if name == 'UserWidget' then isWidget = true end
            cls = cls:GetSuperStruct()
        end
        local hasWorld, w = pcall(IndexedWorld, obj)
        if not hasWorld then w = nil end
        local player
        if isWidget then
            local hasOwner, candidate = pcall(function() return obj:GetOwningPlayer() end)
            if hasOwner and candidate and candidate:IsValid() then player = candidate end
        end
        return chain, w, player
    end)
    if not ok or not names then return end
    local entry = {obj = obj, world = world, owner = owner, names = names}
    if not CurrentEntry(entry) then return end
    ObjectIndex.entries[obj] = entry
    for _, name in ipairs(names) do
        local list = ObjectIndex.classes[name]
        if not list then list = {}; ObjectIndex.classes[name] = list end
        list[obj] = entry
    end
    if ObjectIndex.widget then
        for _, name in ipairs(names) do
            if name == 'UserWidget' then ObjectIndex.widget(obj, names); break end
        end
    end
end
function ObjectIndex.capture(obj)
    ObjectIndex.pending[obj] = true
    Defer(0, function()
        while next(ObjectIndex.pending) do
            BudgetStep()
            local object = next(ObjectIndex.pending)
            ObjectIndex.pending[object] = nil
            ObjectIndex.add(object)
        end
    end, false, 'object-index', true)
end
function ObjectIndex.get(name)
    local result, list = {}, ObjectIndex.classes[name]
    if not list then return result end
    for obj, entry in pairs(list) do
        BudgetStep()
        if CurrentEntry(entry) then result[#result + 1] = obj else list[obj] = nil end
    end
    return result
end
function ObjectIndex.prune(replay)
    for obj, entry in pairs(ObjectIndex.entries) do
        BudgetStep()
        if not CurrentEntry(entry) then
            ObjectIndex.entries[obj] = nil
            for _, name in ipairs(entry.names) do ObjectIndex.classes[name][obj] = nil end
        elseif replay and ObjectIndex.widget then
            ObjectIndex.widget(obj, entry.names)
        end
    end
end
function ObjectIndex.context(controller)
    local ok, localPlayer = pcall(function() return controller:IsValid() and controller:IsLocalController() end)
    if not ok or not localPlayer then return end
    ObjectIndex.attempts = {}
    ObjectIndex.owner = controller
    local found, world = pcall(IndexedWorld, controller)
    ObjectIndex.world = found and world or nil
    ObjectIndex.capture(controller)
    local valid, pawn = pcall(function() return controller.Pawn end)
    if valid and pawn then ObjectIndex.capture(pawn) end
end
function ObjectIndex.start()
    for _, path in ipairs({'/Script/UMG.UserWidget', '/Script/Engine.PlayerController',
        '/Script/Engine.WorldSubsystem', '/Script/Engine.GameInstanceSubsystem'}) do
        if not ObjectIndex.hooks[path] and (ObjectIndex.attempts[path] or 0) < 3 then
            ObjectIndex.attempts[path] = (ObjectIndex.attempts[path] or 0) + 1
            ObjectIndex.hooks[path] = pcall(NotifyOnNewObject, path, ObjectIndex.capture)
            if not ObjectIndex.hooks[path] and ObjectIndex.attempts[path] == 3 then
                Log('HUD discovery unavailable for %s; check UE4SS compatibility.', path)
            end
        end
    end
end
-- All existing lookups now use the index, including player/subsystem recovery.
local FindAllOf = ObjectIndex.get
