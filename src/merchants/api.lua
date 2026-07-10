local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local InventoryApi = VanillaEnhanced.InventoryApi

local Api = {}
Merchants.Api = Api

local equipmentSetItemIDs

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

local function GetFormatPrefix(value)
    if type(value) ~= "string" then
        return nil
    end
    local marker = string.find(value, "%%", 1, true)
    return marker and string.sub(value, 1, marker - 1) or value
end

local function StartsWith(text, prefix)
    return type(text) == "string" and type(prefix) == "string" and prefix ~= ""
        and string.find(text, prefix, 1, true) == 1
end

local function ScanContainerTooltip(bagID, slot)
    local result = { isUnique = false, hasUseEffect = false }
    if not CreateFrame or not UIParent then
        return result
    end

    local tooltip = VanillaEnhancedMerchantItemScanner
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "VanillaEnhancedMerchantItemScanner", UIParent, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    if type(tooltip.SetBagItem) ~= "function" then
        return result
    end

    tooltip:ClearLines()
    if not pcall(tooltip.SetBagItem, tooltip, bagID, slot) then
        return result
    end

    local uniquePrefix = GetFormatPrefix(_G.ITEM_UNIQUE)
    local uniqueMultiplePrefix = GetFormatPrefix(_G.ITEM_UNIQUE_MULTIPLE)
    local usePrefix = GetFormatPrefix(_G.ITEM_SPELL_TRIGGER_ONUSE)
    for lineIndex = 1, tooltip:NumLines() do
        local line = _G["VanillaEnhancedMerchantItemScannerTextLeft" .. lineIndex]
        local text = line and line:GetText()
        if StartsWith(text, uniquePrefix) or StartsWith(text, uniqueMultiplePrefix) then
            result.isUnique = true
        end
        if StartsWith(text, usePrefix) then
            result.hasUseEffect = true
        end
    end
    return result
end

local function AddEquipmentSetItems(target, items)
    if type(items) ~= "table" then
        return
    end
    for _, itemID in pairs(items) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
            target[itemID] = true
        end
    end
end

local function AddEquipmentSetItemResults(target, ok, ...)
    if not ok then
        return
    end

    local first = ...
    if type(first) == "table" then
        AddEquipmentSetItems(target, first)
    else
        AddEquipmentSetItems(target, { ... })
    end
end

local function BuildEquipmentSetItemIDs()
    local result = {}
    if C_EquipmentSet and type(C_EquipmentSet.GetEquipmentSetIDs) == "function"
        and type(C_EquipmentSet.GetItemIDs) == "function" then
        local ok, setIDs = pcall(C_EquipmentSet.GetEquipmentSetIDs)
        if ok and type(setIDs) == "table" then
            for _, setID in ipairs(setIDs) do
                AddEquipmentSetItemResults(result, pcall(C_EquipmentSet.GetItemIDs, setID))
            end
        end
    elseif type(GetNumEquipmentSets) == "function" and type(GetEquipmentSetInfo) == "function"
        and type(GetEquipmentSetItemIDs) == "function" then
        local count = tonumber(GetNumEquipmentSets()) or 0
        for index = 1, count do
            local name = GetEquipmentSetInfo(index)
            if name then
                AddEquipmentSetItemResults(result, pcall(GetEquipmentSetItemIDs, name))
            end
        end
    end
    return result
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

function Api:CanPlayerUseItem(itemID)
    return InventoryApi:CanPlayerUseItem(itemID)
end

function Api:UseContainerItem(bagID, slot)
    return InventoryApi:UseContainerItem(bagID, slot)
end

function Api:HasCursorItem()
    return InventoryApi:HasCursorItem()
end

function Api:ClearEquipmentSetCache()
    equipmentSetItemIDs = nil
end

function Api:IsItemInEquipmentSet(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end
    if not equipmentSetItemIDs then
        equipmentSetItemIDs = BuildEquipmentSetItemIDs()
    end
    return equipmentSetItemIDs[itemID] == true
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
    local tooltipFlags = ScanContainerTooltip(bagID, slot)

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
        canPlayerUse = self:CanPlayerUseItem(itemID),
        isBound = isBound,
        isLocked = containerItem.isLocked == true,
        isUserLocked = IsUserLockedItem(bagID, slot),
        isQuestItem = isQuestRelated,
        isQuestStarter = isQuestRelated and questInfo and questInfo.isQuestItem ~= true,
        isInEquipmentSet = self:IsItemInEquipmentSet(itemID),
        isUnique = tooltipFlags.isUnique,
        hasUseEffect = tooltipFlags.hasUseEffect,
    }
end
