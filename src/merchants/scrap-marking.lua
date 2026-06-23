local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local BUTTON_SIZE = 24
local HIGHLIGHT_INSET = 2
local HIGHLIGHT_MAX_BUTTONS = 100
local SCRAP_MARK_CLICK_OVERLAY_LEVEL_OFFSET = 30
local MARK_SCRAPS_ICON = "Interface\\Minimap\\Tracking\\Banker"
local MARK_SCRAPS_ICON_INSET = 4
local SCRAP_MARK_CLICK_DEDUPE_SECONDS = 0.2

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

function Merchants:ConfigureScrapMarkButton(button, size)
    button:SetSize(size or BUTTON_SIZE, size or BUTTON_SIZE)
    button:SetText("")

    local icon = button.icon
    if not icon then
        icon = button:CreateTexture(nil, "ARTWORK")
        button.icon = icon
    end
    icon:SetTexture(MARK_SCRAPS_ICON)
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetBlendMode("BLEND")
    if icon.SetDesaturated then
        icon:SetDesaturated(false)
    end
    icon:SetVertexColor(1, 1, 1, 1)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", MARK_SCRAPS_ICON_INSET, -MARK_SCRAPS_ICON_INSET)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -MARK_SCRAPS_ICON_INSET, MARK_SCRAPS_ICON_INSET)

    local activeTexture = button.activeTexture
    if not activeTexture then
        activeTexture = button:CreateTexture(nil, "OVERLAY")
        button.activeTexture = activeTexture
    end
    activeTexture:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    activeTexture:ClearAllPoints()
    activeTexture:SetPoint("CENTER", button, "CENTER", 0, 0)
    activeTexture:SetSize((size or BUTTON_SIZE) + 2, (size or BUTTON_SIZE) + 2)
    activeTexture:Hide()

    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    end

    self.scrapMarkButtons = self.scrapMarkButtons or {}
    self.scrapMarkButtons[button] = true
end

function Merchants:ShowScrapMarkTooltip(button)
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

function Merchants:HideScrapMarkTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function Merchants:ShowScrapMarkButtonTooltip(button)
    self:ShowScrapMarkTooltip(button)
    self.scrapMarkButtonHovered = true
    self:RefreshScrapHighlights()
end

function Merchants:HideScrapMarkButtonTooltip()
    self:HideScrapMarkTooltip()
    self.scrapMarkButtonHovered = false
    if self:ShouldShowScrapHighlights() then
        self:RefreshScrapHighlights()
    else
        self:ClearScrapHighlightTextures()
        self:ClearScrapMarkClickOverlays()
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

local function PositionClickOverlay(overlay, button)
    overlay:ClearAllPoints()
    overlay:SetAllPoints(button)
    if overlay.SetFrameLevel and button.GetFrameLevel then
        overlay:SetFrameLevel((button:GetFrameLevel() or 0) + SCRAP_MARK_CLICK_OVERLAY_LEVEL_OFFSET)
    end
end

function Merchants:GetCustomScrapItemIds()
    local settings = self:GetSettings()
    if type(settings.customScrapItemIds) ~= "table" then
        settings.customScrapItemIds = {}
    end
    return settings.customScrapItemIds
end

function Merchants:GetIgnoredScrapItemIds()
    local settings = self:GetSettings()
    if type(settings.ignoredScrapItemIds) ~= "table" then
        settings.ignoredScrapItemIds = {}
    end
    return settings.ignoredScrapItemIds
end

function Merchants:IsCustomScrapItem(itemContext)
    local itemID = itemContext and itemContext.itemID
    if not itemID then
        return false
    end

    local customScrapItemIds = self:GetCustomScrapItemIds()
    return customScrapItemIds[itemID] == true or customScrapItemIds[tostring(itemID)] == true
end

function Merchants:IsIgnoredScrapItem(itemContext)
    local itemID = itemContext and itemContext.itemID
    if not itemID then
        return false
    end

    local ignoredScrapItemIds = self:GetIgnoredScrapItemIds()
    return ignoredScrapItemIds[itemID] == true or ignoredScrapItemIds[tostring(itemID)] == true
end

function Merchants:SetCustomScrapItem(itemID, enabled)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local customScrapItemIds = self:GetCustomScrapItemIds()
    customScrapItemIds[itemID] = enabled == true or nil
    customScrapItemIds[tostring(itemID)] = nil
    if enabled == true then
        self:SetIgnoredScrapItem(itemID, false)
    end
    return true
