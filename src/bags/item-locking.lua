local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:GetModule("bags")

local MODIFIER_REFRESH_INTERVAL = 0.05
local STALE_LOCK_CONFIRM_SECONDS = 0.75

-- Item locking is a user-level safety lock, not Blizzard's transient container
-- item lock. Keep these guarantees in sync when touching bags, sorting, or
-- merchants:
-- - Alt-left-click toggles a lock for the current item stack in that slot.
-- - Alt-right-click toggles the current item as scrap through the merchant
--   module when scrap selling is enabled.
-- - Safe right-click use stays on Blizzard's item button. Do not wrap or
--   forward normal item use from addon code; that taints UseContainerItem.
-- - Plain left-click on a locked item is undone after Blizzard picks it up,
--   because pre-click blocking would also taint safe right-click use.
-- - Dragging a locked item, or dropping another item onto it, is blocked.
-- - Merchant right-click sell is blocked. The merchant overlay is a sibling
--   above the item button, owns the tooltip, and temporarily disables mouse on
--   the item button so the sell cursor/purse hint never appears.
-- - Tooltips still show while temporary overlays own the mouse.
-- - Scrap mark mode owns its own item overlay; it delegates Alt-left lock
--   toggles instead of sharing this click overlay.
-- - Sorting and bank stacking skip locked slots entirely.
-- - Merchant scrap detection and selling treat locked items as unsellable.
-- - Locks are slot + item-fingerprint based. If a slot changes, stale locks
--   are pruned only after a short confirmation window to avoid transient reads.
-- The click overlay should exist only for interactions we must intercept:
-- Alt-toggle, cursor-drop protection, and locked merchant protection.
local modifierFrame = CreateFrame("Frame")

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function GetSlotKey(bagID, slot)
    return tostring(bagID) .. ":" .. tostring(slot)
end

local function GetStableTime()
    if type(GetTime) == "function" then
        return GetTime()
    end
    return nil
end

local function ParseSlotKey(slotKey)
    if type(slotKey) ~= "string" then
        return nil, nil
    end

    local bagID, slot = string.match(slotKey, "^(-?%d+):(%d+)$")
    return tonumber(bagID), tonumber(slot)
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

local function ClearPendingItemLockPrune(slotKey)
    if Bags.pendingItemLockPrunes then
        Bags.pendingItemLockPrunes[slotKey] = nil
    end
end

local function ShouldPruneItemLock(slotKey, reason, observedFingerprint)
    local now = GetStableTime()
    if not now then
        return true
    end

    Bags.pendingItemLockPrunes = Bags.pendingItemLockPrunes or {}
    local pending = Bags.pendingItemLockPrunes[slotKey]
    if not pending
        or pending.reason ~= reason
        or pending.observedFingerprint ~= observedFingerprint
    then
        Bags.pendingItemLockPrunes[slotKey] = {
            reason = reason,
            observedFingerprint = observedFingerprint,
            started = now,
        }
        return false
    end

    return now - (pending.started or now) >= STALE_LOCK_CONFIRM_SECONDS
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

local function IsAltRightClick(mouseButton)
    return mouseButton == "RightButton" and type(IsAltKeyDown) == "function" and IsAltKeyDown()
end

local function GetMerchantsModule()
    return VanillaEnhanced:GetModule("merchants")
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

local function GetClickOverlayParent(button)
    if button and button.GetParent then
        return button:GetParent()
    end
    return button
end

local function PositionClickOverlay(overlay, button, levelOffset)
    local parent = GetClickOverlayParent(button)
    if parent and overlay.SetParent and overlay.GetParent and overlay:GetParent() ~= parent then
        overlay:SetParent(parent)
    end

    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    if overlay.SetFrameLevel and button.GetFrameLevel then
        overlay:SetFrameLevel((button:GetFrameLevel() or 0) + (levelOffset or 20))
    end
end

local function ShowBagItemTooltip(owner, button)
    if not owner or not button or not GameTooltip then
        return
    end

    local bagID, slot = GetButtonBagAndSlot(button)
    if bagID == nil or slot == nil or type(GameTooltip.SetBagItem) ~= "function" then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if pcall(GameTooltip.SetBagItem, GameTooltip, bagID, slot) then
        GameTooltip:Show()
    end
end

local function HideTooltipOwnedBy(owner)
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(owner) then
        GameTooltip:Hide()
    end
end

local function ShowItemButtonTooltip(button, ...)
    if not button then
        return
    end

    local onEnter = button.GetScript and button:GetScript("OnEnter")
    if onEnter then
        return onEnter(button, ...)
    end

    ShowBagItemTooltip(button, button)
