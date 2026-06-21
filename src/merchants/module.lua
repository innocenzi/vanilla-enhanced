local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:CreateModule("merchants", VanillaEnhanced:T("module.merchants"))

local AUTO_SELL_LIMIT = 12
local MERCHANT_OPEN_REFRESH_SECONDS = 2.0
local BUTTON_SIZE = 24
local BUTTON_SPACING = 4
local HIGHLIGHT_INSET = 2
local HIGHLIGHT_MAX_BUTTONS = 100
local SELL_SCRAPS_ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local MARK_SCRAPS_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local defaults = {
    enabled = true,
    sellScrapsEnabled = true,
    autoSellScraps = false,
    autoRepair = false,
    safeManualSell = true,
    safeAutoSell = true,
    sortBagsAfterSellingScraps = false,
    scrapStrategy = "poor-sellable",
    customScrapItemIds = {},
}

local eventFrame = CreateFrame("Frame")
local refreshFrame = CreateFrame("Frame")
Merchants.eventFrame = eventFrame
Merchants.scrapStrategies = Merchants.scrapStrategies or {}
Merchants.scrapStrategyOrder = Merchants.scrapStrategyOrder or {}
Merchants.merchantOpen = false
Merchants.refreshRemaining = 0
Merchants.pendingAutoSellScraps = false
Merchants.pendingAutoRepair = false
Merchants.scrapMarkMode = false

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function IsShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function GetContainerFrameCount()
    if type(NUM_CONTAINER_FRAMES) == "number" then
        return NUM_CONTAINER_FRAMES
    end
    return 13
end

local function FormatMoney(value)
    if type(GetCoinTextureString) == "function" then
        return GetCoinTextureString(value or 0)
    end
    if type(GetMoneyString) == "function" then
        return GetMoneyString(value or 0, true)
    end
    return tostring(value or 0)
end

local function IsSellableScrapCandidate(itemContext)
    return itemContext
        and itemContext.isLocked ~= true
        and itemContext.isQuestItem ~= true
        and (itemContext.sellPrice or 0) > 0
end

function Merchants:GetSettings()
    return VanillaEnhanced:GetModuleSettings("merchants", defaults)
end

function Merchants:IsSellScrapsEnabled()
    local settings = self:GetSettings()
    return settings.enabled ~= false and settings.sellScrapsEnabled ~= false
end

function Merchants:IsMerchantOpen()
    return self.merchantOpen == true
end

function Merchants:GetSellLimit(safeEnabled)
    return safeEnabled and AUTO_SELL_LIMIT or nil
end

function Merchants:CanSortBagsAfterSellingScraps()
    if self:GetSettings().sortBagsAfterSellingScraps ~= true then
        return false
    end
    if not VanillaEnhanced:IsModuleEnabled("bags") then
        return false
    end

    local Bags = VanillaEnhanced:GetModule("bags")
    return Bags and Bags.IsSortEnabled and Bags:IsSortEnabled() and Bags.QueueAutoSort
end

function Merchants:AutoRepair()
    if self:GetSettings().autoRepair ~= true then
        return true
    end
    if type(GetRepairAllCost) ~= "function" or type(RepairAllItems) ~= "function" then
        return false
    end

    local cost = GetRepairAllCost()
    if not cost or cost <= 0 then
        return false
    end
    if type(GetMoney) == "function" and GetMoney() < cost then
        self:PrintMessage(T("merchants.autoRepair.notEnoughMoney", {
            money = FormatMoney(cost),
        }))
        return true
    end

    local ok = pcall(RepairAllItems)
    if not ok then
        return false
    end

    self:PrintMessage(T("merchants.autoRepair.repaired", {
        money = FormatMoney(cost),
    }))
    return true
end

function Merchants:PrintMessage(message)
    VanillaEnhanced:PrintMessage(message)
end

function Merchants:RegisterScrapStrategy(strategy)
    if type(strategy) ~= "table" or type(strategy.key) ~= "string" or type(strategy.isScrap) ~= "function" then
        return
    end

    if not self.scrapStrategies[strategy.key] then
        table.insert(self.scrapStrategyOrder, strategy.key)
    end
    self.scrapStrategies[strategy.key] = strategy
end

