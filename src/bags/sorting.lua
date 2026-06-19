local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:GetModule("bags")

local PLAYER_BAGS = { 0, 1, 2, 3, 4 }
local SORT_WAIT_TIMEOUT = 0.08
local SORT_MIN_POLL_TIMEOUT = 0.03
local LOCK_RETRY_TIMEOUT = 5
local AUTO_SORT_DELAY = 0.25

local sortFrame = CreateFrame("Frame")
local autoSortFrame = CreateFrame("Frame")

local function DebugSort(message)
    if Bags.debugSorting then
        Bags:PrintMessage("Bags debug: " .. message)
    end
end

local function GetItemID(link)
    if type(link) ~= "string" then
        return 0
    end
    return tonumber(string.match(link, "item:(%d+)")) or 0
end

local function CallNativeSort()
    local nativeSort = Bags.Api and Bags.Api:FindContainer("SortBags")
    if nativeSort then
        local ok = pcall(nativeSort)
        return ok
    end
    return false
end

local function GetBagFamily(bagID)
    if bagID == 0 then
        return 0
    end

    local _, family = Bags.Api:GetContainerNumFreeSlots(bagID)
    if type(family) == "number" then
        return family
    end

    local inventoryID = Bags.Api:GetInventoryIDForContainer(bagID)
    if inventoryID and type(GetInventoryItemLink) == "function" then
        local bagLink = GetInventoryItemLink("player", inventoryID)
        local itemFamily = bagLink and Bags.Api:GetItemFamily(bagLink)
        if type(itemFamily) == "number" then
            return itemFamily
        end
    end

    return bagID
end

local function GetSortGroupKey(bagID)
    if GetBagFamily(bagID) == 0 then
        return "normal"
    end
    return "bag:" .. bagID
end

local function GetGroup(groups, groupOrder, groupKey)
    local group = groups[groupKey]
    if group then
        return group
    end

    group = {
        slots = {},
        items = {},
    }
    groups[groupKey] = group
    table.insert(groupOrder, group)
    return group
end

local function ReadItem(bagID, slot)
    local containerItem = Bags.Api:GetContainerItemInfo(bagID, slot)
    local link = containerItem and (containerItem.hyperlink or Bags.Api:GetContainerItemLink(bagID, slot))

    if containerItem and containerItem.isLocked then
        return nil, true
    end
    if not link then
        return nil, false
    end

    local itemInfo = Bags.Api:GetItemInfo(link)
    local count = containerItem and containerItem.stackCount or 1

    return {
        bagID = bagID,
        slot = slot,
        link = link,
        key = link .. ":" .. count,
        count = count,
        name = (itemInfo and itemInfo.name) or link,
        itemType = (itemInfo and itemInfo.itemType) or "",
        itemSubType = (itemInfo and itemInfo.itemSubType) or "",
        quality = (itemInfo and itemInfo.quality) or (containerItem and containerItem.quality) or -1,
        itemLevel = (itemInfo and itemInfo.itemLevel) or 0,
        itemID = (containerItem and containerItem.itemID) or GetItemID(link),
    }, false
end

local SORT_ORDERS = {
    category = {
        "itemTypeAsc",
        "itemSubTypeAsc",
        "qualityDesc",
        "itemLevelDesc",
        "nameAsc",
        "itemIDAsc",
        "countDesc",
    },
    quality = {
        "qualityDesc",
        "itemLevelDesc",
        "itemTypeAsc",
        "itemSubTypeAsc",
        "nameAsc",
        "itemIDAsc",
        "countDesc",
    },
    name = {
        "nameAsc",
        "itemTypeAsc",
        "itemSubTypeAsc",
        "qualityDesc",
        "itemLevelDesc",
        "itemIDAsc",
        "countDesc",
    },
}

local SORT_RULES = {
    itemTypeAsc = function(left, right)
        if left.itemType ~= right.itemType then
            return left.itemType < right.itemType
        end
        return nil
    end,
    itemSubTypeAsc = function(left, right)
        if left.itemSubType ~= right.itemSubType then
            return left.itemSubType < right.itemSubType
        end
        return nil
    end,
    qualityDesc = function(left, right)
        if left.quality ~= right.quality then
            return left.quality > right.quality
        end
        return nil
    end,
    itemLevelDesc = function(left, right)
        if left.itemLevel ~= right.itemLevel then
            return left.itemLevel > right.itemLevel
        end
        return nil
    end,
    nameAsc = function(left, right)
        if left.name ~= right.name then
            return left.name < right.name
        end
        return nil
    end,
    itemIDAsc = function(left, right)
        if left.itemID ~= right.itemID then
            return left.itemID < right.itemID
        end
        return nil
    end,
    countDesc = function(left, right)
        if left.count ~= right.count then
            return left.count > right.count
        end
        return nil
    end,
}