end

local function HideItemButtonTooltip(button, ...)
    if not button then
        return
    end

    local onLeave = button.GetScript and button:GetScript("OnLeave")
    if onLeave then
        onLeave(button, ...)
    end

    HideTooltipOwnedBy(button)
end

local function ShouldUseDirectOverlayTooltip(button)
    local bagID, slot = GetButtonBagAndSlot(button)
    return bagID ~= nil
        and slot ~= nil
        and IsMerchantOpen()
        and Bags:IsItemLocked(bagID, slot)
end

local function SetItemButtonMouseSuppressed(button, suppressed)
    if not button or not button.EnableMouse then
        return
    end

    if suppressed then
        if button.VanillaEnhancedItemLockMouseSuppressed then
            return
        end

        local wasEnabled = true
        if button.IsMouseEnabled then
            wasEnabled = button:IsMouseEnabled() == true
        end
        button.VanillaEnhancedItemLockMouseWasEnabled = wasEnabled
        button.VanillaEnhancedItemLockMouseSuppressed = true
        button:EnableMouse(false)
        return
    end

    if not button.VanillaEnhancedItemLockMouseSuppressed then
        return
    end

    local wasEnabled = button.VanillaEnhancedItemLockMouseWasEnabled ~= false
    button.VanillaEnhancedItemLockMouseSuppressed = nil
    button.VanillaEnhancedItemLockMouseWasEnabled = nil
    button:EnableMouse(wasEnabled)
end

local function ClearItemLockClickOverlay(button)
    SetItemButtonMouseSuppressed(button, false)

    local overlay = button and button.VanillaEnhancedItemLockClickOverlay
    if not overlay then
        return
    end

    if overlay.VanillaEnhancedItemLockDirectTooltip then
        overlay.VanillaEnhancedItemLockDirectTooltip = nil
        HideTooltipOwnedBy(overlay)
    end
    overlay:Hide()
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

        if slotState ~= "readable" or not fingerprint or fingerprint == lockFingerprint then
            ClearPendingItemLockPrune(slotKey)
        elseif ShouldPruneItemLock(slotKey, slotState, fingerprint) then
            locks[slotKey] = nil
            ClearPendingItemLockPrune(slotKey)
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
    local slotKey = GetSlotKey(bagID, slot)
    local lock = locks[slotKey]
    if type(lock) ~= "table" or not lock.fingerprint then
        return false
    end

    local fingerprint = GetItemFingerprint(bagID, slot, itemContext)
    if fingerprint == lock.fingerprint then
        ClearPendingItemLockPrune(slotKey)
        return true
    end

    if not fingerprint then
        ClearPendingItemLockPrune(slotKey)
        return false
    end

    local slotState = GetContainerSlotState(bagID, slot)
    if slotState == "readable" and ShouldPruneItemLock(slotKey, slotState, fingerprint) then
        locks[slotKey] = nil
        ClearPendingItemLockPrune(slotKey)
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
        ClearPendingItemLockPrune(slotKey)
        self:PrintMessage(T("bags.lock.unlocked", { item = itemText }))
        self:RefreshItemOverlays()
        return true
    end

    locks[slotKey] = {
        fingerprint = fingerprint,
        itemID = itemID,
        link = link,
    }
    ClearPendingItemLockPrune(slotKey)
    self:PrintMessage(T("bags.lock.locked", { item = itemText }))
    self:RefreshItemOverlays()
    return true
end

function Bags:HandleItemLockOverlayClick(button, mouseButton)
    local bagID, slot = GetButtonBagAndSlot(button)
    if bagID == nil or slot == nil then
        return false
    end

    if IsAltRightClick(mouseButton) then
        local Merchants = GetMerchantsModule()
        if Merchants and Merchants.ToggleCustomScrapItemForSlot then
            Merchants:ToggleCustomScrapItemForSlot(bagID, slot)
            return true
        end
    end

    if IsAltLeftClick(mouseButton) then
        return self:ToggleItemLock(bagID, slot)
    end

    if not self:IsItemLocked(bagID, slot) then
        return false
    end

    if IsMerchantOpen() then
        local message = mouseButton == "RightButton" and T("bags.lock.cannotSell") or T("bags.lock.cannotMove")
        self:PrintMessage(message)
        return true
    end

    if HasCursorItem() or mouseButton == "LeftButton" then
        self:PrintMessage(T("bags.lock.cannotMove"))
        return true
    end

    return false
end

function Bags:ClearItemLockClickOverlay(button)
    ClearItemLockClickOverlay(button)
