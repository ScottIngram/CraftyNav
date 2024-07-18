local ADDON_NAME, CraftyNav = ...
local debug = CraftyNav.DEBUG.newDebugger(CraftyNav.DEBUG.ERROR)

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

CraftyNav.CONSTANTS = {
    IS_HOOKED = ADDON_NAME ..".IS_HOOKED",
    RECIPE_ID = ADDON_NAME ..".RECIPE_ID",
}
local CONSTANTS = CraftyNav.CONSTANTS

-------------------------------------------------------------------------------
-- CraftyNav Data
-------------------------------------------------------------------------------

CraftyNav.NAMESPACE = {}
CraftyNav.EventHandlers = {}
CraftyNav.itemToRecipeIdMapping = {}
CraftyNav.originalScripts = {}

-------------------------------------------------------------------------------
-- Namespace Manipulation
--
-- Leverage Lua's setfenv to restrict all of my declarations to my own private "namespace"
-- Now, I can create "Local" functions without needing the local keyword
-------------------------------------------------------------------------------

local _G = _G -- but first, grab the global namespace or else we lose it
setmetatable(CraftyNav.NAMESPACE, { __index = _G }) -- inherit all member of the Global namespace
setfenv(1, CraftyNav.NAMESPACE)

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

local EventHandlers = CraftyNav.EventHandlers -- just for shorthand

function EventHandlers:ADDON_LOADED(addonName)
    if addonName == ADDON_NAME then
        debug.trace:print("ADDON_LOADED", addonName)
    end

    if addonName == "Blizzard_Professions" then
        -- this happens when the user opens up a professions window
        -- until then, the UI knows nothing about the ProfessionsFrame and will just throw errors if we try to do anything
        initalizeAddonStuff()
    end
end

function EventHandlers:PLAYER_LOGIN()
    debug.trace:print("PLAYER_LOGIN")
end

function EventHandlers:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    debug.trace:out("",1,"PLAYER_ENTERING_WORLD", "isInitialLogin",isInitialLogin, "isReloadingUi",isReloadingUi)
end

-------------------------------------------------------------------------------
-- Event Handler Registration
-------------------------------------------------------------------------------

function createEventListener(targetSelfAsProxy, eventHandlers)
    debug.info:print(ADDON_NAME .. " EventListener:Activate() ...")

    local dispatcher = function(listenerFrame, eventName, ...)
        -- ignore the listenerFrame and instead
        eventHandlers[eventName](targetSelfAsProxy, ...)
    end

    local eventListenerFrame = CreateFrame("Frame")
    eventListenerFrame:SetScript("OnEvent", dispatcher)

    for eventName, _ in pairs(eventHandlers) do
        debug.info:print("EventListener:activate() - registering " .. eventName)
        eventListenerFrame:RegisterEvent(eventName)
    end
end

-------------------------------------------------------------------------------
-- Tradeskill Utility Functions and Methods
-------------------------------------------------------------------------------

function initProfData()
    CraftyNav:createItemToRecipeIdMapping()
end

function isTradeSkillUiReady()
    local isReady = C_TradeSkillUI.IsTradeSkillReady()
    local professionName = C_TradeSkillUI.GetBaseProfessionInfo().professionName or "UNKNOWN"
    debug.info:print(professionName.." C_TradeSkillUI.IsTradeSkillReady() = "..tostring(isReady))
    return isReady
end

function getCurrentProfessionName()
    local professionName = C_TradeSkillUI.GetBaseProfessionInfo().professionName
    return professionName
end

function CraftyNav:isProfessionDataInitialized(professionName)
    assert(professionName)
    return (self.itemToRecipeIdMapping[professionName] and true) or false
end

function CraftyNav:getRecipeId(professionName, itemID)
    local map = self.itemToRecipeIdMapping[professionName]
    if (not map) then return end
    return map[itemID]
end

function CraftyNav:addRecipeId(professionName, itemID, recipeId)
    self.itemToRecipeIdMapping[professionName][itemID] = recipeId
end

