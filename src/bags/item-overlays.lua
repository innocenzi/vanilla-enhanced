local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:GetModule("bags")

local LOCK_ICON = "Interface\\Buttons\\LockButton-Locked-Up"
local SCRAP_ICON = "Interface\\Buttons\\UI-GroupLoot-Coin-Up"
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local LOCK_SIZE = 25
local SCRAP_ICON_SIZE = 17
local SCRAP_ICON_OFFSET_X = 2
local SCRAP_ICON_OFFSET_Y = 2
local SCRAP_ICON_FALLBACK_OFFSET_X = -1
local SCRAP_ICON_FALLBACK_OFFSET_Y = -1
local QUEST_ICON_SIZE = 17
local QUEST_ICON_OFFSET_X = 3
local QUEST_ICON_OFFSET_Y = -1
local QUEST_ICON_FALLBACK_OFFSET_X = -1
local QUEST_ICON_FALLBACK_OFFSET_Y = 1
local QUEST_ICON_TINT = 1
local QUEST_ICON_ALPHA = 1
local MAX_CONTAINER_BUTTONS = 100

local function IsShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function GetContainerFrameCount()
    if type(NUM_CONTAINER_FRAMES) == "number" then
        return NUM_CONTAINER_FRAMES
    end
    return 13
end

local function GetContainerItemButton(frame, index)
    local frameName = frame and frame.GetName and frame:GetName()
    return frameName and _G[frameName .. "Item" .. index] or nil
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

local function GetMerchantsModule()
    return VanillaEnhanced:GetModule("merchants")
end

local function IsQuestRelatedItem(questInfo)
    if not questInfo then
        return false
    end
    if questInfo.isQuestItem == true or questInfo.isQuestStarter == true then
        return true
    end

    local questID = tonumber(questInfo.questID)
    return questID ~= nil and questID > 0
end

local function IsScrapShortcutEnabled()
    local Merchants = GetMerchantsModule()
    return Merchants
        and Merchants.IsSellScrapsEnabled
        and Merchants:IsSellScrapsEnabled()
        and Merchants.ToggleCustomScrapItemForSlot
end

local function IsMerchantOpen()
    local Merchants = GetMerchantsModule()
    if Merchants and Merchants.IsMerchantOpen then
        return Merchants:IsMerchantOpen()
    end
    return MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()
end

local function HasCursorItem()
    return Bags.Api and Bags.Api.HasCursorItem and Bags.Api:HasCursorItem()
end

local function IsScrapMarkModeActive()
    local Merchants = GetMerchantsModule()
    return Merchants and Merchants.scrapMarkMode == true
end

local function EnsureLockOverlay(button)
    if button.VanillaEnhancedItemLockOverlay then
        return button.VanillaEnhancedItemLockOverlay
    end

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture(LOCK_ICON)
    overlay:SetSize(LOCK_SIZE, LOCK_SIZE)
    overlay:SetVertexColor(1, 0.82, 0, 0.95)
    overlay:Hide()

    local icon = GetItemButtonIcon(button)
    if icon then
        overlay:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 6, 6)
    else
        overlay:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    end

    button.VanillaEnhancedItemLockOverlay = overlay
    return overlay
end

local function EnsureScrapIconOverlay(button)
    if button.VanillaEnhancedScrapIconOverlay then
        return button.VanillaEnhancedScrapIconOverlay
    end

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture(SCRAP_ICON)
    overlay:SetSize(SCRAP_ICON_SIZE, SCRAP_ICON_SIZE)
    overlay:Hide()

    local icon = GetItemButtonIcon(button)
    if icon then
        overlay:SetPoint("TOPRIGHT", icon, "TOPRIGHT", SCRAP_ICON_OFFSET_X, SCRAP_ICON_OFFSET_Y)
    else
        overlay:SetPoint("TOPRIGHT", button, "TOPRIGHT", SCRAP_ICON_FALLBACK_OFFSET_X, SCRAP_ICON_FALLBACK_OFFSET_Y)
    end

    button.VanillaEnhancedScrapIconOverlay = overlay
    return overlay
end

local function ApplyQuestIconStyle(overlay)
    if overlay.SetDesaturated then
        overlay:SetDesaturated(true)
    end
    overlay:SetVertexColor(QUEST_ICON_TINT, QUEST_ICON_TINT, QUEST_ICON_TINT, QUEST_ICON_ALPHA)
end

local function EnsureQuestIconOverlay(button)
    if button.VanillaEnhancedQuestIconOverlay then
        ApplyQuestIconStyle(button.VanillaEnhancedQuestIconOverlay)
        return button.VanillaEnhancedQuestIconOverlay
    end

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture(QUEST_ICON)
    overlay:SetSize(QUEST_ICON_SIZE, QUEST_ICON_SIZE)
    ApplyQuestIconStyle(overlay)
    overlay:Hide()

    local icon = GetItemButtonIcon(button)
    if icon then
        overlay:SetPoint("TOPRIGHT", icon, "TOPRIGHT", QUEST_ICON_OFFSET_X, QUEST_ICON_OFFSET_Y)
    else
        overlay:SetPoint("TOPRIGHT", button, "TOPRIGHT", QUEST_ICON_FALLBACK_OFFSET_X, QUEST_ICON_FALLBACK_OFFSET_Y)
    end

    button.VanillaEnhancedQuestIconOverlay = overlay
    return overlay
end

function Bags:IsScrapIconEnabled()
    local settings = self:GetSettings()
    if self.sorting == true or not self:IsSortEnabled() or settings.showScrapIcon ~= true then
        return false
    end

    local Merchants = GetMerchantsModule()
    return Merchants and Merchants.IsSellScrapsEnabled and Merchants:IsSellScrapsEnabled()