function Merchants:GetScrapStrategy()
    local settings = self:GetSettings()
    return self.scrapStrategies[settings.scrapStrategy] or self.scrapStrategies["poor-sellable"]
end

function Merchants:GetCustomScrapItemIds()
    local settings = self:GetSettings()
    if type(settings.customScrapItemIds) ~= "table" then
        settings.customScrapItemIds = {}
    end
    return settings.customScrapItemIds
end

function Merchants:IsCustomScrapItem(itemContext)
    local itemID = itemContext and itemContext.itemID
    if not itemID then
        return false
    end

    local customScrapItemIds = self:GetCustomScrapItemIds()
    return customScrapItemIds[itemID] == true or customScrapItemIds[tostring(itemID)] == true
end

function Merchants:SetCustomScrapItem(itemID, enabled)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local customScrapItemIds = self:GetCustomScrapItemIds()
    customScrapItemIds[itemID] = enabled == true or nil
    customScrapItemIds[tostring(itemID)] = nil
    return true
end

function Merchants:GetItemDisplayText(itemContext)
    if itemContext and itemContext.link then
        return itemContext.link
    end
    if itemContext and itemContext.itemID then
        return T("merchants.scrapMark.itemFallback", {
            itemID = itemContext.itemID,
        })
    end
    return T("merchants.scrapMark.itemUnknown")
end

function Merchants:ToggleCustomScrapItem(itemContext)
    if not itemContext or not itemContext.itemID then
        return false
    end

    local isMarked = self:IsCustomScrapItem(itemContext)
    if isMarked then
        if self:SetCustomScrapItem(itemContext.itemID, false) then
            self:PrintMessage(T("merchants.scrapMark.unmarked", {
                item = self:GetItemDisplayText(itemContext),
            }))
            self:RequestRefresh(0.2)
            return true
        end
        return false
    end

    if not IsSellableScrapCandidate(itemContext) then
        self:PrintMessage(T("merchants.scrapMark.cannotMark", {
            item = self:GetItemDisplayText(itemContext),
        }))
        return false
    end

    if self:SetCustomScrapItem(itemContext.itemID, true) then
        self:PrintMessage(T("merchants.scrapMark.marked", {
            item = self:GetItemDisplayText(itemContext),
        }))
        self:RequestRefresh(0.2)
        return true
    end

    return false
end

function Merchants:IsScrapItem(itemContext)
    if self:IsCustomScrapItem(itemContext) then
        return IsSellableScrapCandidate(itemContext)
    end

    local strategy = self:GetScrapStrategy()
    return strategy and strategy.isScrap(itemContext) == true
end

function Merchants:IterateBagItems()
    local bagID = BACKPACK_CONTAINER or 0
    local lastBagID = type(NUM_BAG_SLOTS) == "number" and NUM_BAG_SLOTS or 4
    local slot = 0
    local slotCount = self.Api and self.Api:GetContainerNumSlots(bagID) or 0

    return function()
        while bagID <= lastBagID do
            if slot < (slotCount or 0) then
                slot = slot + 1
            else
                bagID = bagID + 1
                slot = 1
                slotCount = self.Api and self.Api:GetContainerNumSlots(bagID) or 0
            end

            if bagID <= lastBagID then
                local itemContext = self.Api and self.Api:ReadContainerItem(bagID, slot)
                if itemContext then
                    return itemContext
                end
            end
        end
    end
end

function Merchants:GetScrapReport()
    local report = {
        stacks = 0,
        items = 0,
        value = 0,
    }

    if not self:IsSellScrapsEnabled() then
        return report
    end

    for itemContext in self:IterateBagItems() do
        if self:IsScrapItem(itemContext) then
            report.stacks = report.stacks + 1
            report.items = report.items + math.max(1, itemContext.stackCount or 1)
            report.value = report.value + ((itemContext.sellPrice or 0) * math.max(1, itemContext.stackCount or 1))
        end
    end

    return report
end

function Merchants:GetScrapReportSafely()
    local ok, report = pcall(function()
        return self:GetScrapReport()
    end)
    if ok and type(report) == "table" then
        return report
    end
    return {
        stacks = 0,
        items = 0,
        value = 0,
    }
end

