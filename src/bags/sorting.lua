local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:GetModule("bags")

local PLAYER_BAGS = { 0, 1, 2, 3, 4 }
local SORT_WAIT_TIMEOUT = 0.08
local SORT_MIN_POLL_TIMEOUT = 0.03
local LOCK_RETRY_TIMEOUT = 0.5
local AUTO_SORT_DELAY = 0.25
local SORT_STRATEGY_FULL = "full"
local SORT_STRATEGY_TIDY = "tidy"

local QUALITY_POOR = 0
local ITEM_CLASS_CONSUMABLE = 0
local ITEM_CLASS_CONTAINER = 1
local ITEM_CLASS_WEAPON = 2
local ITEM_CLASS_GEM = 3
local ITEM_CLASS_ARMOR = 4
local ITEM_CLASS_REAGENT = 5
local ITEM_CLASS_PROJECTILE = 6
local ITEM_CLASS_TRADE_GOODS = 7
local ITEM_CLASS_RECIPE = 9
local ITEM_CLASS_QUIVER = 11
local ITEM_CLASS_QUEST = 12
local ITEM_CLASS_KEY = 13

local sortFrame = CreateFrame("Frame")
local autoSortFrame = CreateFrame("Frame")

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function LocalizedSortReason(reason)
    if reason == "open" then
        return T("bags.sort.reasonOpen")
    end
    if reason == "loot" then
        return T("bags.sort.reasonLoot")
    end
    if reason == "merchant" then
        return T("bags.sort.reasonMerchant")
    end
    return reason or T("bags.sort.reasonTrigger")
end

local function DebugSort(message)
    if Bags.debugSorting then
        Bags:PrintMessage(T("bags.sort.debugPrefix", { message = message }))
    end
end

local function GetItemID(link)
    if type(link) ~= "string" then
        return 0
    end
    return tonumber(string.match(link, "item:(%d+)")) or 0
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

local function GetAutoSortStrategy(reason)
    local settings = Bags:GetSettings()
    if reason == "loot" and settings.autoSortAfterLootMode ~= SORT_STRATEGY_FULL then
        return SORT_STRATEGY_TIDY
    end
    return SORT_STRATEGY_FULL
end

local function GetCachedItemInfo(link)
    local cache = Bags.sortItemInfoCache
    if not cache then
        return Bags.Api:GetItemInfo(link)
    end

    local cached = cache[link]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local itemInfo = Bags.Api:GetItemInfo(link)
    cache[link] = itemInfo or false
    return itemInfo
end

local function GetSortGroupKey(bagID)
    if GetBagFamily(bagID) == 0 then
        return "normal"
    end
    return "bag:" .. bagID
end

local function GetSlotKey(bagID, slot)
    return bagID .. ":" .. slot
end

local function IsIgnoredSortSlot(bagID, slot)
    return Bags.ignoredSortSlots and Bags.ignoredSortSlots[GetSlotKey(bagID, slot)] == true
end

local function IgnoreSortSlot(bagID, slot)
    Bags.ignoredSortSlots = Bags.ignoredSortSlots or {}
    Bags.ignoredSortSlots[GetSlotKey(bagID, slot)] = true
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

    local itemInfo = GetCachedItemInfo(link)
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
        classID = itemInfo and itemInfo.classID,
        subclassID = itemInfo and itemInfo.subclassID,
        quality = (itemInfo and itemInfo.quality) or (containerItem and containerItem.quality) or -1,
        itemLevel = (itemInfo and itemInfo.itemLevel) or 0,
        itemID = (containerItem and containerItem.itemID) or GetItemID(link),
    }, false
end

local function ReadSlotKey(bagID, slot)
    local containerItem = Bags.Api:GetContainerItemInfo(bagID, slot)
    local link = containerItem and (containerItem.hyperlink or Bags.Api:GetContainerItemLink(bagID, slot))

    if containerItem and containerItem.isLocked then
        return nil, true
    end
    if not link then
        return nil, false
    end

    local count = containerItem and containerItem.stackCount or 1
    return link .. ":" .. count, false
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

local function CompareItems(left, right, sortOrder)
    for _, ruleName in ipairs(sortOrder) do
        local result = SORT_RULES[ruleName](left, right)
        if result ~= nil then
            return result
        end
    end

    return left.key < right.key
end

local TIDY_BUCKET_ORDER = {
    "quest",
    "equipment",
    "consumable",
    "materials",
    "container",
    "other",
    "junk",
}

