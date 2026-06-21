local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:GetModule("bags")

local LOCK_ICON = "Interface\\Buttons\\LockButton-Locked-Up"
local LOCK_SIZE = 25
local MAX_CONTAINER_BUTTONS = 100

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

local function GetSlotKey(bagID, slot)
    return tostring(bagID) .. ":" .. tostring(slot)
end

local function ParseSlotKey(slotKey)
    if type(slotKey) ~= "string" then
        return nil, nil
    end

    local bagID, slot = string.match(slotKey, "^(-?%d+):(%d+)$")
    return tonumber(bagID), tonumber(slot)
end

local function GetContainerItemButton(frame, index)
    local frameName = frame and frame.GetName and frame:GetName()
    return frameName and _G[frameName .. "Item" .. index] or nil
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

local function GetItemIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(string.match(link, "item:(%d+)"))
end

local function GetItemFingerprint(bagID, slot, itemContext)
    local itemID = itemContext and itemContext.itemID
    local link = itemContext and itemContext.link

    if not itemID or not link then
        local containerItem = Bags.Api and Bags.Api:GetContainerItemInfo(bagID, slot)
        itemID = itemID or (containerItem and containerItem.itemID)
        link = link or (containerItem and (containerItem.hyperlink or Bags.Api:GetContainerItemLink(bagID, slot)))
    end

    itemID = tonumber(itemID) or GetItemIDFromLink(link)
    if itemID then
        return "id:" .. itemID, itemID, link
    end
    if link then
        return "link:" .. link, nil, link
    end

    return nil, nil, nil
end

local function GetContainerSlotState(bagID, slot)
    if not Bags.Api or not Bags.Api.GetContainerNumSlots then
        return "unavailable"
    end

    local slotCount = Bags.Api:GetContainerNumSlots(bagID)
    if type(slotCount) ~= "number" then
        return "unavailable"
    end
    if slot > slotCount then
        return "missing"
    end

    return "readable"
end

local function GetItemDisplayText(itemID, link)
    if link then
        return link
    end
    if itemID then
        return T("bags.lock.itemFallback", { itemID = itemID })
    end
    return T("bags.lock.itemUnknown")
end

local function IsAltLeftClick(mouseButton)
    return mouseButton == "LeftButton" and type(IsAltKeyDown) == "function" and IsAltKeyDown()
end

local function IsMerchantOpen()
    local Merchants = VanillaEnhanced:GetModule("merchants")
    if Merchants and Merchants.IsMerchantOpen then
        return Merchants:IsMerchantOpen()
    end
    return MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()
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

function Bags:GetItemLocks()
    local settings = self:GetSettings()
    if type(settings.itemLocks) ~= "table" then
        settings.itemLocks = {}
    end
    return settings.itemLocks
end

function Bags:IsItemLockingEnabled()
    local settings = self:GetSettings()
    return self:IsSortEnabled() and settings.enableItemLocking ~= false
end

function Bags:PruneItemLocks()
    local locks = self:GetItemLocks()
    local changed = false

    for slotKey, lock in pairs(locks) do
        local bagID, slot = ParseSlotKey(slotKey)
        local slotState = bagID and slot and GetContainerSlotState(bagID, slot) or "missing"
        local fingerprint = slotState == "readable" and GetItemFingerprint(bagID, slot) or nil
        local lockFingerprint = type(lock) == "table" and lock.fingerprint or nil

        if slotState ~= "unavailable" and (not fingerprint or fingerprint ~= lockFingerprint) then
            locks[slotKey] = nil
            changed = true
        end
    end

    return changed
end

function Bags:IsItemLocked(bagID, slot, itemContext)
    if not self:IsItemLockingEnabled() then
        return false
    end

    local locks = self:GetItemLocks()
    local lock = locks[GetSlotKey(bagID, slot)]
    if type(lock) ~= "table" or not lock.fingerprint then
        return false
    end

    local fingerprint = GetItemFingerprint(bagID, slot, itemContext)
    if fingerprint == lock.fingerprint then
        return true
    end

    if GetContainerSlotState(bagID, slot) ~= "unavailable" then
        locks[GetSlotKey(bagID, slot)] = nil
    end
    return false
