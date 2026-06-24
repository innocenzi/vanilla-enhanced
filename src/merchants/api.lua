local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local InventoryApi = VanillaEnhanced.InventoryApi

local Api = {}
Merchants.Api = Api

local function IsUserLockedItem(bagID, slot)
    local Bags = VanillaEnhanced:GetModule("bags")
    return Bags and Bags.IsItemLocked and Bags:IsItemLocked(bagID, slot) == true
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

function Api:FindContainer(methodName)
    return InventoryApi:FindContainer(methodName)
end

function Api:FindItem(methodName)
    return InventoryApi:FindItem(methodName)
end

function Api:GetContainerNumSlots(bagID)
    return InventoryApi:GetContainerNumSlots(bagID) or 0
end

function Api:GetContainerItemInfo(bagID, slot)
    return InventoryApi:GetContainerItemInfo(bagID, slot)
end

function Api:GetContainerItemLink(bagID, slot)
    return InventoryApi:GetContainerItemLink(bagID, slot)
end

function Api:GetContainerItemID(bagID, slot)
    return InventoryApi:GetContainerItemID(bagID, slot)
end

function Api:GetContainerItemQuestInfo(bagID, slot)
    return InventoryApi:GetContainerItemQuestInfo(bagID, slot)
end

function Api:GetItemInfo(item)
    return InventoryApi:GetItemInfo(item)
end

function Api:IsEquippableItem(item)
    return InventoryApi:IsEquippableItem(item)
end

function Api:IsUsableItem(item)
    return InventoryApi:IsUsableItem(item)
end

function Api:UseContainerItem(bagID, slot)
    return InventoryApi:UseContainerItem(bagID, slot)
end

function Api:HasCursorItem()
    return InventoryApi:HasCursorItem()
end

function Api:IsContainerItemBound(bagID, slot)
    return InventoryApi:IsContainerItemBound(bagID, slot)
end

function Api:ReadContainerItem(bagID, slot)
    local containerItem = self:GetContainerItemInfo(bagID, slot)
    if not containerItem then
        return nil
    end

    local itemID = containerItem.itemID or self:GetContainerItemID(bagID, slot)
    local link = containerItem.hyperlink or self:GetContainerItemLink(bagID, slot)
    if not itemID and not link then
        return nil
    end

    local itemInfo = self:GetItemInfo(itemID or link) or self:GetItemInfo(link)
    local questInfo = self:GetContainerItemQuestInfo(bagID, slot)
    local isQuestRelated = IsQuestRelatedItem(questInfo)
    local stackCount = containerItem.stackCount or 1
    local item = itemID or link
    local isBound = self:IsContainerItemBound(bagID, slot)

    return {
        bagID = bagID,
        slot = slot,
        itemID = itemID,
        link = link,
        quality = containerItem.quality or (itemInfo and itemInfo.quality),
        stackCount = stackCount,
        sellPrice = (itemInfo and itemInfo.sellPrice) or 0,
        itemLevel = (itemInfo and itemInfo.itemLevel) or 0,
        minLevel = (itemInfo and itemInfo.minLevel) or 0,
        itemType = itemInfo and itemInfo.itemType,
        itemSubType = itemInfo and itemInfo.itemSubType,
        equipLoc = (itemInfo and itemInfo.equipLoc) or "",
        classID = itemInfo and itemInfo.classID,
        subclassID = itemInfo and itemInfo.subclassID,
        bindType = itemInfo and itemInfo.bindType,
        isEquippable = self:IsEquippableItem(item),
        isUsable = self:IsUsableItem(item),
        isBound = isBound,
        isLocked = containerItem.isLocked == true,
        isUserLocked = IsUserLockedItem(bagID, slot),
        isQuestItem = isQuestRelated,
        isQuestStarter = isQuestRelated and questInfo and questInfo.isQuestItem ~= true,
    }
end