local function GetTidyBucket(item)
    local classID = item and item.classID
    local itemType = item and item.itemType

    if item and item.quality == QUALITY_POOR then
        return "junk"
    end
    if classID == ITEM_CLASS_QUEST or classID == ITEM_CLASS_KEY then
        return "quest"
    end
    if classID == ITEM_CLASS_WEAPON or classID == ITEM_CLASS_ARMOR then
        return "equipment"
    end
    if classID == ITEM_CLASS_CONSUMABLE then
        return "consumable"
    end
    if classID == ITEM_CLASS_TRADE_GOODS
        or classID == ITEM_CLASS_REAGENT
        or classID == ITEM_CLASS_GEM
        or classID == ITEM_CLASS_RECIPE
    then
        return "materials"
    end
    if classID == ITEM_CLASS_CONTAINER
        or classID == ITEM_CLASS_QUIVER
        or classID == ITEM_CLASS_PROJECTILE
    then
        return "container"
    end

    if itemType == _G.ITEM_CLASS_QUESTITEM or itemType == _G.ITEM_CLASS_KEY then
        return "quest"
    end
    if itemType == _G.ITEM_CLASS_WEAPON or itemType == _G.ITEM_CLASS_ARMOR then
        return "equipment"
    end
    if itemType == _G.ITEM_CLASS_CONSUMABLE then
        return "consumable"
    end
    if itemType == _G.ITEM_CLASS_TRADEGOODS
        or itemType == _G.ITEM_CLASS_REAGENT
        or itemType == _G.ITEM_CLASS_GEM
        or itemType == _G.ITEM_CLASS_RECIPE
    then
        return "materials"
    end
    if itemType == _G.ITEM_CLASS_CONTAINER
        or itemType == _G.ITEM_CLASS_QUIVER
        or itemType == _G.ITEM_CLASS_PROJECTILE
    then
        return "container"
    end

    return "other"
end

local function ApplyFullSort(group)
    local sortOrder = Bags.sortOrder or GetSortOrder()
    table.sort(group.items, function(left, right)
        return CompareItems(left, right, sortOrder)
    end)
end

local function ApplyTidySort(group)
    local bucketedItems = {}
    local sortedItems = {}

    for _, item in ipairs(group.items) do
        local bucket = GetTidyBucket(item)
        bucketedItems[bucket] = bucketedItems[bucket] or {}
        table.insert(bucketedItems[bucket], item)
    end

    for _, bucket in ipairs(TIDY_BUCKET_ORDER) do
        for _, item in ipairs(bucketedItems[bucket] or {}) do
            table.insert(sortedItems, item)
        end
    end

    group.items = sortedItems
end

local function ApplySortStrategy(group, strategy)
    if strategy == SORT_STRATEGY_TIDY then
        ApplyTidySort(group)
        return
    end

    ApplyFullSort(group)
end

local function BuildSortGroups(strategy)
    local groups = {}
    local groupOrder = {}

    for _, bagID in ipairs(PLAYER_BAGS) do
        local group = GetGroup(groups, groupOrder, GetSortGroupKey(bagID))
        local slotCount = Bags.Api:GetContainerNumSlots(bagID) or 0

        for slot = 1, slotCount do
            if not IsIgnoredSortSlot(bagID, slot) then
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
    end

    for _, group in ipairs(groupOrder) do
        ApplySortStrategy(group, strategy)
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
                return nil, nil, T("bags.sort.errorChanged")
            end
        end
    end

    return nil, nil, nil
end

local function ValidateSortGroups(groups)
    for _, group in ipairs(groups) do
        for _, slotInfo in ipairs(group.slots) do
            local key, locked = ReadSlotKey(slotInfo.bagID, slotInfo.slot)
            if locked then
                return nil, {
                    reason = "locked",
                    bagID = slotInfo.bagID,
                    slot = slotInfo.slot,
                }
            end

            local expectedKey = slotInfo.item and slotInfo.item.key or nil
            if key ~= expectedKey then
                return nil, T("bags.sort.errorChanged")
            end
        end
    end

    return true, nil
end