function CraftyNav:createItemToRecipeIdMapping()
    if (not isTradeSkillUiReady()) then return end
    local professionName = C_TradeSkillUI.GetBaseProfessionInfo().professionName
    if (self.itemToRecipeIdMapping[professionName]) then
        debug.trace:print("Already scanned so skipping: "..professionName)
        return
    end
    debug.info:print("Initializing "..professionName)

    self.itemToRecipeIdMapping[professionName] = {}
    local recipeIds = C_TradeSkillUI.GetAllRecipeIDs()

    for i, recipeId in ipairs(recipeIds) do
        local foo = C_TradeSkillUI.GetRecipeOutputItemData(recipeId)
        local itemID = foo and foo.itemID
        if (itemID) then self:addRecipeId(professionName,itemID,recipeId) end
    end
end

-------------------------------------------------------------------------------
-- Tooltip Functions
-------------------------------------------------------------------------------

-- this is only needed because the recipe header
-- doesn't play by the same rules as the reagents
-- even though both claim to be buttons

local global_craft_header_bonus_tooltip_text -- this is sooooo lame

function addHelpTextToToolTip(tooltip, data)
    if tooltip == GameTooltip then
        local itemId = data.id or "none"
        debug.info:out("@",3, "addHelpTextToToolTip","itemId",itemId)
        if (global_craft_header_bonus_tooltip_text) then
            GameTooltip:AddLine(global_craft_header_bonus_tooltip_text, 0, 1, 0)
        end
    end
end

-------------------------------------------------------------------------------
-- Hooking Utility Functions and Methods
-------------------------------------------------------------------------------

-- check to see if the named script ("OnClick" for example)
-- that is currently attached to the given frame object
-- is actually the code in the myHook arg
function isMyHook(frame, scriptName, myHook)
    local currentFunc = frame:GetScript(scriptName)
    return currentFunc == myHook
end

function CraftyNav:rememberCurrentScript(frame, scriptName)
    vivify(self.originalScripts, frame, scriptName)
    self.originalScripts[frame][scriptName] = frame:GetScript(scriptName)
end

function CraftyNav:callPreviousCallback(frame, scriptName)
    local func = self.originalScripts[frame][scriptName]
    func(headerBtn)
end

-------------------------------------------------------------------------------
-- Hooking for Tradeskill UI Recipe Header
-- add nav clicks and tooltipy OnEnter enhancements
-------------------------------------------------------------------------------

function fixHeader()
    local headerBtn = ProfessionsFrame.CraftingPage.SchematicForm.OutputIcon
    if (headerBtn) then
        debug.info:out("#",5, "header checking callbacks")

        -- PostClick
        if not isMyHook(headerBtn, "PostClick", headerCallbackForPostClick) then
            debug.info:out("#",7, "header SetScript PostClick")
            headerBtn:SetScript("PostClick", headerCallbackForPostClick)
        end

        -- OnEnter
        if not isMyHook(headerBtn, "OnEnter", headerCallbackForOnEnter) then
            debug.info:out("#",7, "header SetScript OnEnter","headerBtn",headerBtn)
            CraftyNav:rememberCurrentScript(headerBtn, "OnEnter")
            headerBtn:SetScript("OnEnter", headerCallbackForOnEnter)
        end

        -- OnLeave
        if not isMyHook(headerBtn, "OnLeave", headerCallbackForOnLeave) then
            debug.info:out("#",7, "header SetScript OnLeave","headerBtn",headerBtn)
            CraftyNav:rememberCurrentScript(headerBtn, "OnLeave")
            headerBtn:SetScript("OnLeave", headerCallbackForOnLeave)
        end
    end
end

-------------------------------------------------------------------------------
-- Callbacks for Tradeskill UI Header
-------------------------------------------------------------------------------