local function ShowSellTooltip(button)
    if not GameTooltip then
        return
    end

    local report = Merchants:GetScrapReportSafely()
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("merchants.sellScraps.tooltipTitle"))
    if report.stacks > 0 then
        GameTooltip:AddLine(T("merchants.sellScraps.tooltipBody", {
            count = report.items,
            money = FormatMoney(report.value),
        }), 1, 1, 1, true)
    else
        GameTooltip:AddLine(T("merchants.sellScraps.tooltipEmpty"), 1, 1, 1, true)
    end
    GameTooltip:Show()
    Merchants:ShowScrapHighlights()
end

local function HideSellTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
    Merchants:ClearScrapHighlights()
end

local function ShowMarkTooltip(button)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("merchants.scrapMark.tooltipTitle"))
    if Merchants.scrapMarkMode == true then
        GameTooltip:AddLine(T("merchants.scrapMark.tooltipActive"), 1, 1, 1, true)
    else
        GameTooltip:AddLine(T("merchants.scrapMark.tooltipInactive"), 1, 1, 1, true)
    end
    GameTooltip:AddLine(T("merchants.scrapMark.tooltipBody"), 1, 0.82, 0, true)
    GameTooltip:Show()
end

local function HideMarkTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function GetItemButtonIcon(button)
    if not button then
        return nil
    end
    if button.icon then
        return button.icon
    end
    if button.Icon then
        return button.Icon
    end
    if button.GetName then
        return _G[button:GetName() .. "IconTexture"] or _G[button:GetName() .. "Icon"]
    end
    return nil
end

local function EnsureHighlightTexture(button)
    if button.VanillaEnhancedScrapHighlight then
        return button.VanillaEnhancedScrapHighlight
    end

    local highlight = button:CreateTexture(nil, "OVERLAY")
    highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    highlight:SetVertexColor(1, 0, 0, 0.35)
    highlight:Hide()

    local icon = GetItemButtonIcon(button)
    if icon then
        highlight:SetAllPoints(icon)
    else
        highlight:SetPoint("TOPLEFT", button, "TOPLEFT", HIGHLIGHT_INSET, -HIGHLIGHT_INSET)
        highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -HIGHLIGHT_INSET, HIGHLIGHT_INSET)
    end

    button.VanillaEnhancedScrapHighlight = highlight
    return highlight
end

local function GetContainerItemButton(frame, index)
    local frameName = frame and frame.GetName and frame:GetName()
    return frameName and _G[frameName .. "Item" .. index] or nil
end

function Merchants:ApplyScrapMarkCursorOverride(button)
    if not self:ShouldBypassScrapMarkItemUpdate(button) then
        return
    end
    if self.Api and self.Api.HasCursorItem and self.Api:HasCursorItem() then
        return
    end
    if type(SetCursor) == "function" then
        pcall(SetCursor, "POINT_CURSOR")
    end
end

function Merchants:EnsureScrapMarkButtonHooks(button)
    if not button or button.VanillaEnhancedScrapMarkHooksInstalled then
        return
    end
    if not button.HookScript then
        return
    end

    button:HookScript("OnEnter", function(self)
        Merchants:ApplyScrapMarkCursorOverride(self)
    end)
    button:HookScript("OnUpdate", function(self)
        Merchants:ApplyScrapMarkCursorOverride(self)
    end)
    button.VanillaEnhancedScrapMarkHooksInstalled = true
end

function Merchants:ClearScrapHighlightTextures()
    for button in pairs(self.highlightedScrapButtons or {}) do
        if button.VanillaEnhancedScrapHighlight then
            button.VanillaEnhancedScrapHighlight:Hide()
        end
        self.highlightedScrapButtons[button] = nil
    end
end

function Merchants:IsSellButtonHovered()
    return self.sellButtonHovered == true
end

function Merchants:ShouldShowScrapHighlights()
    return self.sellButtonHovered == true or self.scrapMarkMode == true
end

function Merchants:ShowScrapHighlights()
    self.sellButtonHovered = true
    self:RefreshScrapHighlights()
end