function Bags:SortItems(suppressErrors, strategy)
    if not self:IsSortEnabled() then
        return
    end

    if self.sorting then
        if not suppressErrors then
            self:PrintMessage(T("bags.sort.errorRunning"))
        end
        return
    end

    self:StartManualSort(suppressErrors, strategy)
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
            local reason = Bags.pendingAutoSortReason
            DebugSort(T("bags.sort.debugAutoSort", {
                reason = LocalizedSortReason(reason),
            }))
            Bags.pendingAutoSortReason = nil
            Bags:SortItems(true, GetAutoSortStrategy(reason))
        end
    end)
end

function Bags:ClearAutoSort()
    self.pendingAutoSortReason = nil
    self.autoSortElapsed = 0
    autoSortFrame:SetScript("OnUpdate", nil)
end

function Bags:StopManualSort(message)
    local suppressErrors = self.suppressSortErrors == true

    self.sorting = false
    self.suppressSortErrors = nil
    self.sortWaiting = false
    self.sortWaitElapsed = 0
    self.lockWaitStarted = nil
    self.lockWaitBagID = nil
    self.lockWaitSlot = nil
    self.sortItemInfoCache = nil
    self.sortOrder = nil
    self.sortStrategy = nil
    self.sortGroups = nil
    self.ignoredSortSlots = nil
    self.pendingSortMove = nil
    self.pendingSortMoveStarted = nil
    sortFrame:SetScript("OnUpdate", nil)
    self:SetSortButtonBusy(false)
    self:QueueUpdate()

    if message and not suppressErrors then
        self:PrintMessage(message)
    end
end

function Bags:StartManualSort(suppressErrors, strategy)
    self.suppressSortErrors = suppressErrors == true

    if not self:IsSortEnabled() then
        self:ClearAutoSort()
        self.suppressSortErrors = nil
        return
    end

    if not self.Api or not self.Api:HasManualSortApis() then
        if not self.suppressSortErrors then
            self:PrintMessage(T("bags.sort.errorUnavailableClient"))
        end
        self.suppressSortErrors = nil
        return
    end

    if self.Api:HasCursorItem() then
        if not self.suppressSortErrors then
            self:PrintMessage(T("bags.sort.errorCursor"))
        end
        self.suppressSortErrors = nil
        return
    end

    self.sorting = true
    self.lockWaitStarted = nil
    self.lockWaitBagID = nil
    self.lockWaitSlot = nil
    self.sortItemInfoCache = {}
    self.sortOrder = GetSortOrder()
    self.sortStrategy = strategy == SORT_STRATEGY_TIDY and SORT_STRATEGY_TIDY or SORT_STRATEGY_FULL
    self.sortGroups = nil
    self.ignoredSortSlots = {}
    self.pendingSortMove = nil
    self.pendingSortMoveStarted = nil
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
        return false, T("bags.sort.errorCursor")
    end

    DebugSort(T("bags.sort.debugMove", {
        sourceBag = sourceSlot.bagID,
        sourceSlot = sourceSlot.slot,
        targetBag = targetSlot.bagID,
        targetSlot = targetSlot.slot,
    }))

    local ok = pcall(self.Api.PickupContainerItem, self.Api, sourceSlot.bagID, sourceSlot.slot)
    if not ok then
        return false, T("bags.sort.errorPickup")
    end

    ok = pcall(self.Api.PickupContainerItem, self.Api, targetSlot.bagID, targetSlot.slot)
    if not ok then
        if self.Api:HasCursorItem() then
            pcall(self.Api.PickupContainerItem, self.Api, sourceSlot.bagID, sourceSlot.slot)
        end
        return false, T("bags.sort.errorMove")
    end

    if self.Api:HasCursorItem() then
        pcall(self.Api.PickupContainerItem, self.Api, sourceSlot.bagID, sourceSlot.slot)
        if self.Api:HasCursorItem() then
            return false, T("bags.sort.errorMove")
        end
    end

    self.lockWaitStarted = nil
    self.lockWaitBagID = nil
    self.lockWaitSlot = nil

    local sourceItem = sourceSlot.item
    local targetItem = targetSlot.item
    sourceSlot.item = targetSlot.item
    targetSlot.item = sourceItem

    self.pendingSortMove = {
        sourceBagID = sourceSlot.bagID,
        sourceSlotID = sourceSlot.slot,
        targetBagID = targetSlot.bagID,
        targetSlotID = targetSlot.slot,
        oldSourceKey = sourceItem and sourceItem.key or nil,
        oldTargetKey = targetItem and targetItem.key or nil,
        expectedSourceKey = targetItem and targetItem.key or nil,
        expectedTargetKey = sourceItem and sourceItem.key or nil,
    }
    self.pendingSortMoveStarted = type(GetTime) == "function" and GetTime() or 0

    return true, nil