function headerCallbackForPostClick(headerBtn, whichMouseButtonStr, isPressed)
    local name = ProfessionsFrame.CraftingPage.SchematicForm.recipeSchematic.name
    debug.info:out("#",7, "You PostClicked me with", "whichMouseButtonStr", whichMouseButtonStr, "name",name)
    local isRightClick = (whichMouseButtonStr == "RightButton")
    if (name and isRightClick) then
        ProfessionsFrame.CraftingPage.RecipeList.SearchBox:SetText(name)
        C_TradeSkillUI.SetRecipeItemNameFilter(name)
        PlaySound(SOUNDKIT.UI_PROFESSION_FILTER_MENU_OPEN_CLOSE);
    end
end

function headerCallbackForOnEnter(headerBtn)
    local name = ProfessionsFrame.CraftingPage.SchematicForm.recipeSchematic.name
    local text = CraftyNav.L10N.TOOLTIP_HEADER .. name .. (CraftyNav.L10N.TOOLTIP_HEADER_POST or "")
    debug.info:out("#",7, "Enter header!", "TOOLTIP_HEADER",text)

    -- Unlike the callback for the Reagent Buttons which successfully used the following API calls, not here!
    -- No matter what order, nor matter how much I begged or cried, the following never affected the tooltip.
    --CraftyNav:callPreviousCallback(headerBtn, "OnEnter")
    --GameTooltip:AddLine(text, 0, 1, 0)
    --GameTooltip:Show()
    -- So, instead I have to stuff text into global_craft_header_bonus_tooltip_text
    global_craft_header_bonus_tooltip_text = text
    CraftyNav:callPreviousCallback(headerBtn, "OnEnter")
end

function headerCallbackForOnLeave(headerBtn)
    debug.info:out("#",7, "LEAVE header!")
    global_craft_header_bonus_tooltip_text = nil
    CraftyNav:callPreviousCallback(headerBtn, "OnLeave")
end

-------------------------------------------------------------------------------
-- Hooking for Tradeskill UI Reagent Buttons
-- add nav clicks and tooltipy OnEnter enhancements
-------------------------------------------------------------------------------

function fixReagents()
    CraftyNav:createItemToRecipeIdMapping() -- workaround for OnShow not firing when switching between professions (see above)
    local professionName = getCurrentProfessionName()
    if (not CraftyNav:isProfessionDataInitialized(professionName)) then return end

    local reagentTree = ProfessionsFrame.CraftingPage.SchematicForm.Reagents:GetLayoutChildren()
    for i, reagent in ipairs(reagentTree) do
        local reagentBtn = reagent.Button
        local craftInfo = reagent.reagentSlotSchematic

        -- PROBLEM:
        -- I was expecting each new recipe refresh to instantiate fresh buttons.
        -- but instead, the UI recycles buttons leaving my hooks intact, but now with stale closure data.
        -- SOLUTION:
        -- hook the code once (unless it gets clobbered, then reattach it)
        -- but do not rely on closure scoping
        -- instead store the recipeId in the button in a named field
        -- and have the callback refer to it that way

        if (reagentBtn and craftInfo) then
            local itemID = craftInfo.reagents[1].itemID
            local recipeId = CraftyNav:getRecipeId(professionName, itemID)
            debug.info:out(">",5, "BUTTON", "i", i, "itemID",itemID, "recipeId",recipeId, "buttonLabel", buttonLabel)
            reagentBtn[CONSTANTS.RECIPE_ID] = recipeId
            if recipeId then

                -- PostClick
                if not isMyHook(reagentBtn, "PostClick", reagentCallbackForPostClick) then
                    debug.info:out("#",7, "reagent SetScript PostClick")
                    reagentBtn:SetScript("PostClick", reagentCallbackForPostClick)
                end

                -- OnEnter
                if not isMyHook(reagentBtn, "OnEnter", reagentCallbackForOnEnter) then
                    debug.info:out("#",7, "reagent SetScript OnEnter", "reagentBtn",reagentBtn)
                    CraftyNav:rememberCurrentScript(reagentBtn, "OnEnter")
                    reagentBtn:SetScript("OnEnter", reagentCallbackForOnEnter)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Callbacks for Tradeskill Reagent Buttons
-------------------------------------------------------------------------------

