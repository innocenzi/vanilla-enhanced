local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local Api = {}
Merchants.Api = Api

local CONTAINER_INFO_KEYS = {
    "iconFileID",
    "stackCount",
    "isLocked",
    "quality",
    "isReadable",
    "hasLoot",
    "hyperlink",
    "isFiltered",
    "hasNoValue",
    "itemID",
    "isBound",
}

local ITEM_INFO_KEYS = {
    "name",
    "link",
    "quality",
    "itemLevel",
    "minLevel",
    "itemType",
    "itemSubType",
    "stackSize",
    "equipLoc",
    "texture",
    "sellPrice",
    "classID",
    "subclassID",
    "bindType",
}

local CONTAINER_QUEST_INFO_KEYS = {
    "isQuestItem",
    "questID",
    "isActive",
}

local function FindApi(namespace, methodName)
    if namespace and type(namespace[methodName]) == "function" then
        return namespace[methodName]
    end
    if type(_G[methodName]) == "function" then
        return _G[methodName]
    end
    return nil
end

local function PackReturns(keys, ...)
    local first = ...
    if first == nil then
        return nil
    end
    if type(first) == "table" then
        return first
    end

    local info = {}
    for index, key in ipairs(keys) do
        info[key] = select(index, ...)
    end
    return info
end

local function TooltipSaysBound(bagID, slot)
    if not ITEM_SOULBOUND or not CreateFrame then
        return false
    end

    local tooltip = VanillaEnhancedMerchantsTooltipScanner
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "VanillaEnhancedMerchantsTooltipScanner", UIParent, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    tooltip:ClearLines()
    local ok = pcall(tooltip.SetBagItem, tooltip, bagID, slot)
    if not ok then
        return false
    end

    for lineIndex = 1, tooltip:NumLines() do
        local line = _G["VanillaEnhancedMerchantsTooltipScannerTextLeft" .. lineIndex]
        if line and line:GetText() == ITEM_SOULBOUND then
            return true
        end
    end

    return false
end

function Api:FindContainer(methodName)
    return FindApi(C_Container, methodName)
end

function Api:FindItem(methodName)
    return FindApi(C_Item, methodName)
end

function Api:GetContainerNumSlots(bagID)
    local api = self:FindContainer("GetContainerNumSlots")
    return api and api(bagID) or 0
end

function Api:GetContainerItemInfo(bagID, slot)
    local api = self:FindContainer("GetContainerItemInfo")
    return api and PackReturns(CONTAINER_INFO_KEYS, api(bagID, slot)) or nil
end

function Api:GetContainerItemLink(bagID, slot)
    local api = self:FindContainer("GetContainerItemLink")
    if api then
        return api(bagID, slot)
    end

    local item = self:GetContainerItemInfo(bagID, slot)
    return item and item.hyperlink
end

function Api:GetContainerItemID(bagID, slot)
    local api = self:FindContainer("GetContainerItemID")
    if api then
        return api(bagID, slot)
    end

    local item = self:GetContainerItemInfo(bagID, slot)
    return item and item.itemID
end

function Api:GetContainerItemQuestInfo(bagID, slot)
    local api = self:FindContainer("GetContainerItemQuestInfo")
    return api and PackReturns(CONTAINER_QUEST_INFO_KEYS, api(bagID, slot)) or nil
end

function Api:GetItemInfo(item)
    local api = self:FindItem("GetItemInfo")
    return api and PackReturns(ITEM_INFO_KEYS, api(item)) or nil
end

function Api:IsEquippableItem(item)
    local api = self:FindItem("IsEquippableItem")
    if api then
        return api(item)
    end
    if type(IsEquippableItem) == "function" then
        return IsEquippableItem(item)
    end
    return false
end

function Api:IsUsableItem(item)
    if type(IsUsableItem) == "function" then
        local usable = IsUsableItem(item)
        return usable == true
    end
    return true
end

function Api:UseContainerItem(bagID, slot)
    local api = self:FindContainer("UseContainerItem")
    if api then
        return api(bagID, slot)
    end
    return nil
end

function Api:HasCursorItem()
    if type(CursorHasItem) == "function" then
        return CursorHasItem()
    end
    if C_Cursor and type(C_Cursor.GetCursorItem) == "function" then
        return C_Cursor.GetCursorItem() ~= nil
    end
    return false
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
    local stackCount = containerItem.stackCount or 1
    local item = itemID or link
    local isBound = containerItem.isBound == true or TooltipSaysBound(bagID, slot)

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
        isQuestItem = questInfo and questInfo.isQuestItem == true,
    }
end
