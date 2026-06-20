local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:GetModule("bags")

local Api = {}
Bags.Api = Api

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

local function CacheApi(cache, namespace, methodName)
    local cached = cache[methodName]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local api = FindApi(namespace, methodName)
    cache[methodName] = api or false
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

local containerApiCache = {}
local itemApiCache = {}

function Api:FindContainer(methodName)
    return CacheApi(containerApiCache, C_Container, methodName)
end

function Api:FindItem(methodName)
    return CacheApi(itemApiCache, C_Item, methodName)
end

function Api:HasManualSortApis()
    return self:FindContainer("GetContainerNumSlots") ~= nil
        and self:FindContainer("GetContainerItemInfo") ~= nil
        and self:FindContainer("PickupContainerItem") ~= nil
        and self:FindItem("GetItemInfo") ~= nil
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

function Api:GetContainerNumFreeSlots(bagID)
    local api = self:FindContainer("GetContainerNumFreeSlots")
    if api then
        return api(bagID)
    end
    return nil
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
    if api then
        return api(bagID, slot)
    end
    return nil
end

function Api:GetItemInfo(item)
    local api = self:FindItem("GetItemInfo")
    return api and PackReturns(ITEM_INFO_KEYS, api(item)) or nil
end

function Api:GetItemFamily(item)
    local api = self:FindItem("GetItemFamily")
    return api and api(item) or nil
end