function Merchants:RefreshScrapHighlights()
    self:ClearScrapHighlightTextures()

    if not self:IsMerchantOpen() or not self:IsSellScrapsEnabled() then
        return
    end

    self.highlightedScrapButtons = self.highlightedScrapButtons or {}

    for frameIndex = 1, GetContainerFrameCount() do
        local frame = _G["ContainerFrame" .. frameIndex]
        if IsShown(frame) and frame.GetID then
            local bagID = frame:GetID()
            local slotCount = self.Api and self.Api:GetContainerNumSlots(bagID) or 0
            local buttonCount = math.max(slotCount or 0, frame.size or 0)
            if buttonCount <= 0 then
                buttonCount = HIGHLIGHT_MAX_BUTTONS
            end

            buttonCount = math.min(buttonCount, HIGHLIGHT_MAX_BUTTONS)
            for buttonIndex = 1, buttonCount do
                local button = GetContainerItemButton(frame, buttonIndex)
                if not button then
                    break
                end
                self:EnsureScrapMarkButtonHooks(button)

                local slot = button.GetID and button:GetID() or buttonIndex
                local itemContext = IsShown(button) and self.Api and self.Api:ReadContainerItem(bagID, slot)
                if itemContext and self:IsScrapItem(itemContext) then
                    local highlight = EnsureHighlightTexture(button)
                    highlight:Show()
                    self.highlightedScrapButtons[button] = true
                end
            end
        end
    end
end

function Merchants:ClearScrapHighlights()
    self.sellButtonHovered = false
    if self.scrapMarkMode == true then
        self:RefreshScrapHighlights()
        return
    end
    self:ClearScrapHighlightTextures()
end