end

function Bags:HandleBlockedItemLockInteraction(button, mouseButton)
    local bagID, slot = GetButtonBagAndSlot(button)
    if bagID == nil or slot == nil or not self:IsItemLocked(bagID, slot) then
        return false
    end

    local message = mouseButton == "RightButton" and IsMerchantOpen()
        and T("bags.lock.cannotSell")
        or T("bags.lock.cannotMove")
    self:PrintMessage(message)
    return true
end

function Bags:HandleItemLockPostClick(button, mouseButton)
    if mouseButton ~= "LeftButton" or IsAltLeftClick(mouseButton) then
        return false
    end

    local bagID, slot = GetButtonBagAndSlot(button)
    if bagID == nil or slot == nil or not self:IsItemLocked(bagID, slot) then
        return false
    end

    if not HasCursorItem() then
        return false
    end

    local ok = false
    if self.Api and self.Api.PickupContainerItem then
        ok = pcall(self.Api.PickupContainerItem, self.Api, bagID, slot)
    elseif type(PickupContainerItem) == "function" then
        ok = pcall(PickupContainerItem, bagID, slot)
    end

    self:PrintMessage(T("bags.lock.cannotMove"))
    return ok
end

local function RefreshOriginalButtonScript(button, scriptName, wrapperKey, originalKey)
    if not button or not button.GetScript or not button.SetScript then
        return
    end

    local wrapper = button[wrapperKey]
    local currentScript = button:GetScript(scriptName)
    if currentScript ~= wrapper then
        button[originalKey] = currentScript
        button:SetScript(scriptName, wrapper)
    end
end

function Bags:EnsureItemLockButtonHooks(button)
    if not button or not button.SetScript then
        return
    end

    if not button.VanillaEnhancedItemLockDragStartWrapper then
        button.VanillaEnhancedItemLockDragStartWrapper = function(self, ...)
            if Bags:HandleBlockedItemLockInteraction(self, "LeftButton") then
                return
            end

            local original = self.VanillaEnhancedItemLockOriginalOnDragStart
            if original then
                return original(self, ...)
            end
        end
    end

    if not button.VanillaEnhancedItemLockReceiveDragWrapper then
        button.VanillaEnhancedItemLockReceiveDragWrapper = function(self, ...)
            if Bags:HandleBlockedItemLockInteraction(self, "LeftButton") then
                return
            end

            local original = self.VanillaEnhancedItemLockOriginalOnReceiveDrag
            if original then
                return original(self, ...)
            end
        end
    end

    if button.HookScript and not button.VanillaEnhancedItemLockPostClickHooked then
        button:HookScript("OnClick", function(self, mouseButton)
            Bags:HandleItemLockPostClick(self, mouseButton)
        end)
        button.VanillaEnhancedItemLockPostClickHooked = true
    end

    RefreshOriginalButtonScript(
        button,
        "OnDragStart",
        "VanillaEnhancedItemLockDragStartWrapper",
        "VanillaEnhancedItemLockOriginalOnDragStart"
    )
    RefreshOriginalButtonScript(
        button,
        "OnReceiveDrag",
        "VanillaEnhancedItemLockReceiveDragWrapper",
        "VanillaEnhancedItemLockOriginalOnReceiveDrag"
    )

    self.itemLockHookedButtons = self.itemLockHookedButtons or {}
    self.itemLockHookedButtons[button] = true
end

function Bags:RestoreItemLockButtonHooks(button)
    if not button or not button.SetScript then
        return
    end

    if button.GetScript and button:GetScript("OnDragStart") == button.VanillaEnhancedItemLockDragStartWrapper then
        button:SetScript("OnDragStart", button.VanillaEnhancedItemLockOriginalOnDragStart)
    end
    if button.GetScript and button:GetScript("OnReceiveDrag") == button.VanillaEnhancedItemLockReceiveDragWrapper then
        button:SetScript("OnReceiveDrag", button.VanillaEnhancedItemLockOriginalOnReceiveDrag)
    end

    button.VanillaEnhancedItemLockDragStartWrapper = nil
    button.VanillaEnhancedItemLockReceiveDragWrapper = nil
    button.VanillaEnhancedItemLockOriginalOnDragStart = nil
    button.VanillaEnhancedItemLockOriginalOnReceiveDrag = nil

    if self.itemLockHookedButtons then
        self.itemLockHookedButtons[button] = nil
    end
end

function Bags:ClearItemLockButtonHooks()
    for button in pairs(self.itemLockHookedButtons or {}) do
        self:RestoreItemLockButtonHooks(button)
    end