end

function Bags:IsQuestIconEnabled()
    local settings = self:GetSettings()
    return self.sorting ~= true and self:IsSortEnabled() and settings.showQuestIcon == true
end

function Bags:IsQuestItem(bagID, slot)
    local questInfo = self.Api
        and self.Api.GetContainerItemQuestInfo
        and self.Api:GetContainerItemQuestInfo(bagID, slot)
    return IsQuestRelatedItem(questInfo)
end

function Bags:ClearScrapIconOverlays()
    for button in pairs(self.scrapIconOverlayButtons or {}) do
        if button.VanillaEnhancedScrapIconOverlay then
            button.VanillaEnhancedScrapIconOverlay:Hide()
        end
        self.scrapIconOverlayButtons[button] = nil
    end
end

function Bags:ClearQuestIconOverlays()
    for button in pairs(self.questIconOverlayButtons or {}) do
        if button.VanillaEnhancedQuestIconOverlay then
            button.VanillaEnhancedQuestIconOverlay:Hide()
        end
        self.questIconOverlayButtons[button] = nil
    end
end

function Bags:ClearItemOverlays()
    self:ClearScrapIconOverlays()
    self:ClearQuestIconOverlays()
    self:ClearItemLockButtonHooks()

    for button in pairs(self.itemLockOverlayButtons or {}) do
        if button.VanillaEnhancedItemLockOverlay then
            button.VanillaEnhancedItemLockOverlay:Hide()
        end
        self.itemLockOverlayButtons[button] = nil
    end

    for button in pairs(self.itemLockClickOverlayButtons or {}) do
        self:ClearItemLockClickOverlay(button)
        self.itemLockClickOverlayButtons[button] = nil
    end
end

function Bags:RefreshItemOverlays()
    self:ClearItemOverlays()
    self.itemLockOverlayButtons = self.itemLockOverlayButtons or {}
    self.itemLockClickOverlayButtons = self.itemLockClickOverlayButtons or {}
    self.scrapIconOverlayButtons = self.scrapIconOverlayButtons or {}
    self.questIconOverlayButtons = self.questIconOverlayButtons or {}

    local lockEnabled = self:IsItemLockingEnabled()
    local scrapIconEnabled = self:IsScrapIconEnabled()
    local scrapShortcutEnabled = IsScrapShortcutEnabled()
    local questIconEnabled = self:IsQuestIconEnabled()
    if not lockEnabled and not scrapIconEnabled and not scrapShortcutEnabled and not questIconEnabled then
        return
    end

    if lockEnabled then
        self:PruneItemLocks()
    end
    local altDown = type(IsAltKeyDown) == "function" and IsAltKeyDown()
    local cursorHasItem = HasCursorItem()
    local merchantOpen = IsMerchantOpen()
    local suppressClickOverlays = IsScrapMarkModeActive()
    local Merchants = scrapIconEnabled and GetMerchantsModule() or nil

    for frameIndex = 1, GetContainerFrameCount() do
        local frame = _G["ContainerFrame" .. frameIndex]
        if IsShown(frame) and frame.GetID then
            local bagID = frame:GetID()
            local slotCount = self.Api and self.Api:GetContainerNumSlots(bagID) or 0
            local buttonCount = math.max(slotCount or 0, frame.size or 0)
            if buttonCount <= 0 then
                buttonCount = MAX_CONTAINER_BUTTONS
            end

            buttonCount = math.min(buttonCount, MAX_CONTAINER_BUTTONS)
            for buttonIndex = 1, buttonCount do
                local button = GetContainerItemButton(frame, buttonIndex)
                if not button then
                    break
                end

                local slot = button.GetID and button:GetID() or buttonIndex
                local containerItem = IsShown(button) and self.Api and self.Api:GetContainerItemInfo(bagID, slot)
                local hasItem = containerItem and (containerItem.hyperlink or containerItem.itemID or containerItem.iconFileID)
                local locked = lockEnabled and hasItem and self:IsItemLocked(bagID, slot)
                if locked then
                    self:EnsureItemLockButtonHooks(button)
                    local overlay = EnsureLockOverlay(button)
                    overlay:Show()
                    self.itemLockOverlayButtons[button] = true
                end
                if scrapIconEnabled and hasItem and Merchants and Merchants.Api and Merchants.Api.ReadContainerItem then
                    local itemContext = Merchants.Api:ReadContainerItem(bagID, slot)
                    if itemContext and Merchants.IsScrapItem and Merchants:IsScrapItem(itemContext) then
                        local overlay = EnsureScrapIconOverlay(button)
                        overlay:Show()
                        self.scrapIconOverlayButtons[button] = true
                    end
                end
                if questIconEnabled and hasItem and not locked and self:IsQuestItem(bagID, slot) then
                    local overlay = EnsureQuestIconOverlay(button)
                    overlay:Show()
                    self.questIconOverlayButtons[button] = true
                end
                if lockEnabled
                    and hasItem
                    and not suppressClickOverlays
                    and (
                        altDown
                        or (locked and (cursorHasItem or merchantOpen))
                    )
                then
                    self:EnsureItemLockClickOverlay(button)
                elseif scrapShortcutEnabled
                    and hasItem
                    and altDown
                    and not suppressClickOverlays
                then
                    self:EnsureItemLockClickOverlay(button)
                end
            end
        end
    end
end

function Bags:ClearItemLockOverlays()
    self:ClearItemOverlays()
end

function Bags:RefreshItemLockOverlays()
    self:RefreshItemOverlays()
end

function Bags:RefreshScrapIconOverlays()
    self:RefreshItemOverlays()
end