local function ConfigureIconButton(button, iconTexture)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetText("")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(iconTexture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.icon = icon

    local activeTexture = button:CreateTexture(nil, "OVERLAY")
    activeTexture:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    activeTexture:SetPoint("CENTER", button, "CENTER", 0, 0)
    activeTexture:SetSize(BUTTON_SIZE + 2, BUTTON_SIZE + 2)
    activeTexture:Hide()
    button.activeTexture = activeTexture

    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    end
end

function Merchants:UpdateScrapMarkButtonState()
    local button = self.markButton
    if not button then
        return
    end

    if button.activeTexture then
        if self.scrapMarkMode == true then
            button.activeTexture:Show()
        else
            button.activeTexture:Hide()
        end
    end
end

function Merchants:SetScrapMarkMode(enabled)
    self.scrapMarkMode = enabled == true and self:IsMerchantOpen() and self:IsSellScrapsEnabled()
    self:UpdateScrapMarkButtonState()
    if self.scrapMarkMode == true then
        self:RefreshScrapHighlights()
    elseif not self:IsSellButtonHovered() then
        self:ClearScrapHighlightTextures()
    end
end

local function GetButtonBagAndSlot(button)
    if not button or not button.GetID or not button.GetParent then
        return nil, nil
    end

    local parent = button:GetParent()
    if not parent or not parent.GetID then
        return nil, nil
    end

    return parent:GetID(), button:GetID()
end

function Merchants:ShouldHandleScrapMarkItemHover(button)
    if self.scrapMarkMode ~= true then
        return false
    end
    if not self:IsMerchantOpen() or not self:IsSellScrapsEnabled() then
        return false
    end

    local bagID, slot = GetButtonBagAndSlot(button)
    return bagID ~= nil and slot ~= nil
end

function Merchants:ShouldBypassScrapMarkItemUpdate(button)
    if not self:ShouldHandleScrapMarkItemHover(button) then
        return false
    end
    if button and button.IsMouseOver then
        return button:IsMouseOver()
    end
    return true
end

function Merchants:ShowScrapMarkItemTooltip(button)
    if not GameTooltip then
        return
    end

    local bagID, slot = GetButtonBagAndSlot(button)
    if bagID == nil or slot == nil then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if type(GameTooltip.SetBagItem) == "function" then
        pcall(GameTooltip.SetBagItem, GameTooltip, bagID, slot)
    end
    GameTooltip:Show()
end

function Merchants:HandleScrapMarkItemClick(button, mouseButton)
    if self.scrapMarkMode ~= true or mouseButton ~= "LeftButton" then
        return false
    end
    if not self:IsMerchantOpen() or not self:IsSellScrapsEnabled() then
        self:SetScrapMarkMode(false)
        return false
    end

    local bagID, slot = GetButtonBagAndSlot(button)
    local itemContext = bagID and slot and self.Api and self.Api:ReadContainerItem(bagID, slot)
    if not itemContext then
        return true
    end

    self:ToggleCustomScrapItem(itemContext)
    if self:ShouldShowScrapHighlights() then
        self:RefreshScrapHighlights()
    end
    return true
end

function Merchants:InstallScrapMarkHooks()
    local hooked = false
    if type(ContainerFrameItemButton_OnClick) == "function" and not self.containerItemClickHookInstalled then
        self.originalContainerFrameItemButtonOnClick = ContainerFrameItemButton_OnClick
        ContainerFrameItemButton_OnClick = function(button, mouseButton, ...)
            if Merchants:HandleScrapMarkItemClick(button, mouseButton) then
                return
            end
            return Merchants.originalContainerFrameItemButtonOnClick(button, mouseButton, ...)
        end
        self.containerItemClickHookInstalled = true
        hooked = true
    end

    if type(ContainerFrameItemButton_OnModifiedClick) == "function" and not self.containerItemModifiedClickHookInstalled then
        self.originalContainerFrameItemButtonOnModifiedClick = ContainerFrameItemButton_OnModifiedClick
        ContainerFrameItemButton_OnModifiedClick = function(button, mouseButton, ...)
            if Merchants:HandleScrapMarkItemClick(button, mouseButton) then
                return true
            end
            return Merchants.originalContainerFrameItemButtonOnModifiedClick(button, mouseButton, ...)
        end
        self.containerItemModifiedClickHookInstalled = true
        hooked = true
    end

    if type(ContainerFrameItemButton_OnEnter) == "function" and not self.containerItemEnterHookInstalled then
        self.originalContainerFrameItemButtonOnEnter = ContainerFrameItemButton_OnEnter
        ContainerFrameItemButton_OnEnter = function(button, ...)
            if Merchants:ShouldHandleScrapMarkItemHover(button) then
                Merchants:ShowScrapMarkItemTooltip(button)
                return
            end

            local result = Merchants.originalContainerFrameItemButtonOnEnter(button, ...)
            return result
        end
        self.containerItemEnterHookInstalled = true
        hooked = true
    end

    self.scrapMarkHooksInstalled = hooked
end

function Merchants:EnsureButton()
    if self.sellButton and self.markButton then
        return self.button
    end

    local sellButton = self.sellButton
    if not sellButton then
        sellButton = CreateFrame("Button", "VanillaEnhancedMerchantsSellScrapsButton", UIParent, "UIPanelButtonTemplate")
        ConfigureIconButton(sellButton, SELL_SCRAPS_ICON)
        sellButton:SetFrameStrata("HIGH")
        sellButton:Hide()

        sellButton:SetScript("OnClick", function()
            Merchants:SellScrapsBatch(Merchants:GetSellLimit(Merchants:GetSettings().safeManualSell == true))
        end)
        sellButton:SetScript("OnEnter", ShowSellTooltip)
        sellButton:SetScript("OnLeave", HideSellTooltip)

        self.sellButton = sellButton
        self.button = sellButton
    end

    local markButton = self.markButton
    if not markButton then
        markButton = CreateFrame("Button", "VanillaEnhancedMerchantsMarkScrapsButton", UIParent, "UIPanelButtonTemplate")
        ConfigureIconButton(markButton, MARK_SCRAPS_ICON)
        markButton:SetFrameStrata("HIGH")
        markButton:Hide()

        markButton:SetScript("OnClick", function()
            Merchants:SetScrapMarkMode(Merchants.scrapMarkMode ~= true)
            if GameTooltip and GameTooltip:IsOwned(markButton) then
                ShowMarkTooltip(markButton)
            end
        end)
        markButton:SetScript("OnEnter", ShowMarkTooltip)
        markButton:SetScript("OnLeave", HideMarkTooltip)

        self.markButton = markButton
    end

    return self.button
end

function Merchants:AnchorButton()
    self:EnsureButton()
    local sellButton = self.sellButton
    local markButton = self.markButton
    sellButton:ClearAllPoints()
    markButton:ClearAllPoints()

    if MerchantFrame then
        sellButton:SetParent(MerchantFrame)
        markButton:SetParent(MerchantFrame)
        sellButton:SetFrameStrata(MerchantFrame:GetFrameStrata() or "HIGH")
        markButton:SetFrameStrata(MerchantFrame:GetFrameStrata() or "HIGH")
        sellButton:SetFrameLevel((MerchantFrame:GetFrameLevel() or 0) + 50)
        markButton:SetFrameLevel((MerchantFrame:GetFrameLevel() or 0) + 50)
    else
        sellButton:SetParent(UIParent)
        markButton:SetParent(UIParent)
        sellButton:SetFrameStrata("HIGH")
        markButton:SetFrameStrata("HIGH")
        sellButton:SetFrameLevel(100)
        markButton:SetFrameLevel(100)
    end

    if MerchantFrameCloseButton then
        sellButton:SetPoint("TOPRIGHT", MerchantFrameCloseButton, "BOTTOMRIGHT", -10, 4)
    elseif MerchantFrame then
        sellButton:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -16, -24)
    else
        sellButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    markButton:SetPoint("RIGHT", sellButton, "LEFT", -BUTTON_SPACING, 0)
