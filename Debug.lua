local MY_NAME, MY_GLOBALS = ...

-- /dump C_TradeSkillUI.OpenRecipe(310526)
-- DevTools_Dump({"fun","yay"})
-- Blizzard_ProfessionsRecipeList -> OnSelectionChanged(o, elementData, selected)

MY_GLOBALS.DEBUG = {}
local DEBUG = MY_GLOBALS.DEBUG
DEBUG.OFF = true

function DEBUG.dump(...)
    if (DEBUG.OFF) then return end
    DevTools_Dump(...)
    --print(MY_GLOBALS.inspect(...))
end

function DEBUG.print(...)
    if (DEBUG.OFF) then return end
    print(...)
end

function DEBUG.getName(obj, default)
    if(obj and obj.GetName) then
        return obj:GetName() or default or "UNKNOWN"
    end
    return default or "UNNAMED"
end

function DEBUG.messengerForEvent(eventName, msg)
    return function(obj)
        if (DEBUG.OFF) then return end
        print(DEBUG.getName(obj,eventName).." said ".. msg .."! ")
    end
end

function DEBUG.makeDummyStubForCallback(obj, eventName, msg)
    DEBUG.print("makeDummyStubForCallback for " .. eventName)
    obj:RegisterEvent(eventName);
    obj:SetScript("OnEvent", DEBUG.messengerForEvent(eventName,msg))

end

function DEBUG.run(callback)
    if (DEBUG.OFF) then return end
    callback()
end

function DEBUG.dumpKeys(obj)
    if (DEBUG.OFF) then return end
    pcall(function(object)
        for k, v in pairs(object or {}) do
            DEBUG.print(DEBUG.asString(k).." <-> ".. DEBUG.asString(v))
        end
    end, obj)
end

function DEBUG.asString(v)
    return ((type(v) == "string") and v) or tostring(v) or "NiL"
end