end

function Bags:EnsureItemLockClickOverlay(button)
    if not button then
        return nil
    end

    local overlay = button.VanillaEnhancedItemLockClickOverlay
    if not overlay then
        overlay = CreateFrame("Button", nil, GetClickOverlayParent(button))
        overlay:RegisterForClicks("AnyUp")
        overlay:RegisterForDrag("LeftButton")
        overlay:EnableMouse(true)
        overlay:SetScript("OnClick", function(_, mouseButton)
            Bags:HandleItemLockOverlayClick(button, mouseButton)
        end)
        overlay:SetScript("OnDragStart", function(_, mouseButton)
            Bags:HandleBlockedItemLockInteraction(button, mouseButton or "LeftButton")
        end)
        overlay:SetScript("OnReceiveDrag", function()
            Bags:HandleBlockedItemLockInteraction(button, "LeftButton")
        end)
        overlay:SetScript("OnEnter", function(self, ...)
            self.VanillaEnhancedItemLockDirectTooltip = ShouldUseDirectOverlayTooltip(button)
            if self.VanillaEnhancedItemLockDirectTooltip then
                ShowBagItemTooltip(self, button)
                return
            end

            ShowItemButtonTooltip(button, ...)
        end)
        overlay:SetScript("OnLeave", function(self, ...)
            if self.VanillaEnhancedItemLockDirectTooltip then
                self.VanillaEnhancedItemLockDirectTooltip = nil
                HideTooltipOwnedBy(self)
                return
            end

            HideItemButtonTooltip(button, ...)
        end)
        button.VanillaEnhancedItemLockClickOverlay = overlay
    end

    PositionClickOverlay(overlay, button, 20)
    SetItemButtonMouseSuppressed(button, ShouldUseDirectOverlayTooltip(button))
    overlay:Show()

    self.itemLockClickOverlayButtons = self.itemLockClickOverlayButtons or {}
    self.itemLockClickOverlayButtons[button] = true
    return overlay
end

function Bags:HandleItemLockClick(button, mouseButton)
    local bagID, slot = GetButtonBagAndSlot(button)
    if bagID == nil or slot == nil then
        return false
    end

    if IsAltRightClick(mouseButton) then
        local Merchants = GetMerchantsModule()
        if Merchants and Merchants.ToggleCustomScrapItemForSlot then
            Merchants:ToggleCustomScrapItemForSlot(bagID, slot)
            return true
        end
        return false
    end

    if not self:IsItemLockingEnabled() then
        return false
    end

    if IsAltLeftClick(mouseButton) then
        return self:ToggleItemLock(bagID, slot)
    end

    return false
end

function Bags:RefreshItemLockClickOverlays()
    self:RefreshItemOverlays()

    local Merchants = VanillaEnhanced:GetModule("merchants")
    if Merchants and Merchants.RefreshScrapHighlights and Merchants.scrapMarkMode == true then
        Merchants:RefreshScrapHighlights()
    end
end

function Bags:InstallItemLockHooks()
    if self.itemLockHooksInstalled then
        return
    end

    -- Keep inventory item use untainted: never replace ContainerFrameItemButton_* globals here.
    -- Temporary sibling overlays handle only the clicks this module must intercept.
    self.lastItemLockAltDown = type(IsAltKeyDown) == "function" and IsAltKeyDown()
    self.lastItemLockCursorHasItem = HasCursorItem()
    modifierFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
    modifierFrame:SetScript("OnEvent", function(_, _, key)
        if key == "LALT" or key == "RALT" then
            Bags:RefreshItemLockClickOverlays()
        end
    end)
    modifierFrame:SetScript("OnUpdate", function(_, elapsed)
        Bags.itemLockModifierRefreshElapsed = (Bags.itemLockModifierRefreshElapsed or 0) + (elapsed or 0)
        if Bags.itemLockModifierRefreshElapsed < MODIFIER_REFRESH_INTERVAL then
            return
        end

        Bags.itemLockModifierRefreshElapsed = 0
        local altDown = type(IsAltKeyDown) == "function" and IsAltKeyDown()
        local cursorHasItem = HasCursorItem()
        if altDown ~= Bags.lastItemLockAltDown or cursorHasItem ~= Bags.lastItemLockCursorHasItem then
            Bags.lastItemLockAltDown = altDown
            Bags.lastItemLockCursorHasItem = cursorHasItem
            Bags:RefreshItemLockClickOverlays()
        end
    end)

    self.itemLockHooksInstalled = true
    self:RefreshItemLockClickOverlays()
end