local function GetSortOrder()
    local settings = Bags:GetSettings()
    return SORT_ORDERS[settings.sortOrder] or SORT_ORDERS.category
end

local function CompareItems(left, right)
    local sortOrder = GetSortOrder()
    for _, ruleName in ipairs(sortOrder) do
        local result = SORT_RULES[ruleName](left, right)
        if result ~= nil then
            return result
        end
    end

    return left.key < right.key
end

local function BuildSortGroups()
    local groups = {}
    local groupOrder = {}

    for _, bagID in ipairs(PLAYER_BAGS) do
        local group = GetGroup(groups, groupOrder, GetSortGroupKey(bagID))
        local slotCount = Bags.Api:GetContainerNumSlots(bagID) or 0

        for slot = 1, slotCount do
            local item, locked = ReadItem(bagID, slot)
            if locked then
                return nil, {
                    reason = "locked",
                    bagID = bagID,
                    slot = slot,
                }
            end

            local slotInfo = {
                bagID = bagID,
                slot = slot,
                item = item,
            }
            table.insert(group.slots, slotInfo)
            if item then
                table.insert(group.items, item)
            end
        end
    end

    for _, group in ipairs(groupOrder) do
        table.sort(group.items, CompareItems)
    end

    return groupOrder
end

local function FindNextMove(groups)
    for _, group in ipairs(groups) do
        for targetIndex, desiredItem in ipairs(group.items) do
            local targetSlot = group.slots[targetIndex]
            if targetSlot and (not targetSlot.item or targetSlot.item.key ~= desiredItem.key) then
                for sourceIndex = targetIndex + 1, #group.slots do
                    local sourceSlot = group.slots[sourceIndex]
                    if sourceSlot.item and sourceSlot.item.key == desiredItem.key then
                        return sourceSlot, targetSlot
                    end
                end
                return nil, nil, "Bag sorting stopped because item positions changed unexpectedly."
            end
        end
    end

    return nil, nil, nil
end

function Bags:SortItems()
    if not self:IsSortEnabled() then
        return
    end

    if self.sorting then
        self:PrintMessage("Bag sorting is already running.")
        return
    end

    if CallNativeSort() then
        return
    end

    self:StartManualSort()
end

function Bags:QueueAutoSort(reason)
    if not self:IsSortEnabled() or self.sorting then
        return
    end

    self.pendingAutoSortReason = reason
    self.autoSortElapsed = 0
    autoSortFrame:SetScript("OnUpdate", function(frame, elapsed)
        Bags.autoSortElapsed = (Bags.autoSortElapsed or 0) + elapsed
        if Bags.autoSortElapsed < AUTO_SORT_DELAY then
            return
        end

        frame:SetScript("OnUpdate", nil)
        if not Bags.sorting and Bags:IsSortEnabled() then
            DebugSort("auto sorting after " .. (Bags.pendingAutoSortReason or "trigger"))
            Bags.pendingAutoSortReason = nil
            Bags:SortItems()
        end
    end)
end

function Bags:ClearAutoSort()
    self.pendingAutoSortReason = nil
    self.autoSortElapsed = 0
    autoSortFrame:SetScript("OnUpdate", nil)
end

function Bags:StopManualSort(message)
    self.sorting = false
    self.sortWaiting = false
    self.sortWaitElapsed = 0
    self.lockWaitStarted = nil
    self.lockWaitBagID = nil
    self.lockWaitSlot = nil
    sortFrame:SetScript("OnUpdate", nil)
    self:SetSortButtonBusy(false)
    self:QueueUpdate()

    if message then
        self:PrintMessage(message)
    end
end

function Bags:StartManualSort()
    if not self:IsSortEnabled() then
        self:ClearAutoSort()
        return
    end

    if not self.Api or not self.Api:HasManualSortApis() then
        self:PrintMessage("Manual bag sorting is not available on this client.")
        return
    end

    if self.Api:HasCursorItem() then
        self:PrintMessage("Bag sorting is unavailable while an item is on your cursor.")
        return
    end

    self.sorting = true
    self.lockWaitStarted = nil
    self.lockWaitBagID = nil
    self.lockWaitSlot = nil
    self:SetSortButtonBusy(true)
    self:ContinueManualSort()