end

function Merchants:SetIgnoredScrapItem(itemID, enabled)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local ignoredScrapItemIds = self:GetIgnoredScrapItemIds()
    ignoredScrapItemIds[itemID] = enabled == true or nil
    ignoredScrapItemIds[tostring(itemID)] = nil
    if enabled == true then
        local customScrapItemIds = self:GetCustomScrapItemIds()
        customScrapItemIds[itemID] = nil
        customScrapItemIds[tostring(itemID)] = nil
    end
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

    local isCustomMarked = self:IsCustomScrapItem(itemContext)
    local isIgnored = self:IsIgnoredScrapItem(itemContext)
    local strategy = self:GetScrapStrategy()
    local isStrategyScrap = strategy and strategy.isScrap(itemContext) == true

    if isIgnored then
        if self:SetIgnoredScrapItem(itemContext.itemID, false) then
            self:PrintMessage(T("merchants.scrapMark.marked", {
                item = self:GetItemDisplayText(itemContext),
            }))
            self:RequestRefresh(0.2)
            self:RefreshBagScrapIcons()
            return true
        end
        return false
    end

    if isCustomMarked then
        if self:SetCustomScrapItem(itemContext.itemID, false) then
            self:PrintMessage(T("merchants.scrapMark.unmarked", {
                item = self:GetItemDisplayText(itemContext),
            }))
            self:RequestRefresh(0.2)
            self:RefreshBagScrapIcons()
            return true
        end
        return false
    end

    if isStrategyScrap then
        if self:SetIgnoredScrapItem(itemContext.itemID, true) then
            self:PrintMessage(T("merchants.scrapMark.unmarked", {
                item = self:GetItemDisplayText(itemContext),
            }))
            self:RequestRefresh(0.2)
            self:RefreshBagScrapIcons()
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
        self:RefreshBagScrapIcons()
        return true
    end

    return false
end

function Merchants:ToggleCustomScrapItemForSlot(bagID, slot)
    if not self:IsSellScrapsEnabled() then
        if self.scrapMarkMode == true then
            self:SetScrapMarkMode(false)
        end
        return false
    end

    local itemContext = self.Api and self.Api:ReadContainerItem(bagID, slot)
    if not itemContext then
        return false
    end

    local toggled = self:ToggleCustomScrapItem(itemContext)
    if toggled and self:ShouldShowScrapHighlights() then
        self:RefreshScrapHighlights()
    end
    return toggled
end

function Merchants:IsScrapItem(itemContext)
    if self:IsIgnoredScrapItem(itemContext) then
        return false
    end

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

function Merchants:EnsureScrapMarkClickOverlay(button)
    if not button then
        return nil
    end

    local overlay = button.VanillaEnhancedScrapMarkClickOverlay
    if not overlay then
        overlay = CreateFrame("Button", nil, button)
        overlay:RegisterForClicks("AnyUp")
        overlay:EnableMouse(true)
        overlay:SetScript("OnClick", function(_, mouseButton)
            Merchants:HandleScrapMarkItemClick(button, mouseButton)
        end)
        overlay:SetScript("OnEnter", function()
            Merchants:ShowScrapMarkItemTooltip(button)
            Merchants:ApplyScrapMarkCursorOverride(button)
        end)
        overlay:SetScript("OnLeave", function()
            Merchants:HideScrapMarkTooltip()
        end)
        button.VanillaEnhancedScrapMarkClickOverlay = overlay
    end

    PositionClickOverlay(overlay, button)
    overlay:Show()

    self.scrapMarkClickOverlayButtons = self.scrapMarkClickOverlayButtons or {}
    self.scrapMarkClickOverlayButtons[button] = true
    return overlay
end

function Merchants:ClearScrapMarkClickOverlays()
    for button in pairs(self.scrapMarkClickOverlayButtons or {}) do
        if button.VanillaEnhancedScrapMarkClickOverlay then
            button.VanillaEnhancedScrapMarkClickOverlay:Hide()
        end
        self.scrapMarkClickOverlayButtons[button] = nil
    end
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
    return self.sellButtonHovered == true
        or self.scrapMarkButtonHovered == true
        or self.scrapMarkMode == true
end

function Merchants:ShowScrapHighlights()
    self.sellButtonHovered = true
    self:RefreshScrapHighlights()
end

