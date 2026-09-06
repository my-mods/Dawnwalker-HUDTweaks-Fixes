local function AnyShown(className)
    for _, obj in ipairs(ObjectIndex.get(className)) do
        BudgetStep()
        if IsValidObject(obj) and not IsDefaultObject(obj) and WidgetIsShown(obj) then return true end
    end
    return false
end
