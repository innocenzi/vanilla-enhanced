local VanillaEnhanced = _G.VanillaEnhanced

local Api = {}
VanillaEnhanced.InventoryApi = Api

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

local CONTAINER_QUEST_INFO_KEYS = {
    "isQuestItem",
    "questID",
    "isActive",
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

local containerApiCache = {}
local itemApiCache = {}

local function FindApi(namespace, methodName)
    if namespace and type(namespace[methodName]) == "function" then
        return namespace[methodName]
    end
    if type(_G[methodName]) == "function" then
        return _G[methodName]
    end
    return nil
end

local function CacheApi(cache, namespace, methodName)
    local cached = cache[methodName]
    if cached then
        return cached
    end

    local api = FindApi(namespace, methodName)
    if api then
        cache[methodName] = api
    end
    return api
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

function Api:ClearCache()
    for key in pairs(containerApiCache) do
        containerApiCache[key] = nil
    end
    for key in pairs(itemApiCache) do
        itemApiCache[key] = nil
    end
end

function Api:FindContainer(methodName)
    return CacheApi(containerApiCache, C_Container, methodName)
end

function Api:FindItem(methodName)
    return CacheApi(itemApiCache, C_Item, methodName)
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

function Api:GetContainerNumSlots(bagID)
    local api = self:FindContainer("GetContainerNumSlots")
    return api and api(bagID) or nil
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

function Api:GetContainerNumFreeSlots(bagID)
    local api = self:FindContainer("GetContainerNumFreeSlots")
    return api and api(bagID) or nil
end

function Api:GetInventoryIDForContainer(bagID)
    local api = self:FindContainer("ContainerIDToInventoryID")
    if api then
        return api(bagID)
    end
    if type(ContainerIDToInventoryID) == "function" then
        return ContainerIDToInventoryID(bagID)
    end
    return nil
end

function Api:PickupContainerItem(bagID, slot)
    local api = self:FindContainer("PickupContainerItem")
    return api and api(bagID, slot) or nil
end

function Api:UseContainerItem(bagID, slot)
    local api = self:FindContainer("UseContainerItem")
    return api and api(bagID, slot) or nil
end

function Api:GetItemInfo(item)
    local api = self:FindItem("GetItemInfo")
    return api and PackReturns(ITEM_INFO_KEYS, api(item)) or nil
end

function Api:GetItemFamily(item)
    local api = self:FindItem("GetItemFamily")
    return api and api(item) or nil
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
