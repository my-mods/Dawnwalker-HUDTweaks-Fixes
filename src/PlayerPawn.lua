-- Local compatibility backport: revalidate possession even while an old pawn is
-- a valid UObject. No controller input, compass hooks, or additional timers.
local compatibilityController = nil
local compatibilityLookupWarning = nil
local function PlayerPawn()
    local function controls(candidate, pawn)
        if not IsValidObject(candidate) or not IsValidObject(pawn) then return false end
        local ok, result = pcall(function()
            local name = pawn:GetFullName()
            return not IsDefaultObject(candidate) and not IsDefaultObject(pawn)
                and candidate:IsLocalController() == true
                and IsValidObject(candidate.Pawn)
                and type(name) == "string" and name ~= ""
                and candidate.Pawn:GetFullName() == name
        end)
        return ok and result == true
    end
    if controls(compatibilityController, fadePlayer) then return fadePlayer end
    fadePlayer, compatibilityController = nil, nil

    local function find(className)
        local ok, objects = pcall(FindAllOf, className)
        if ok and objects == nil then return {} end
        if not ok or type(objects) ~= "table" then
            local reason = className .. ": " .. (ok and type(objects) or "lookup failed")
            if compatibilityLookupWarning ~= reason then
                Log("COMPAT: player lookup unavailable (%s); retrying on next probe", reason)
                compatibilityLookupWarning = reason
            end
            return nil
        end
        return objects
    end
    local pawns = find(PLAYER_CLASS)
    if pawns == nil then return nil end
    local controllers = find("PlayerController")
    if controllers == nil then return nil end
    compatibilityLookupWarning = nil
    for _, pawn in pairs(pawns) do
        for _, candidate in pairs(controllers) do
            if controls(candidate, pawn) then
                fadePlayer, compatibilityController = pawn, candidate
                return fadePlayer
            end
        end
    end
    return nil
end