end

function Merchants:UpdateButton()
    self:EnsureButton()
    local sellButton = self.sellButton
    local markButton = self.markButton

    if not self:IsMerchantOpen() or not self:IsSellScrapsEnabled() or not MerchantFrame then
        self:SetScrapMarkMode(false)
        self:ClearScrapHighlights()
        sellButton:Hide()
        markButton:Hide()
        return
    end

    self:AnchorButton()
    sellButton:Show()
    markButton:Show()
    self:UpdateScrapMarkButtonState()

    local report = self:GetScrapReportSafely()
    if report.stacks > 0 then
        if sellButton.Enable then
            sellButton:Enable()
        end
        if sellButton.icon then
            sellButton.icon:SetAlpha(1)
        end
        if self:ShouldShowScrapHighlights() then
            self:RefreshScrapHighlights()
        end
    elseif sellButton.Disable then
        sellButton:Disable()
        if sellButton.icon then
            sellButton.icon:SetAlpha(0.35)
        end
        self:ClearScrapHighlights()
    end
end

function Merchants:TryHookMerchantFrame()
    if self.merchantHooksInstalled or not MerchantFrame then
        return
    end

    if MerchantFrame.HookScript then
        MerchantFrame:HookScript("OnShow", function()
            Merchants:RequestRefresh(0.2)
        end)
        MerchantFrame:HookScript("OnHide", function()
            if not Merchants:IsMerchantOpen() then
                if Merchants.sellButton then
                    Merchants.sellButton:Hide()
                end
                if Merchants.markButton then
                    Merchants.markButton:Hide()
                end
            end
        end)
    end

    if type(hooksecurefunc) == "function" then
        if type(MerchantFrame_UpdateMerchantInfo) == "function" then
            pcall(hooksecurefunc, "MerchantFrame_UpdateMerchantInfo", function()
                Merchants:RequestRefresh(0.2)
            end)
        end
        if type(MerchantFrame_UpdateRepairButtons) == "function" then
            pcall(hooksecurefunc, "MerchantFrame_UpdateRepairButtons", function()
                Merchants:RequestRefresh(0.2)
            end)
        end
    end

    self.merchantHooksInstalled = true
end