end

function Bags:ToggleItemLock(bagID, slot)
    if not self:IsItemLockingEnabled() then
        return false
    end

    local fingerprint, itemID, link = GetItemFingerprint(bagID, slot)
    if not fingerprint then
        return false
    end

    local locks = self:GetItemLocks()
    local slotKey = GetSlotKey(bagID, slot)
    local itemText = GetItemDisplayText(itemID, link)

    if self:IsItemLocked(bagID, slot) then
        locks[slotKey] = nil
        self:PrintMessage(T("bags.lock.unlocked", { item = itemText }))
        self:RefreshItemLockOverlays()
        return true
    end

    locks[slotKey] = {
        fingerprint = fingerprint,
        itemID = itemID,
        link = link,
    }
    self:PrintMessage(T("bags.lock.locked", { item = itemText }))
    self:RefreshItemLockOverlays()
    return true
end

function Bags:ClearItemLockOverlays()
    for button in pairs(self.itemLockOverlayButtons or {}) do
        if button.VanillaEnhancedItemLockOverlay then
            button.VanillaEnhancedItemLockOverlay:Hide()
        end
        self.itemLockOverlayButtons[button] = nil
    end
end

function Bags:RefreshItemLockOverlays()
    self:ClearItemLockOverlays()
    self.itemLockOverlayButtons = self.itemLockOverlayButtons or {}

    if not self:IsItemLockingEnabled() then
        return
    end

    self:PruneItemLocks()

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
                if IsShown(button) and self:IsItemLocked(bagID, slot) then
                    local overlay = EnsureLockOverlay(button)
                    overlay:Show()
                    self.itemLockOverlayButtons[button] = true
                end
            end
        end
    end
end

function Bags:ShouldBlockLockedItemClick(bagID, slot, mouseButton)
    if not self:IsItemLocked(bagID, slot) then
        return false, nil
    end

    if mouseButton == "RightButton" and IsMerchantOpen() then
        return true, T("bags.lock.cannotSell")
    end

    if mouseButton == "RightButton" then
        local link = self.Api and self.Api:GetContainerItemLink(bagID, slot)
        if link and self.Api.IsEquippableItem and self.Api:IsEquippableItem(link) then
            return true, T("bags.lock.cannotMove")
        end
        return false, nil
    end

    if mouseButton == "LeftButton" then
        return true, T("bags.lock.cannotMove")
    end

    return false, nil
end

function Bags:HandleItemLockClick(button, mouseButton)
    if not self:IsItemLockingEnabled() then
        return false
    end

    local bagID, slot = GetButtonBagAndSlot(button)
    if bagID == nil or slot == nil then
        return false
    end

    if IsAltLeftClick(mouseButton) then
        return self:ToggleItemLock(bagID, slot)
    end

    local blocked, message = self:ShouldBlockLockedItemClick(bagID, slot, mouseButton)
    if blocked then
        if message then
            self:PrintMessage(message)
        end
        return true
    end

    return false
end

function Bags:InstallItemLockHooks()
    if self.itemLockHooksInstalled then
        return
    end

    local hooked = false
    if type(ContainerFrameItemButton_OnClick) == "function" then
        self.originalContainerFrameItemButtonOnClick = ContainerFrameItemButton_OnClick
        ContainerFrameItemButton_OnClick = function(button, mouseButton, ...)
            if Bags:HandleItemLockClick(button, mouseButton) then
                return
            end
            return Bags.originalContainerFrameItemButtonOnClick(button, mouseButton, ...)
        end
        hooked = true
    end

    if type(ContainerFrameItemButton_OnModifiedClick) == "function" then
        self.originalContainerFrameItemButtonOnModifiedClick = ContainerFrameItemButton_OnModifiedClick
        ContainerFrameItemButton_OnModifiedClick = function(button, mouseButton, ...)
            if Bags:HandleItemLockClick(button, mouseButton) then
                return true
            end
            return Bags.originalContainerFrameItemButtonOnModifiedClick(button, mouseButton, ...)
        end
        hooked = true
    end

    self.itemLockHooksInstalled = hooked
end
