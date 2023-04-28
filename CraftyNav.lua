local MY_NAME, MY_GLOBALS = ...

local CraftyNav = {
    itemToRecipeIdMapping = {}
}
local DEBUG = MY_GLOBALS.DEBUG
local CONSTANTS = MY_GLOBALS.CONSTANTS

function isTradeSkillUiReady()
    local isReady = C_TradeSkillUI.IsTradeSkillReady()
    local professionName = C_TradeSkillUI.GetBaseProfessionInfo().professionName or "UNKNOWN"
    DEBUG.print(professionName.." C_TradeSkillUI.IsTradeSkillReady() = "..tostring(isReady))
    return isReady
end

function isProfessionDataInitialized(professionName)
    assert(professionName)
    return (CraftyNav.itemToRecipeIdMapping[professionName] and true) or false
end

function getCurrentProfessionName()
    local professionName = C_TradeSkillUI.GetBaseProfessionInfo().professionName
    return professionName
end

function getRecipeId(professionName, itemID)
    local map = CraftyNav.itemToRecipeIdMapping[professionName]
    if (not map) then return end
    return map[itemID]
end

function addRecipeId(professionName, itemID, recipeId)
    CraftyNav.itemToRecipeIdMapping[professionName][itemID] = recipeId
end

function createItemToRecipeIdMapping()
    if (not isTradeSkillUiReady()) then return end
    local professionName = C_TradeSkillUI.GetBaseProfessionInfo().professionName
    if (CraftyNav.itemToRecipeIdMapping[professionName]) then
        DEBUG.print("Ignoring "..professionName)
        return
    end
    DEBUG.print("Initializing "..professionName)

    CraftyNav.itemToRecipeIdMapping[professionName] = {}
    local recipeIds = C_TradeSkillUI.GetAllRecipeIDs()

    for i, recipeId in ipairs(recipeIds) do
        local foo = C_TradeSkillUI.GetRecipeOutputItemData(recipeId)
        local itemID = foo and foo.itemID
        if (itemID) then addRecipeId(professionName,itemID,recipeId) end
    end
end

--ProfessionsFrame.CraftingPage.RecipeList:HookScript("OnShow", createItemToRecipeIdMapping)
ProfessionsFrame.CraftingPage:HookScript("OnShow", createItemToRecipeIdMapping)
-- OnShow isn't reliable because you can switch between professions while the frame is still SHOWn

-- local listener = CreateFrame("Frame");
-- listener:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE"); -- nope
-- listener:SetScript("OnEvent", DEBUG.messengerForEvent("TRADE_SKILL_DETAILS_UPDATE","Frame listener"))
-- listener:SetScript("OnEvent", createItemToRecipeIdMapping)

function enhanceReagentsButtonsAddNavClicks()
    createItemToRecipeIdMapping() -- workaround for OnShow not firing when switching between professions (see above)
    local professionName = getCurrentProfessionName()
    if (not isProfessionDataInitialized(professionName)) then return end
    local reagentTree = ProfessionsFrame.CraftingPage.SchematicForm.Reagents:GetLayoutChildren()
    for i, reagent in ipairs(reagentTree) do
        local button = reagent.Button
        local craftInfo = reagent.reagentSlotSchematic
        
        -- PROBLEM:
        -- I was expecting each new recipe refresh to instantiate fresh buttons. 
        -- but instead, the UI recycles buttons leaving my hooks intact. 
        -- SOLUTION: 
        -- hook the code once,
        -- store the recipeId in the button in a named field
        -- and have the code refer to it

        -- The Bliz UI recycles the existing buttons for a recipe and reuses them when the user picks a new recipe.
        -- So, I can't embed the ID as a closure value in the button hooks itself.
        -- I must store/update the id on the button and have the hook reference it.
        if (button and craftInfo) then
            local itemID = craftInfo.reagents[1].itemID
            local recipeId = getRecipeId(professionName,itemID)
            local buttonLabel = "BUTTON "..i.." itemID#"..itemID.." <-> recipeId#"..(recipeId or "UNKNOWN")
            DEBUG.print(buttonLabel)
            button[CONSTANTS.RECIPE_ID] = recipeId
            if (recipeId) then
                local isAlreadyHooked = button and button[CONSTANTS.IS_HOOKED]
                if (not isAlreadyHooked) then
                    button:SetScript("PostClick", function(widget, whichMouseButtonStr, isPressed)
                        local recipeIdFromButton = button[CONSTANTS.RECIPE_ID]
                        DEBUG.print("You PostClicked me with "..whichMouseButtonStr.. " itemID#"..itemID.. " recipeIdFromButton#"..(recipeIdFromButton or "NONE"))
                        local isRightClick = (whichMouseButtonStr == "RightButton")
                        if (recipeIdFromButton and isRightClick) then
                            ProfessionsFrame.CraftingPage.RecipeList.SearchBox:SetText("")
                            C_TradeSkillUI.SetRecipeItemNameFilter(nil)
                            PlaySound(SOUNDKIT.UI_PROFESSION_FILTER_MENU_OPEN_CLOSE);
                            C_TradeSkillUI.OpenRecipe(recipeIdFromButton)
                        end
                    end)
                    button[CONSTANTS.IS_HOOKED] = true
                end
            end
        end
    end
end

function enhanceRecipeHeaderAddNavClicks()
    local button = ProfessionsFrame.CraftingPage.SchematicForm.OutputIcon

    if (button) then
        local isAlreadyHooked = button and button[CONSTANTS.IS_HOOKED]
        if (not isAlreadyHooked) then
            button:SetScript("PostClick", function(widget, whichMouseButtonStr, isPressed)
                local name = ProfessionsFrame.CraftingPage.SchematicForm.recipeSchematic.name
                local isRightClick = (whichMouseButtonStr == "RightButton")
                if (name and isRightClick) then
                    ProfessionsFrame.CraftingPage.RecipeList.SearchBox:SetText(name)
                    C_TradeSkillUI.SetRecipeItemNameFilter(name)
                    PlaySound(SOUNDKIT.UI_PROFESSION_FILTER_MENU_OPEN_CLOSE);
                end
            end)
            button[CONSTANTS.IS_HOOKED] = true
        end
    end
end

function init()
    enhanceRecipeHeaderAddNavClicks()
    enhanceReagentsButtonsAddNavClicks()
end

ProfessionsFrame.CraftingPage.RecipeList.selectionBehavior:RegisterCallback("OnSelectionChanged", init, ProfessionsFrame.CraftingPage)