function Merchants:RefreshScrapHighlights()
    self:ClearScrapHighlightTextures()
    self:ClearScrapMarkClickOverlays()

    if not self:IsSellScrapsEnabled() then
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
                if self.scrapMarkMode == true and itemContext then
                    self:EnsureScrapMarkClickOverlay(button)
                end
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
    if self:ShouldShowScrapHighlights() then
        self:RefreshScrapHighlights()
        return
    end
    self:ClearScrapHighlightTextures()
    self:ClearScrapMarkClickOverlays()
end

function Merchants:UpdateScrapMarkButtonState()
    for button in pairs(self.scrapMarkButtons or {}) do
        if button.activeTexture then
            if self.scrapMarkMode == true then
                button.activeTexture:Show()
            else
                button.activeTexture:Hide()
            end
        end
    end
end

function Merchants:SetScrapMarkMode(enabled)
    self.scrapMarkMode = enabled == true and self:IsSellScrapsEnabled()
    self:SetScrapMarkCursorOverrideEnabled(self.scrapMarkMode == true)
    self:UpdateScrapMarkButtonState()
    if self.UpdateSellButtonState then
        self:UpdateSellButtonState(self:GetScrapReportSafely())
    end
    local Bags = VanillaEnhanced:GetModule("bags")
    if Bags and Bags.RefreshItemLockOverlays then
        Bags:RefreshItemLockOverlays()
    end
    if self.scrapMarkMode == true then
        self:RefreshScrapHighlights()
    else
        self:ClearScrapMarkClickOverlays()
        if self:ShouldShowScrapHighlights() then
            self:RefreshScrapHighlights()
        else
            self:ClearScrapHighlightTextures()
        end
    end
end

function Merchants:ShouldHandleScrapMarkItemHover(button)
    if self.scrapMarkMode ~= true then
        return false
    end
    if not self:IsSellScrapsEnabled() then
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
        local Bags = VanillaEnhanced:GetModule("bags")
        if Bags and Bags.HandleItemLockClick then
            return Bags:HandleItemLockClick(button, mouseButton)
        end
        return false
    end

    if self.scrapMarkMode ~= true then
        return false
    end
    if not self:IsSellScrapsEnabled() then
        self:SetScrapMarkMode(false)
        return false
    end

    local bagID, slot = GetButtonBagAndSlot(button)
    if bagID == nil or slot == nil then
        return false
    end

    if mouseButton == "RightButton" and type(IsAltKeyDown) == "function" and IsAltKeyDown() then
        self:ToggleCustomScrapItemForSlot(bagID, slot)
        return true
    end

    if mouseButton == "LeftButton" then
        local now = type(GetTime) == "function" and GetTime() or nil
        local slotKey = tostring(bagID) .. ":" .. tostring(slot)
        if now
            and self.lastScrapMarkClickSlotKey == slotKey
            and self.lastScrapMarkClickTime
            and now - self.lastScrapMarkClickTime <= SCRAP_MARK_CLICK_DEDUPE_SECONDS
        then
            return true
        end
        self.lastScrapMarkClickSlotKey = slotKey
        self.lastScrapMarkClickTime = now
    end

    if mouseButton == "LeftButton" then
        self:ToggleCustomScrapItemForSlot(bagID, slot)
    end
    return true
end

function Merchants:InstallScrapMarkHooks()
    if self.scrapMarkHooksInstalled then
        return
    end

    -- The old global container-button hooks tainted right-click item use.
    -- Scrap mark mode now installs per-button child overlays only while active.
    self.scrapMarkHooksInstalled = true
end

function Merchants:EnsureMarkButton(size)
    if self.markButton then
        return self.markButton
    end

    local markButton = CreateFrame("Button", "VanillaEnhancedMerchantsMarkScrapsButton", UIParent, "UIPanelButtonTemplate")
    self:ConfigureScrapMarkButton(markButton, size or BUTTON_SIZE)
    markButton:SetFrameStrata("HIGH")
    markButton:Hide()

    markButton:SetScript("OnClick", function()
        Merchants:SetScrapMarkMode(Merchants.scrapMarkMode ~= true)
        if GameTooltip and GameTooltip:IsOwned(markButton) then
            Merchants:ShowScrapMarkButtonTooltip(markButton)
        end
    end)
    markButton:SetScript("OnEnter", function()
        Merchants:ShowScrapMarkButtonTooltip(markButton)
    end)
    markButton:SetScript("OnLeave", function()
        Merchants:HideScrapMarkButtonTooltip()
    end)

    self.markButton = markButton
    return markButton
end
