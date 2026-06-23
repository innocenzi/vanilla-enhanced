local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:GetModule("bags")

local PLAYER_BAGS = { 0, 1, 2, 3, 4 }
local PLAYER_BAGS_BACKPACK_LAST = { 4, 3, 2, 1, 0 }
local FALLBACK_BANK_BAG_FIRST = 5
local FALLBACK_BANK_BAG_LAST = 11
local SORT_WAIT_TIMEOUT = 0.08
local SORT_MIN_POLL_TIMEOUT = 0.03
local LOCK_RETRY_TIMEOUT = 0.5
local AUTO_SORT_DELAY = 0.25

local sortFrame = CreateFrame("Frame")
local autoSortFrame = CreateFrame("Frame")

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function IsInCombatLockdown()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return true
    end
    return type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player") == true
end

local function GetItemID(link)
    if type(link) ~= "string" then
        return 0
    end
    return tonumber(string.match(link, "item:(%d+)")) or 0
end

local function GetBankContainerID()
    if type(BANK_CONTAINER) == "number" then
        return BANK_CONTAINER
    end
    return -1
end

local function IsMainBankContainer(bagID)
    return bagID == GetBankContainerID()
end

local function GetBankBags()
    local bags = {}
    local normalBagCount = type(NUM_BAG_SLOTS) == "number" and NUM_BAG_SLOTS or 4
    local bankBagCount = type(NUM_BANKBAGSLOTS) == "number" and NUM_BANKBAGSLOTS or nil

    if bankBagCount then
        for bagID = normalBagCount + 1, normalBagCount + bankBagCount do
            bags[#bags + 1] = bagID
        end
        return bags
    end

    for bagID = FALLBACK_BANK_BAG_FIRST, FALLBACK_BANK_BAG_LAST do
        bags[#bags + 1] = bagID
    end
    return bags
end

local function GetBankContainers()
    local containers = { GetBankContainerID() }
    for _, bagID in ipairs(GetBankBags()) do
        containers[#containers + 1] = bagID
    end
    return containers
end

local function GetBagFamily(bagID)
    if bagID == 0 or IsMainBankContainer(bagID) then
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

local function IsScrapSortItem(bagID, slot)
    if Bags.sortScrapsLast ~= true then
        return false
    end

    local Merchants = VanillaEnhanced:GetModule("merchants")
    if not Merchants
        or not Merchants.IsSellScrapsEnabled
        or not Merchants.IsScrapItem
        or not Merchants.Api
        or not Merchants.Api.ReadContainerItem
    then
        return false
    end

    local enabledOk, enabled = pcall(Merchants.IsSellScrapsEnabled, Merchants)
    if not enabledOk or enabled ~= true then
        return false
    end

    local readOk, itemContext = pcall(Merchants.Api.ReadContainerItem, Merchants.Api, bagID, slot)
    if not readOk or not itemContext then
        return false
    end

    local scrapOk, isScrap = pcall(Merchants.IsScrapItem, Merchants, itemContext)
    return scrapOk and isScrap == true
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
        isScrap = IsScrapSortItem(bagID, slot),
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

local function GetPlayerSortContainers()
    local settings = Bags:GetSettings()
    if settings.sortFillDirection == "backpack-last" then
        return PLAYER_BAGS_BACKPACK_LAST
    end
    return PLAYER_BAGS
end

local function CompareItems(left, right, sortOrder)
    if Bags.sortScrapsLast == true and left.isScrap ~= right.isScrap then
        return left.isScrap ~= true
    end

    for _, ruleName in ipairs(sortOrder) do
        local result = SORT_RULES[ruleName](left, right)
        if result ~= nil then
            return result
        end
    end

    return left.key < right.key
end

local function ApplyFullSort(group)
    local sortOrder = Bags.sortOrder or GetSortOrder()
    table.sort(group.items, function(left, right)
        return CompareItems(left, right, sortOrder)
    end)
end

local function BuildSortGroups(containerIDs)
    local groups = {}
    local groupOrder = {}

    for _, bagID in ipairs(containerIDs or PLAYER_BAGS) do
        local group = GetGroup(groups, groupOrder, GetSortGroupKey(bagID))
        local slotCount = Bags.Api:GetContainerNumSlots(bagID) or 0

        for slot = 1, slotCount do
            if not IsIgnoredSortSlot(bagID, slot)
                and not (Bags.IsItemLocked and Bags:IsItemLocked(bagID, slot))
            then
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
        ApplyFullSort(group)
    end

    return groupOrder
end

local function GetItemStackSize(link)
    local itemInfo = link and GetCachedItemInfo(link)
    local stackSize = itemInfo and tonumber(itemInfo.stackSize) or 1
    if stackSize < 1 then
        stackSize = 1
    end
    return stackSize
end

local function ReadStackableSlot(bagID, slot)
    if Bags.IsItemLocked and Bags:IsItemLocked(bagID, slot) then
        return nil, false
    end

    local containerItem = Bags.Api:GetContainerItemInfo(bagID, slot)
    if not containerItem then
        return nil, false
    end
    if containerItem.isLocked then
        return nil, true
    end

    local link = containerItem.hyperlink or Bags.Api:GetContainerItemLink(bagID, slot)
    if not link then
        return nil, false
    end

    local count = containerItem.stackCount or 1
    return {
        bagID = bagID,
        slot = slot,
        link = link,
        count = count,
        key = link .. ":" .. count,
        stackSize = GetItemStackSize(link),
    }, false
end

local function FindNextBankStackMove()
    local targetsByLink = {}
    local targetOrder = {}

    for _, bagID in ipairs(GetBankContainers()) do
        local slotCount = Bags.Api:GetContainerNumSlots(bagID) or 0
        for slot = 1, slotCount do
            if not IsIgnoredSortSlot(bagID, slot) then
                local target, locked = ReadStackableSlot(bagID, slot)
                if locked then
                    IgnoreSortSlot(bagID, slot)
                elseif target and target.stackSize > 1 and target.count < target.stackSize then
                    if not targetsByLink[target.link] then
                        targetsByLink[target.link] = {}
                        targetOrder[#targetOrder + 1] = target.link
                    end
                    targetsByLink[target.link][#targetsByLink[target.link] + 1] = target
                end
            end
        end
    end

    if #targetOrder == 0 then
        return nil, nil, nil
    end

    for _, sourceBagID in ipairs(PLAYER_BAGS) do
        local slotCount = Bags.Api:GetContainerNumSlots(sourceBagID) or 0
        for sourceSlot = 1, slotCount do
            if not IsIgnoredSortSlot(sourceBagID, sourceSlot) then
                local source, locked = ReadStackableSlot(sourceBagID, sourceSlot)
                if locked then
                    IgnoreSortSlot(sourceBagID, sourceSlot)
                elseif source and targetsByLink[source.link] then
                    for _, target in ipairs(targetsByLink[source.link]) do
                        local free = target.stackSize - target.count
                        if free > 0 then
                            return source, target, math.min(source.count, free)
                        end
                    end
                end
            end
        end
    end

    return nil, nil, nil
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

function Bags:SortItems(suppressErrors)
    if not self:IsSortEnabled() then
        return
    end

    if self.sorting then
        if not suppressErrors then
            self:PrintMessage(T("bags.sort.errorRunning"))
        end
        return
    end

    self:StartManualSort(suppressErrors, GetPlayerSortContainers(), "bags")
end

function Bags:SortBankItems(suppressErrors)
    if not self:IsSortEnabled() then
        return
    end

    if self.sorting then
        if not suppressErrors then
            self:PrintMessage(T("bags.sort.errorRunning"))
        end
        return
    end

    self:StartManualSort(suppressErrors, GetBankContainers(), "bank")
end

function Bags:StackItemsToBank(suppressErrors)
    if not self:IsSortEnabled() then
        return
    end

    if self.sorting then
        if not suppressErrors then
            self:PrintMessage(T("bags.sort.errorRunning"))
        end
        return
    end

    self:StartBankStack(suppressErrors)
end

function Bags:QueueAutoSort()
    if not self:IsSortEnabled() or self.sorting then
        return
    end

    self.autoSortElapsed = 0
    autoSortFrame:SetScript("OnUpdate", function(frame, elapsed)
        Bags.autoSortElapsed = (Bags.autoSortElapsed or 0) + elapsed
        if Bags.autoSortElapsed < AUTO_SORT_DELAY then
            return
        end

        frame:SetScript("OnUpdate", nil)
        if not Bags.sorting and Bags:IsSortEnabled() then
            Bags:SortItems(true)
        end
    end)
end

function Bags:ClearAutoSort()
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
    self.sortScrapsLast = nil
    self.sortContainerIDs = nil
    self.sortScope = nil
    self.sortOperation = nil
    self.sortGroups = nil
    self.ignoredSortSlots = nil
    self.pendingSortMove = nil
    self.pendingSortMoveStarted = nil
    sortFrame:SetScript("OnUpdate", nil)
    self:SetSortButtonBusy(false)
    if self.SetBankSortButtonBusy then
        self:SetBankSortButtonBusy(false)
    end
    if self.SetBankStackButtonBusy then
        self:SetBankStackButtonBusy(false)
    end
    self:QueueUpdate()

    if message and not suppressErrors then
        self:PrintMessage(message)
    end
end

function Bags:PrepareManualOperation(suppressErrors)
    self.suppressSortErrors = suppressErrors == true

    if not self:IsSortEnabled() then
        self:ClearAutoSort()
        self.suppressSortErrors = nil
        return false
    end

    if not self.Api or not self.Api:HasManualSortApis() then
        if not self.suppressSortErrors then
            self:PrintMessage(T("bags.sort.errorUnavailableClient"))
        end
        self.suppressSortErrors = nil
        return false
    end

    if IsInCombatLockdown() then
        if not self.suppressSortErrors then
            self:PrintMessage(T("bags.sort.errorCombat"))
        end
        self.suppressSortErrors = nil
        return false
    end

    if self.Api:HasCursorItem() then
        if not self.suppressSortErrors then
            self:PrintMessage(T("bags.sort.errorCursor"))
        end
        self.suppressSortErrors = nil
        return false
    end

    self.sorting = true
    self.lockWaitStarted = nil
    self.lockWaitBagID = nil
    self.lockWaitSlot = nil
    self.sortItemInfoCache = {}
    self.sortOrder = GetSortOrder()
    self.sortScrapsLast = self:GetSettings().sortScrapsLast ~= false
    self.sortGroups = nil
    self.ignoredSortSlots = {}
    self.pendingSortMove = nil
    self.pendingSortMoveStarted = nil
    if self.ClearScrapIconOverlays then
        self:ClearScrapIconOverlays()
    end
    self:SetSortButtonBusy(true)
    if self.SetBankSortButtonBusy then
        self:SetBankSortButtonBusy(true)
    end
    if self.SetBankStackButtonBusy then
        self:SetBankStackButtonBusy(true)
    end
    return true
end

function Bags:StartManualSort(suppressErrors, containerIDs, scope)
    if not self:PrepareManualOperation(suppressErrors) then
        return
    end

    self.sortOperation = "sort"
    self.sortScope = scope or "bags"
    self.sortContainerIDs = containerIDs or PLAYER_BAGS
    self:ContinueManualSort()
end

function Bags:StartBankStack(suppressErrors)
    if not self:PrepareManualOperation(suppressErrors) then
        return
    end

    self.sortOperation = "bankStack"
    self.sortScope = "bank"
    self.sortContainerIDs = nil
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
    if IsInCombatLockdown() then
        return false, T("bags.sort.errorCombat")
    end

    if self.Api:HasCursorItem() then
        return false, T("bags.sort.errorCursor")
    end
    if self.IsItemLocked
        and (self:IsItemLocked(sourceSlot.bagID, sourceSlot.slot) or self:IsItemLocked(targetSlot.bagID, targetSlot.slot))
    then
        return false, T("bags.lock.cannotMove")
    end

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

function Bags:MoveStackToBank(sourceSlot, targetSlot, moveCount)
    if IsInCombatLockdown() then
        return false, T("bags.sort.errorCombat")
    end

    if self.Api:HasCursorItem() then
        return false, T("bags.sort.errorCursor")
    end
    if self.IsItemLocked
        and (self:IsItemLocked(sourceSlot.bagID, sourceSlot.slot) or self:IsItemLocked(targetSlot.bagID, targetSlot.slot))
    then
        return false, T("bags.lock.cannotMove")
    end

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

    local expectedSourceCount = sourceSlot.count - moveCount
    local expectedTargetCount = targetSlot.count + moveCount

    self.pendingSortMove = {
        sourceBagID = sourceSlot.bagID,
        sourceSlotID = sourceSlot.slot,
        targetBagID = targetSlot.bagID,
        targetSlotID = targetSlot.slot,
        oldSourceKey = sourceSlot.key,
        oldTargetKey = targetSlot.key,
        expectedSourceKey = expectedSourceCount > 0 and (sourceSlot.link .. ":" .. expectedSourceCount) or nil,
        expectedTargetKey = targetSlot.link .. ":" .. expectedTargetCount,
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
    elseif now - self.lockWaitStarted >= LOCK_RETRY_TIMEOUT then
        IgnoreSortSlot(lockInfo.bagID, lockInfo.slot)
        self.lockWaitStarted = nil
        self.lockWaitBagID = nil
        self.lockWaitSlot = nil
        self.sortGroups = nil
        self.pendingSortMove = nil
        self.pendingSortMoveStarted = nil
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

    if IsInCombatLockdown() then
        self:StopManualSort(T("bags.sort.errorCombat"))
        return
    end

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

    if self.sortOperation == "bankStack" then
        local sourceSlot, targetSlot, moveCount = FindNextBankStackMove()
        if not sourceSlot or not targetSlot or not moveCount then
            self:StopManualSort()
            return
        end

        local ok, message = self:MoveStackToBank(sourceSlot, targetSlot, moveCount)
        if not ok then
            self:StopManualSort(message)
            return
        end

        self:WaitForSortUpdate()
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
        groups, errorMessage = BuildSortGroups(self.sortContainerIDs or PLAYER_BAGS)
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