function Merchants:RequestRefresh(duration)
    self.refreshRemaining = math.max(self.refreshRemaining or 0, duration or 0)
    refreshFrame:SetScript("OnUpdate", function(frame, elapsed)
        Merchants:InstallScrapMarkHooks()
        Merchants:TryHookMerchantFrame()
        Merchants:UpdateButton()

        if Merchants.pendingAutoSellScraps and Merchants:IsMerchantOpen() and MerchantFrame then
            Merchants.pendingAutoSellScraps = false
            Merchants:SellScrapsBatch(Merchants:GetSellLimit(Merchants:GetSettings().safeAutoSell ~= false))
        end
        if Merchants.pendingAutoRepair and Merchants:IsMerchantOpen() and MerchantFrame then
            Merchants.pendingAutoRepair = not Merchants:AutoRepair()
        end

        Merchants.refreshRemaining = (Merchants.refreshRemaining or 0) - (elapsed or 0)
        if Merchants.refreshRemaining <= 0 then
            Merchants.refreshRemaining = 0
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

function Merchants:SellScrapsBatch(limit)
    if not self:IsSellScrapsEnabled() or not self:IsMerchantOpen() then
        return
    end
    if self.Api and self.Api:HasCursorItem() then
        self:PrintMessage(T("merchants.sellScraps.errorCursor"))
        return
    end

    local soldStacks = 0
    local soldValue = 0

    for itemContext in self:IterateBagItems() do
        if limit and soldStacks >= limit then
            break
        end
        if self:IsScrapItem(itemContext) then
            local ok = pcall(self.Api.UseContainerItem, self.Api, itemContext.bagID, itemContext.slot)
            if ok then
                soldStacks = soldStacks + 1
                soldValue = soldValue + ((itemContext.sellPrice or 0) * math.max(1, itemContext.stackCount or 1))
            end
        end
    end

    if soldStacks > 0 then
        self:PrintMessage(T("merchants.sellScraps.sold", {
            money = FormatMoney(soldValue),
        }))
        self.pendingSortBagsAfterSellingScraps = self:CanSortBagsAfterSellingScraps()
    end

    self:RequestRefresh(0.5)
end

function Merchants:SortBagsAfterSellingScraps()
    if not self.pendingSortBagsAfterSellingScraps then
        return
    end
    self.pendingSortBagsAfterSellingScraps = false

    if not self:CanSortBagsAfterSellingScraps() then
        return
    end

    local Bags = VanillaEnhanced:GetModule("bags")
    Bags:QueueAutoSort("merchant")
end

function Merchants:OpenMerchant()
    self.merchantOpen = true
    self.pendingAutoSellScraps = self:IsSellScrapsEnabled() and self:GetSettings().autoSellScraps == true
    self.pendingAutoRepair = self:GetSettings().autoRepair == true
    self:EnsureButton()
    self:InstallScrapMarkHooks()
    self:RequestRefresh(MERCHANT_OPEN_REFRESH_SECONDS)
end

function Merchants:CloseMerchant()
    self.merchantOpen = false
    self:SetScrapMarkMode(false)
    self.pendingAutoSellScraps = false
    self.pendingAutoRepair = false
    self.pendingSortBagsAfterSellingScraps = false
    self.refreshRemaining = 0
    refreshFrame:SetScript("OnUpdate", nil)
    self:ClearScrapHighlights()
    if self.sellButton then
        self.sellButton:Hide()
    end
    if self.markButton then
        self.markButton:Hide()
    end
end

function Merchants:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("merchants", enabled)
    if enabled then
        self:RequestRefresh(0.2)
    else
        self:SetScrapMarkMode(false)
        self:ClearScrapHighlights()
        if self.sellButton then
            self.sellButton:Hide()
        end
        if self.markButton then
            self.markButton:Hide()
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName ~= VanillaEnhanced.addonName then
        return
    end

    if event == "ADDON_LOADED" then
        Merchants:GetSettings()
        Merchants:EnsureButton()
        Merchants:InstallScrapMarkHooks()
        Merchants:TryHookMerchantFrame()
        return
    end

    if event == "PLAYER_LOGIN" then
        Merchants:EnsureButton()
        Merchants:InstallScrapMarkHooks()
        Merchants:TryHookMerchantFrame()
        return
    end

    if event == "MERCHANT_SHOW" then
        Merchants:OpenMerchant()
        return
    end

    if event == "MERCHANT_CLOSED" then
        Merchants:CloseMerchant()
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        Merchants:SortBagsAfterSellingScraps()
        if Merchants:ShouldShowScrapHighlights() then
            Merchants:RefreshScrapHighlights()
        else
            Merchants:ClearScrapHighlightTextures()
        end
        Merchants:RequestRefresh(0.2)
        return
    end

    if event == "MERCHANT_UPDATE" then
        if Merchants:IsMerchantOpen() and Merchants:GetSettings().autoRepair == true then
            Merchants.pendingAutoRepair = true
        end
        Merchants:RequestRefresh(0.2)
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
pcall(eventFrame.RegisterEvent, eventFrame, "MERCHANT_UPDATE")
