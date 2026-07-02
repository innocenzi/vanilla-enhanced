local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")
local InventoryApi = VanillaEnhanced.InventoryApi

Quests.questTrackerButtons = Quests.questTrackerButtons or {}
Quests.questTrackerItemButtons = Quests.questTrackerItemButtons or {}

local hookedQuestWatch = false
local TRACKER_ITEM_BUTTON_SIZE = 18
local TRACKER_ITEM_BUTTON_SPACING = 2
local TRACKER_ITEM_BUTTON_LIMIT = 2
local TRACKER_ITEM_BUTTON_UPDATE_INTERVAL = 0.2
local TRACKER_ITEM_BUTTON_GAP_X = 6
local TRACKER_ITEM_BUTTON_OFFSET_Y = 0

local function CleanText(text)
    if not text then
        return nil
    end

    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

local function GetWatchedQuestsByTitle()
    local watched = {}

    if not GetNumQuestWatches or not GetQuestIndexForWatch or not GetQuestLogTitle then
        return watched
    end

    for watchIndex = 1, GetNumQuestWatches() do
        local questIndex = GetQuestIndexForWatch(watchIndex)
        if questIndex then
            local title, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(questIndex)
            if title and not isHeader and questId and questId > 0 then
                watched[CleanText(title)] = {
                    questId = questId,
                }
            end
        end
    end

    return watched
end

local function GetWatchedQuestId(watched, title)
    local info = watched and watched[CleanText(title)]
    if type(info) == "table" then
        return info.questId
    end
    return info
end

local function CaptureLineState(line)
    local red, green, blue, alpha
    if line.GetTextColor then
        red, green, blue, alpha = line:GetTextColor()
    end

    return {
        text = line.GetText and line:GetText() or "",
        shown = line.IsShown and line:IsShown() == true,
        red = red,
        green = green,
        blue = blue,
        alpha = alpha,
        height = line.GetHeight and line:GetHeight() or nil,
        lineAlpha = line.GetAlpha and line:GetAlpha() or nil,
    }
end

local function ApplyLineState(line, state)
    if not line then
        return
    end

    if not state or not state.shown then
        if line.SetText then
            line:SetText("")
        end
        line:Hide()
        return
    end

    if line.SetText then
        line:SetText(state.text or "")
    end
    if line.SetTextColor and state.red and state.green and state.blue then
        line:SetTextColor(state.red, state.green, state.blue, state.alpha or 1)
    end
    if line.SetAlpha and state.lineAlpha then
        line:SetAlpha(state.lineAlpha)
    end
    if line.SetHeight and state.height and state.height > 0 then
        line:SetHeight(state.height)
    end
    line:Show()
end