end

function Bags:WaitForSortUpdate(timeout)
    self.sortWaiting = true
    self.sortWaitElapsed = 0
    self.sortWaitTimeout = timeout or SORT_WAIT_TIMEOUT

    sortFrame:SetScript("OnUpdate", function(frame, elapsed)
        Bags.sortWaitElapsed = (Bags.sortWaitElapsed or 0) + elapsed
        if Bags.sortWaitElapsed >= (Bags.sortWaitTimeout or SORT_WAIT_TIMEOUT) then
            frame:SetScript("OnUpdate", nil)
            Bags:ContinueManualSort()
        end
    end)
end

function Bags:MoveItem(sourceSlot, targetSlot)
    if self.Api:HasCursorItem() then
        return false, "Bag sorting is unavailable while an item is on your cursor."
    end

    DebugSort("moving bag " .. sourceSlot.bagID .. " slot " .. sourceSlot.slot .. " to bag " .. targetSlot.bagID .. " slot " .. targetSlot.slot)

    local ok = pcall(self.Api.PickupContainerItem, self.Api, sourceSlot.bagID, sourceSlot.slot)
    if not ok then
        return false, "Bag sorting stopped because an item could not be picked up."
    end

    ok = pcall(self.Api.PickupContainerItem, self.Api, targetSlot.bagID, targetSlot.slot)
    if not ok then
        if self.Api:HasCursorItem() then
            pcall(self.Api.PickupContainerItem, self.Api, sourceSlot.bagID, sourceSlot.slot)
        end
        return false, "Bag sorting stopped because an item could not be moved."
    end

    if self.Api:HasCursorItem() then
        pcall(self.Api.PickupContainerItem, self.Api, sourceSlot.bagID, sourceSlot.slot)
        if self.Api:HasCursorItem() then
            return false, "Bag sorting stopped because an item could not be moved."
        end
    end

    self.lockWaitStarted = nil
    self.lockWaitBagID = nil
    self.lockWaitSlot = nil
    return true, nil
end

function Bags:WaitForLockedSlot(lockInfo)
    local now = type(GetTime) == "function" and GetTime() or 0
    local sameSlot = self.lockWaitBagID == lockInfo.bagID and self.lockWaitSlot == lockInfo.slot

    if not self.lockWaitStarted or not sameSlot then
        self.lockWaitStarted = now
        self.lockWaitBagID = lockInfo.bagID
        self.lockWaitSlot = lockInfo.slot
        DebugSort("waiting for locked bag " .. lockInfo.bagID .. " slot " .. lockInfo.slot)
    elseif now - self.lockWaitStarted >= LOCK_RETRY_TIMEOUT then
        self:StopManualSort("Bag sorting stopped because bag " .. lockInfo.bagID .. " slot " .. lockInfo.slot .. " stayed locked.")
        return
    end

    self:WaitForSortUpdate(SORT_MIN_POLL_TIMEOUT)
end

function Bags:ContinueManualSort()
    if not self.sorting then
        return
    end

    self.sortWaiting = false
    sortFrame:SetScript("OnUpdate", nil)

    if self.Api:HasCursorItem() then
        self:StopManualSort("Bag sorting is unavailable while an item is on your cursor.")
        return
    end

    local groups, errorMessage = BuildSortGroups()
    if not groups then
        if type(errorMessage) == "table" and errorMessage.reason == "locked" then
            self:WaitForLockedSlot(errorMessage)
            return
        end
        self:StopManualSort(errorMessage)
        return
    end

    local sourceSlot, targetSlot, moveError = FindNextMove(groups)
    if moveError then
        self:StopManualSort(moveError)
        return
    end
    if not sourceSlot or not targetSlot then
        self:StopManualSort()
        return
    end

    local ok, message = self:MoveItem(sourceSlot, targetSlot)
    if not ok then
        self:StopManualSort(message)
        return
    end

    self:WaitForSortUpdate()
end

function Bags:OnBagUpdateDelayed()
    if self.sorting and self.sortWaiting then
        self:ContinueManualSort()
        return
    end

    self:QueueUpdate()
end