function reagentCallbackForPostClick(reagentBtn, whichMouseButtonStr, isPressed)
    local recipeIdFromButton = reagentBtn[CONSTANTS.RECIPE_ID]
    local isRightClick = (whichMouseButtonStr == "RightButton")
    debug.info:out(">",7, "You PostClicked me with", "whichMouseButtonStr", whichMouseButtonStr, "recipeIdFromButton",recipeIdFromButton, "isRightClick",isRightClick)
    if (recipeIdFromButton and isRightClick) then
        ProfessionsFrame.CraftingPage.RecipeList.SearchBox:SetText("")
        C_TradeSkillUI.SetRecipeItemNameFilter(nil)
        PlaySound(SOUNDKIT.UI_PROFESSION_FILTER_MENU_OPEN_CLOSE);
        C_TradeSkillUI.OpenRecipe(recipeIdFromButton)
        pushHistory(recipeIdFromButton)
    end
end

function reagentCallbackForOnEnter(reagentBtn)
    debug.info:out(">",7, "Enter reagent!", "TOOLTIP_REAGENT",CraftyNav.L10N.TOOLTIP_REAGENT)
    CraftyNav:callPreviousCallback(reagentBtn, "OnEnter")
    GameTooltip:AddLine(CraftyNav.L10N.TOOLTIP_REAGENT, 0, 1, 0)
    GameTooltip:Show()
end

-------------------------------------------------------------------------------
-- Sounds
-------------------------------------------------------------------------------

---@class SND
SND = {
    DELETE   = SOUNDKIT.IG_CHAT_SCROLL_UP,
    KEYPRESS = SOUNDKIT.IG_MINIMAP_ZOOM_IN, -- IG_CHAT_SCROLL_DOWN
    ENTER    = SOUNDKIT.IG_CHAT_BOTTOM,
    NAV_INTO = SOUNDKIT.IG_ABILITY_PAGE_TURN, -- IG_QUEST_LOG_OPEN, --  IG_MAINMENU_OPTION
    NAV_OUTOF= SOUNDKIT.IG_ABILITY_PAGE_TURN, -- IG_QUEST_LOG_OPEN, --  IG_MAINMENU_OPTION
    OPEN     = SOUNDKIT.IG_SPELLBOOK_OPEN, -- IG_BACKPACK_OPEN, -- IG_MAINMENU_OPTION_CHECKBOX_OFF
    CLOSE    = SOUNDKIT.IG_SPELLBOOK_CLOSE, -- IG_CHARACTER_INFO_CLOSE, -- IG_MAINMENU_OPTION_CHECKBOX_ON
    SCROLL_UP = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
    SCROLL_DOWN = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
}
play = PlaySound

-------------------------------------------------------------------------------
-- Naqvigation History & array routines
-------------------------------------------------------------------------------

local backBtn, forwardBtn
local history = {}
local historyPointer = nil