end

function Bags:WaitForLockedSlot(lockInfo)
    local now = type(GetTime) == "function" and GetTime() or 0
    local sameSlot = self.lockWaitBagID == lockInfo.bagID and self.lockWaitSlot == lockInfo.slot

    if not self.lockWaitStarted or not sameSlot then
        self.lockWaitStarted = now
        self.lockWaitBagID = lockInfo.bagID
        self.lockWaitSlot = lockInfo.slot
        DebugSort(T("bags.sort.debugWaitLocked", { bag = lockInfo.bagID, slot = lockInfo.slot }))
    elseif now - self.lockWaitStarted >= LOCK_RETRY_TIMEOUT then
        IgnoreSortSlot(lockInfo.bagID, lockInfo.slot)
        self.lockWaitStarted = nil
        self.lockWaitBagID = nil
        self.lockWaitSlot = nil
        self.sortGroups = nil
        self.pendingSortMove = nil
        self.pendingSortMoveStarted = nil
        DebugSort(T("bags.sort.debugIgnoreLocked", { bag = lockInfo.bagID, slot = lockInfo.slot }))
        self:ContinueManualSort()
        return
    end

    self:WaitForSortUpdate(SORT_MIN_POLL_TIMEOUT)
end

function Bags:WaitForPendingMove()
    local pendingMove = self.pendingSortMove
    if not pendingMove then
        return false, nil
    end

    local sourceKey, sourceLocked = ReadSlotKey(pendingMove.sourceBagID, pendingMove.sourceSlotID)
    local targetKey, targetLocked = ReadSlotKey(pendingMove.targetBagID, pendingMove.targetSlotID)

    if sourceLocked or targetLocked then
        self:WaitForLockedSlot({
            bagID = sourceLocked and pendingMove.sourceBagID or pendingMove.targetBagID,
            slot = sourceLocked and pendingMove.sourceSlotID or pendingMove.targetSlotID,
        })
        return true, nil
    end

    if sourceKey == pendingMove.expectedSourceKey and targetKey == pendingMove.expectedTargetKey then
        self.pendingSortMove = nil
        self.pendingSortMoveStarted = nil
        self.lockWaitStarted = nil
        self.lockWaitBagID = nil
        self.lockWaitSlot = nil
        return false, nil
    end

    local sourceKnown = sourceKey == pendingMove.oldSourceKey or sourceKey == pendingMove.expectedSourceKey
    local targetKnown = targetKey == pendingMove.oldTargetKey or targetKey == pendingMove.expectedTargetKey
    if sourceKnown and targetKnown then
        local now = type(GetTime) == "function" and GetTime() or 0
        local started = self.pendingSortMoveStarted or now
        if now - started >= LOCK_RETRY_TIMEOUT then
            self.pendingSortMove = nil
            self.pendingSortMoveStarted = nil
            self.sortGroups = nil
            return false, nil
        end

        self:WaitForSortUpdate(SORT_MIN_POLL_TIMEOUT)
        return true, nil
    end

    self.pendingSortMove = nil
    self.pendingSortMoveStarted = nil
    return nil, T("bags.sort.errorChanged")
end

function Bags:ContinueManualSort()
    if not self.sorting then
        return
    end

    self.sortWaiting = false
    sortFrame:SetScript("OnUpdate", nil)

    if self.Api:HasCursorItem() then
        self:StopManualSort(T("bags.sort.errorCursor"))
        return
    end

    local pendingHandled, pendingError = self:WaitForPendingMove()
    if pendingError then
        self:StopManualSort(pendingError)
        return
    end
    if pendingHandled then
        return
    end

    local groups = self.sortGroups
    local errorMessage

    if groups then
        local valid
        valid, errorMessage = ValidateSortGroups(groups)
        if not valid then
            if type(errorMessage) == "table" and errorMessage.reason == "locked" then
                self:WaitForLockedSlot(errorMessage)
                return
            end
            self:StopManualSort(errorMessage)
            return
        end
    else
        groups, errorMessage = BuildSortGroups(self.sortStrategy)
        if not groups then
            if type(errorMessage) == "table" and errorMessage.reason == "locked" then
                self:WaitForLockedSlot(errorMessage)
                return
            end
            self:StopManualSort(errorMessage)
            return
        end
        self.sortGroups = groups
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
