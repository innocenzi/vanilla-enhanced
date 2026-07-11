local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:GetModule("bags")

local PLAYER_BAGS = { 0, 1, 2, 3, 4 }

local function GetSlotKey(bagID, slot)
    return bagID .. ":" .. slot
end

local function GetItemID(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(string.match(link, "item:(%d+)"))
end

local function GetFingerprint(containerItem, link)
    if type(link) == "string" and link ~= "" then
        return "link:" .. link
    end

    local itemID = containerItem and containerItem.itemID or GetItemID(link)
    if type(itemID) == "number" and itemID > 0 then
        return "id:" .. itemID
    end
end

local function AddTotal(totals, fingerprint, count)
    totals[fingerprint] = (totals[fingerprint] or 0) + count
end

function Bags:IsRecentItemHighlightEnabled()
    return self:IsSortEnabled() and self:GetSettings().highlightRecentItems ~= false
end

function Bags:BuildRecentItemSnapshot()
    local snapshot = {
        slots = {},
        totals = {},
    }

    for _, bagID in ipairs(PLAYER_BAGS) do
        local slotCount = self.Api and self.Api:GetContainerNumSlots(bagID)
        if type(slotCount) ~= "number" then
            return nil
        end

        for slot = 1, slotCount do
            local containerItem = self.Api:GetContainerItemInfo(bagID, slot)
            if containerItem and containerItem.isLocked then
                return nil
            end

            if containerItem then
                local link = containerItem.hyperlink or self.Api:GetContainerItemLink(bagID, slot)
                local hasItem = link or containerItem.itemID or containerItem.iconFileID
                if hasItem then
                    local fingerprint = GetFingerprint(containerItem, link)
                    if not fingerprint then
                        return nil
                    end

                    local count = tonumber(containerItem.stackCount) or 1
                    if count < 1 then
                        count = 1
                    end

                    local slotInfo = {
                        bagID = bagID,
                        slot = slot,
                        fingerprint = fingerprint,
                        count = count,
                    }
                    snapshot.slots[GetSlotKey(bagID, slot)] = slotInfo
                    AddTotal(snapshot.totals, fingerprint, count)
                end
            end
        end
    end

    return snapshot
end

function Bags:ClearRecentItems()
    self.recentItemQuantities = nil
    self.recentItemSlots = nil
    if self.ClearRecentItemHighlights then
        self:ClearRecentItemHighlights()
    end
end

function Bags:InitializeRecentItemTracking()
    self:ClearRecentItems()
    self.recentItemSnapshot = self:BuildRecentItemSnapshot()
end

function Bags:RebuildRecentItemSlots(snapshot, changedSlots)
    local quantities = self.recentItemQuantities or {}
    local selected = {}
    local allocated = {}

    local function SelectSlot(slotKey, slotInfo)
        if selected[slotKey] or not quantities[slotInfo.fingerprint] then
            return
        end
        selected[slotKey] = slotInfo.fingerprint
        allocated[slotInfo.fingerprint] = (allocated[slotInfo.fingerprint] or 0) + slotInfo.count
    end

    for slotKey, fingerprint in pairs(self.recentItemSlots or {}) do
        local slotInfo = snapshot.slots[slotKey]
        if slotInfo and slotInfo.fingerprint == fingerprint then
            SelectSlot(slotKey, slotInfo)
        end
    end

    for slotKey in pairs(changedSlots or {}) do
        local slotInfo = snapshot.slots[slotKey]
        if slotInfo then
            SelectSlot(slotKey, slotInfo)
        end
    end

    for slotKey, slotInfo in pairs(snapshot.slots) do
        local needed = quantities[slotInfo.fingerprint]
        if needed and (allocated[slotInfo.fingerprint] or 0) < needed then
            SelectSlot(slotKey, slotInfo)
        end
    end

    self.recentItemSlots = selected
end

function Bags:ReconcileRecentItems(suppressAcquisitions)
    if self.sorting == true then
        return false
    end

    local snapshot = self:BuildRecentItemSnapshot()
    if not snapshot then
        return false
    end

    local previous = self.recentItemSnapshot
    self.recentItemSnapshot = snapshot
    if not previous then
        return true
    end

    if not self:IsRecentItemHighlightEnabled() then
        self:ClearRecentItems()
        return true
    end

    local changedSlots = {}
    if not suppressAcquisitions then
        self.recentItemQuantities = self.recentItemQuantities or {}
        for fingerprint, total in pairs(snapshot.totals) do
            local gained = total - (previous.totals[fingerprint] or 0)
            if gained > 0 then
                self.recentItemQuantities[fingerprint] = (self.recentItemQuantities[fingerprint] or 0) + gained
            end
        end

        for slotKey, slotInfo in pairs(snapshot.slots) do
            local oldSlot = previous.slots[slotKey]
            if not oldSlot
                or oldSlot.fingerprint ~= slotInfo.fingerprint
                or oldSlot.count < slotInfo.count
            then
                changedSlots[slotKey] = true
            end
        end
    end

    for fingerprint in pairs(self.recentItemQuantities or {}) do
        if not snapshot.totals[fingerprint] then
            self.recentItemQuantities[fingerprint] = nil
        end
    end

    self:RebuildRecentItemSlots(snapshot, changedSlots)
    if self.QueueUpdate then
        self:QueueUpdate()
    end
    return true
end

function Bags:IsRecentItem(bagID, slot)
    if not self:IsRecentItemHighlightEnabled() then
        return false
    end
    return self.recentItemSlots ~= nil and self.recentItemSlots[GetSlotKey(bagID, slot)] ~= nil
end

function Bags:AcknowledgeRecentItem(bagID, slot)
    local slotKey = GetSlotKey(bagID, slot)
    local fingerprint = self.recentItemSlots and self.recentItemSlots[slotKey]
    if not fingerprint then
        return false
    end

    local quantity = self.recentItemQuantities and self.recentItemQuantities[fingerprint]
    local slotInfo = self.recentItemSnapshot and self.recentItemSnapshot.slots[slotKey]
    if quantity then
        local acknowledged = slotInfo and slotInfo.count or quantity
        quantity = quantity - math.min(quantity, acknowledged)
        if quantity > 0 then
            self.recentItemQuantities[fingerprint] = quantity
        else
            self.recentItemQuantities[fingerprint] = nil
        end
    end

    self.recentItemSlots[slotKey] = nil
    if self.recentItemSnapshot then
        self:RebuildRecentItemSlots(self.recentItemSnapshot)
    end
    if self.QueueUpdate then
        self:QueueUpdate()
    end
    return true
end

function Bags:OnRecentItemsBankStateChanged(isOpen)
    self.recentItemsBankOpen = isOpen == true
    self.recentItemSnapshot = self:BuildRecentItemSnapshot() or self.recentItemSnapshot
end