local function AppendLineStates(target, source)
    for _, state in ipairs(source or {}) do
        target[#target + 1] = state
    end
end

local function BuildQuestTrackerBlocks(lineStates, watched)
    local prefix = {}
    local blocks = {}
    local blocksByQuestId = {}
    local currentBlock

    for _, state in ipairs(lineStates) do
        local questId = GetWatchedQuestId(watched, state.text)
        if questId then
            currentBlock = {
                questId = questId,
                lines = { state },
            }
            blocks[#blocks + 1] = currentBlock
            blocksByQuestId[questId] = blocksByQuestId[questId] or currentBlock
        elseif currentBlock then
            currentBlock.lines[#currentBlock.lines + 1] = state
        else
            prefix[#prefix + 1] = state
        end
    end

    return prefix, blocks, blocksByQuestId
end

local function ApplyAutoFollowQuestTrackerOrder(watched)
    local order = Quests.autoFollowQuestTrackerOrder
    if not order or #order <= 1 or not QuestWatchFrame then
        return false
    end

    local lines = {}
    local lineStates = {}
    local lineIndex = 1
    while true do
        local line = _G["QuestWatchLine" .. lineIndex]
        if not line then
            break
        end
        lines[#lines + 1] = line
        if line.IsShown and line:IsShown() then
            lineStates[#lineStates + 1] = CaptureLineState(line)
        end
        lineIndex = lineIndex + 1
    end

    if #lineStates == 0 then
        return false
    end

    local prefix, blocks, blocksByQuestId = BuildQuestTrackerBlocks(lineStates, watched)
    if #blocks <= 1 then
        return false
    end

    local orderedBlocks = {}
    local orderedQuestIds = {}
    for _, questId in ipairs(order) do
        local block = blocksByQuestId[questId]
        if block then
            orderedQuestIds[questId] = true
            orderedBlocks[#orderedBlocks + 1] = block
        end
    end

    if #orderedBlocks <= 1 then
        return false
    end

    local sortedLineStates = {}
    local orderedBlockIndex = 1
    AppendLineStates(sortedLineStates, prefix)
    for _, block in ipairs(blocks) do
        if orderedQuestIds[block.questId] then
            local sortedBlock = orderedBlocks[orderedBlockIndex]
            if sortedBlock then
                AppendLineStates(sortedLineStates, sortedBlock.lines)
            end
            orderedBlockIndex = orderedBlockIndex + 1
        else
            AppendLineStates(sortedLineStates, block.lines)
        end
    end

    local changed = false
    for index, state in ipairs(sortedLineStates) do
        if lineStates[index] ~= state then
            changed = true
            break
        end
    end
    if not changed then
        return false
    end

    for index, line in ipairs(lines) do
        ApplyLineState(line, sortedLineStates[index])
    end

    return true
end

local function AcquireTrackerButton(index)
    local button = Quests.questTrackerButtons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", nil, QuestWatchFrame or UIParent)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function(self)
        if self.questId then
            Quests:OpenQuestLogToQuest(self.questId)
        end
    end)
    Quests.questTrackerButtons[index] = button
    return button
end

local function GetItemCountCompat(itemId, includeUses)
    local api = C_Item and C_Item.GetItemCount or GetItemCount
    if not api then
        return 0
    end

    local ok, count = pcall(api, itemId, false, includeUses == true)
    if ok and type(count) == "number" then
        return count
    end

    ok, count = pcall(api, itemId)
    return ok and type(count) == "number" and count or 0
end

local function GetItemSpellCompat(itemId)
    local api = C_Item and C_Item.GetItemSpell or GetItemSpell
    if not api then
        return nil
    end

    local ok, spellName = pcall(api, itemId)
    return ok and spellName or nil
end

local function GetItemCooldownCompat(itemId)
    local api = C_Item and C_Item.GetItemCooldown or GetItemCooldown
    if not api then
        return nil, nil, nil
    end

    local ok, start, duration, enabled = pcall(api, itemId)
    if ok then
        return start, duration, enabled
    end
    return nil, nil, nil
end

local function IsQuestSourceItemUsable(itemId)
    if not itemId or GetItemCountCompat(itemId, true) <= 0 then
        return false
    end

    if GetItemSpellCompat(itemId) then
        return true
    end

    local api = InventoryApi
    if api and api.IsEquippableItem then
        local ok, isEquippable = pcall(api.IsEquippableItem, api, itemId)
        if ok and isEquippable then
            return true
        end
    elseif type(IsEquippableItem) == "function" then
        local ok, isEquippable = pcall(IsEquippableItem, itemId)
        if ok and isEquippable then
            return true
        end
    end

    return false
end

local function GetItemTextureFromBags(itemId)
    if not InventoryApi or not InventoryApi.GetContainerNumSlots or not InventoryApi.GetContainerItemInfo then
        return nil
    end

    for bagID = -2, 4 do
        local slots = InventoryApi:GetContainerNumSlots(bagID)
        if slots and slots > 0 then
            for slot = 1, slots do
                local item = InventoryApi:GetContainerItemInfo(bagID, slot)
                if item and item.itemID == itemId and item.iconFileID then
                    return item.iconFileID
                end
            end
        end
    end

    return nil
end

local function GetItemTextureCompat(itemId)
    local texture = GetItemTextureFromBags(itemId)
    if texture then
        return texture
    end

    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemId)
        if ok and icon then
            return icon
        end
    end
    if type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, itemId)
        if ok and icon then
            return icon
        end
    end
    if InventoryApi and InventoryApi.GetItemInfo then
        local ok, itemInfo = pcall(InventoryApi.GetItemInfo, InventoryApi, itemId)
        if ok and itemInfo and itemInfo.texture then
            return itemInfo.texture
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function UpdateItemButtonState(button)
    if not button or not button.itemId then
        return
    end

    local charges = GetItemCountCompat(button.itemId, true)
    if button.count then
        if charges and charges > 1 then
            button.count:SetText(charges)
            button.count:Show()
        else
            button.count:SetText("")
            button.count:Hide()
        end
    end

    if button.cooldown then
        local start, duration, enabled = GetItemCooldownCompat(button.itemId)
        if enabled == 1 and duration and duration > 0 and button.cooldown.SetCooldown then
            button.cooldown:SetCooldown(start or 0, duration)
            button.cooldown:Show()
        else
            button.cooldown:Hide()
        end
    end
end

local function ConfigureTrackerItemButton(button, itemId)
    if not button or not itemId then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    button.itemId = itemId
    button:SetNormalTexture(GetItemTextureCompat(itemId))
    button:SetPushedTexture(GetItemTextureCompat(itemId))
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:SetSize(TRACKER_ITEM_BUTTON_SIZE, TRACKER_ITEM_BUTTON_SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type1", "item")
    button:SetAttribute("item1", "item:" .. itemId)
    UpdateItemButtonState(button)
    return true
end

local function AcquireTrackerItemButton(index)
    local button = Quests.questTrackerItemButtons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", nil, QuestWatchFrame or UIParent, "SecureActionButtonTemplate")
    button.icon = button:GetNormalTexture()
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button)
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    button:SetScript("OnEnter", function(self)
        if not self.itemId or not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.itemId)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    button:SetScript("OnUpdate", function(self, elapsed)
        self.updateElapsed = (self.updateElapsed or 0) + (elapsed or 0)
        if self.updateElapsed < TRACKER_ITEM_BUTTON_UPDATE_INTERVAL then
            return
        end
        self.updateElapsed = 0
        UpdateItemButtonState(self)
    end)
    button:Hide()
    Quests.questTrackerItemButtons[index] = button
    return button
end

local function HideUnusedItemButtons(firstUnusedIndex)
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    for index = firstUnusedIndex, #Quests.questTrackerItemButtons do
        local button = Quests.questTrackerItemButtons[index]
        button.itemId = nil
        button:SetAttribute("type1", nil)
        button:SetAttribute("item1", nil)
        button:Hide()
    end
end

local function HideUnusedButtons(firstUnusedIndex)
    for index = firstUnusedIndex, #Quests.questTrackerButtons do
        Quests.questTrackerButtons[index]:Hide()
        Quests.questTrackerButtons[index].questId = nil
    end
end

local function GetQuestSourceItems(questId)
    local dbQuest = VanillaEnhancedQuestsDB
        and VanillaEnhancedQuestsDB.quests
        and VanillaEnhancedQuestsDB.quests[questId]
    return dbQuest and dbQuest.si
end

local function PositionTrackerItemButton(button, line, itemOffset)
    if not button or not line or not QuestWatchFrame then
        return false
    end

    local frameLeft = QuestWatchFrame.GetLeft and QuestWatchFrame:GetLeft()
    local frameTop = QuestWatchFrame.GetTop and QuestWatchFrame:GetTop()
    local lineLeft = line.GetLeft and line:GetLeft()
    local lineTop = line.GetTop and line:GetTop()
    local lineHeight = line.GetHeight and line:GetHeight()
    if not frameLeft or not frameTop or not lineLeft or not lineTop or not lineHeight then
        return false
    end

    local x = lineLeft
        - frameLeft
        - TRACKER_ITEM_BUTTON_GAP_X
        - TRACKER_ITEM_BUTTON_SIZE
        - (itemOffset * (TRACKER_ITEM_BUTTON_SIZE + TRACKER_ITEM_BUTTON_SPACING))
    local y = lineTop
        - frameTop
        - ((lineHeight - TRACKER_ITEM_BUTTON_SIZE) / 2)
        + TRACKER_ITEM_BUTTON_OFFSET_Y

    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", QuestWatchFrame, "TOPLEFT", x, y)
    return true
end

local function AddQuestTrackerItemButtons(line, questId, itemButtonIndex)
    local sourceItems = GetQuestSourceItems(questId)
    if not sourceItems or not line then
        return itemButtonIndex
    end

    local shownForQuest = 0
    for _, itemId in ipairs(sourceItems) do
        if shownForQuest >= TRACKER_ITEM_BUTTON_LIMIT then
            break
        end
        if IsQuestSourceItemUsable(itemId) then
            local button = AcquireTrackerItemButton(itemButtonIndex)
            if ConfigureTrackerItemButton(button, itemId) then
                button:SetParent(QuestWatchFrame)
                button:SetFrameLevel((QuestWatchFrame:GetFrameLevel() or 0) + 20)
                if PositionTrackerItemButton(button, line, shownForQuest) then
                    button:Show()
                    itemButtonIndex = itemButtonIndex + 1
                    shownForQuest = shownForQuest + 1
                else
                    button:Hide()
                end
            end
        end
    end

    return itemButtonIndex
end

function Quests:RefreshQuestTrackerClicks()
    local settings = self:GetSettings()
    if not settings.enabled or not QuestWatchFrame then
        HideUnusedButtons(1)
        HideUnusedItemButtons(1)
        return
    end

    local watched = GetWatchedQuestsByTitle()
    ApplyAutoFollowQuestTrackerOrder(watched)

    if settings.enableQuestTrackerItemButtons == false or (InCombatLockdown and InCombatLockdown()) then
        HideUnusedItemButtons(1)
    end

    local itemButtonIndex = 1
    if settings.enableQuestTrackerItemButtons ~= false and not (InCombatLockdown and InCombatLockdown()) then
        local lineIndex = 1
        while true do
            local line = _G["QuestWatchLine" .. lineIndex]
            if not line then
                break
            end

            local questId = line:IsShown() and GetWatchedQuestId(watched, line:GetText()) or nil
            if questId then
                itemButtonIndex = AddQuestTrackerItemButtons(line, questId, itemButtonIndex)
            end

            lineIndex = lineIndex + 1
        end
        HideUnusedItemButtons(itemButtonIndex)
    end

    if settings.enableQuestTrackerClicks == false then
        HideUnusedButtons(1)
        return
    end

    local buttonIndex = 1
    local lineIndex = 1

    while true do
        local line = _G["QuestWatchLine" .. lineIndex]
        if not line then
            break
        end

        local questId = line:IsShown() and GetWatchedQuestId(watched, line:GetText()) or nil
        if questId then
            local button = AcquireTrackerButton(buttonIndex)
            button.questId = questId
            button:SetParent(QuestWatchFrame)
            button:SetFrameLevel((QuestWatchFrame:GetFrameLevel() or 0) + 10)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", line, "TOPLEFT", -2, 2)
            button:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 2, -2)
            button:Show()
            buttonIndex = buttonIndex + 1
        end

        lineIndex = lineIndex + 1
    end

    HideUnusedButtons(buttonIndex)
end

local function QueueRefresh()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            Quests:RefreshQuestTrackerClicks()
        end)
    else
        Quests:RefreshQuestTrackerClicks()
    end
end

local function HookQuestWatchUpdate()
    if hookedQuestWatch or not hooksecurefunc then
        return
    end

    if QuestWatch_Update then
        local ok = pcall(hooksecurefunc, "QuestWatch_Update", QueueRefresh)
        hookedQuestWatch = ok or hookedQuestWatch
    end
end

local eventFrame = CreateFrame("Frame")
local function RegisterEventIfAvailable(eventName)
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end

RegisterEventIfAvailable("PLAYER_LOGIN")
RegisterEventIfAvailable("QUEST_LOG_UPDATE")
RegisterEventIfAvailable("QUEST_WATCH_UPDATE")
RegisterEventIfAvailable("PLAYER_ENTERING_WORLD")
RegisterEventIfAvailable("BAG_UPDATE")
RegisterEventIfAvailable("BAG_UPDATE_DELAYED")
RegisterEventIfAvailable("PLAYER_EQUIPMENT_CHANGED")
RegisterEventIfAvailable("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function()
    HookQuestWatchUpdate()
    QueueRefresh()
end)

HookQuestWatchUpdate()