function pushHistory(recipeId, x, y, z)
    debug.info:print("historyPointer",historyPointer, "#history",#history, "recipeId",recipeId, "x",x, "y",y, "z",z)
    if history then debug.trace:dump(history) end

    -- ignore dupe IDs
    if history and history[historyPointer] == recipeId then return end

    if not historyPointer then
        historyPointer = 0
    end
    historyPointer = historyPointer + 1
    arrayTruncate(history, historyPointer)
    history[historyPointer] = recipeId

    if history then debug.trace:dump(history) end

    updateButtonStates()
end

function arrayTruncate(array, n)
    if n ~= #array then
        for i = #array, n, -1 do
            array[i] = nil
        end
    end
end

function historyRewind()
    debug.info:print("historyPointer",historyPointer, "#history",#history)
    if history then debug.trace:dump(history) end

    historyPointer = historyPointer - 1

    if not historyPointer or historyPointer < 1 then
        historyPointer = 0
        return nil
    end

    local result = history[historyPointer]
    openRecipe(result)
    play(SND.KEYPRESS)
    updateButtonStates()
    return result
end

function historyForward()
    debug.info:print("historyPointer",historyPointer, "#history",#history)
    if history then debug.trace:dump(history) end

    if not historyPointer or historyPointer == #history then
        return nil
    end

    historyPointer = historyPointer + 1

    local result = history[historyPointer]
    openRecipe(result)
    play(SND.ENTER)
    updateButtonStates()
    return result
end

function openRecipe(recipeId)
    if not recipeId then return end
    C_TradeSkillUI.OpenRecipe(recipeId)
end

-------------------------------------------------------------------------------
-- Naqvigation "Back" and "Forward" Buttons
-------------------------------------------------------------------------------

local pi = 3.14159265359
local p90 = pi / 2
local p270 = 3 * pi / 2

function createNavButtons()
    local backBtnFrameName = ADDON_NAME .. "_BackBtn"
    backBtn = _G[backBtnFrameName]
    if backBtn then -- we've already made it
        return
    end

    backBtn = makeNavButton("BackBtn")
    forwardBtn = makeNavButton("FrontBtn", backBtn)

end

function makeNavButton(name, previousBtn)
    name = ADDON_NAME .. name
    local btn = _G[name]
    if btn then -- we've already made it
        return
    end

    local blizProfWindow = ProfessionsFrame
    local blizIconFrame = ProfessionsFramePortrait
    assert(blizIconFrame, "can't find ProfessionsFramePortrait")

    local isForwardButton = previousBtn and true or false

    btn = CreateFrame("Button", name,  blizProfWindow, "UIPanelScrollUpButtonTemplate")
    btn:SetPoint("BOTTOMLEFT", previousBtn or blizIconFrame, "BOTTOMRIGHT", 0, 0)
    btn:SetFrameStrata(blizProfWindow:GetFrameStrata())
    btn:SetFrameLevel(blizProfWindow:GetFrameLevel()+1 )
    btn:RegisterForClicks("AnyUp")

    local rotation = isForwardButton and p270 or p90
    btn.Normal:SetRotation(rotation)
    btn.Pushed:SetRotation(rotation)
    btn.Disabled:SetRotation(rotation)
    btn.Highlight:SetRotation(rotation)

    local callback = isForwardButton and historyForward or historyRewind
    btn:SetScript("OnClick", callback)
    btn:SetEnabled(false)
    btn:Show()

    return btn
end

function updateButtonStates()
    local canBack = historyPointer and historyPointer > 1
    local canForward = historyPointer and historyPointer < #history
    backBtn:SetEnabled(canBack)
    forwardBtn:SetEnabled(canForward)
    debug.trace:print("canBack",canBack, "canForward",canForward)
end


-------------------------------------------------------------------------------
-- CraftyNav utils
-------------------------------------------------------------------------------

-- ensure the data structure is ready to store values at the given coordinates
function vivify(matrix, x, y)
    if not matrix then matrix = {} end
    if not matrix[x] then matrix[x] = {} end
    --if not matrix[x][y] then matrix[x][y] = {} end
    -- TODO: automate this so it can support any depth
    return matrix
end

-------------------------------------------------------------------------------
-- Tradeskill UI initialization
-------------------------------------------------------------------------------

function handleRecipeListPick(o, node, isSelected)
    if not isSelected then return end
    fixHeader()
    fixReagents()
    local recipe = node and node.data and node.data.recipeInfo and node.data.recipeInfo.recipeID
    if recipe then
        pushHistory(recipe)
    end
end

-------------------------------------------------------------------------------
-- Addon Lifecycle
-------------------------------------------------------------------------------


function initalizeAddonStuff()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addHelpTextToToolTip) -- TooltipDataProcessor.AllTypes
    ProfessionsFrame.CraftingPage:HookScript("OnShow", initProfData)
    ProfessionsFrame.CraftingPage.RecipeList.selectionBehavior:RegisterCallback("OnSelectionChanged", handleRecipeListPick)
    createNavButtons()
end

-------------------------------------------------------------------------------
-- OK, Go for it!
-------------------------------------------------------------------------------

createEventListener(CraftyNav, CraftyNav.EventHandlers)

