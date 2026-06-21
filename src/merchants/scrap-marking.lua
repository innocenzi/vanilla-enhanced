local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local BUTTON_SIZE = 24
local HIGHLIGHT_INSET = 2
local HIGHLIGHT_MAX_BUTTONS = 100
local MARK_SCRAPS_ICON = "Interface\\Icons\\INV_Misc_Wrench_01"

local cursorFrame = CreateFrame("Frame")

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

local function IsSellableScrapCandidate(itemContext)
    return itemContext
        and itemContext.isLocked ~= true
        and itemContext.isUserLocked ~= true
        and itemContext.isQuestItem ~= true
        and (itemContext.sellPrice or 0) > 0
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

local function FindHoveredBagItemButton()
    for frameIndex = 1, GetContainerFrameCount() do
        local frame = _G["ContainerFrame" .. frameIndex]
        if IsShown(frame) and frame.GetID then
            local slotCount = Merchants.Api and Merchants.Api:GetContainerNumSlots(frame:GetID()) or 0
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
                if button.IsMouseOver and button:IsMouseOver() then
                    return button
                end
            end
        end
    end

    return nil
end

local function ConfigureMarkButton(button, size)
    button:SetSize(size or BUTTON_SIZE, size or BUTTON_SIZE)
    button:SetText("")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(MARK_SCRAPS_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.icon = icon

    local activeTexture = button:CreateTexture(nil, "OVERLAY")
    activeTexture:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    activeTexture:SetPoint("CENTER", button, "CENTER", 0, 0)
    activeTexture:SetSize((size or BUTTON_SIZE) + 2, (size or BUTTON_SIZE) + 2)
    activeTexture:Hide()
    button.activeTexture = activeTexture

    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    end
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

function Merchants:UpdateScrapMarkCursorOverride()
    local button = FindHoveredBagItemButton()
    if button then
        self:EnsureScrapMarkButtonHooks(button)
        self:ApplyScrapMarkCursorOverride(button)
    end
end

function Merchants:SetScrapMarkCursorOverrideEnabled(enabled)
    if enabled == true then
        cursorFrame:SetScript("OnUpdate", function()
            Merchants:UpdateScrapMarkCursorOverride()
        end)
        return
    end

    cursorFrame:SetScript("OnUpdate", nil)
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
    self:SetScrapMarkCursorOverrideEnabled(self.scrapMarkMode == true)
    self:UpdateScrapMarkButtonState()
    if self.UpdateSellButtonState then
        self:UpdateSellButtonState(self:GetScrapReportSafely())
    end
    if self.scrapMarkMode == true then
        self:RefreshScrapHighlights()
    elseif not self:IsSellButtonHovered() then
        self:ClearScrapHighlightTextures()
    end
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
    if mouseButton == "LeftButton" and type(IsAltKeyDown) == "function" and IsAltKeyDown() then
        return false
    end

    if self.scrapMarkMode ~= true then
        return false
    end
    if not self:IsMerchantOpen() or not self:IsSellScrapsEnabled() then
        self:SetScrapMarkMode(false)
        return false
    end

    local bagID, slot = GetButtonBagAndSlot(button)
    if bagID == nil or slot == nil then
        return false
    end

    local itemContext = self.Api and self.Api:ReadContainerItem(bagID, slot)
    if mouseButton == "LeftButton" and itemContext then
        self:ToggleCustomScrapItem(itemContext)
        if self:ShouldShowScrapHighlights() then
            self:RefreshScrapHighlights()
        end
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

            return Merchants.originalContainerFrameItemButtonOnEnter(button, ...)
        end
        self.containerItemEnterHookInstalled = true
        hooked = true
    end

    self.scrapMarkHooksInstalled = self.scrapMarkHooksInstalled or hooked
end

function Merchants:EnsureMarkButton(size)
    if self.markButton then
        return self.markButton
    end

    local markButton = CreateFrame("Button", "VanillaEnhancedMerchantsMarkScrapsButton", UIParent, "UIPanelButtonTemplate")
    ConfigureMarkButton(markButton, size or BUTTON_SIZE)
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
    return markButton
end
