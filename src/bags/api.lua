local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:GetModule("bags")

local InventoryApi = VanillaEnhanced.InventoryApi

local Api = {}
Bags.Api = Api

function Api:HasManualSortApis()
    return InventoryApi:FindContainer("GetContainerNumSlots") ~= nil
        and InventoryApi:FindContainer("GetContainerItemInfo") ~= nil
        and InventoryApi:FindContainer("PickupContainerItem") ~= nil
        and InventoryApi:FindItem("GetItemInfo") ~= nil
end

function Api:HasCursorItem()
    return InventoryApi:HasCursorItem()
end

function Api:GetContainerNumSlots(bagID)
    return InventoryApi:GetContainerNumSlots(bagID)
end

function Api:GetContainerItemInfo(bagID, slot)
    return InventoryApi:GetContainerItemInfo(bagID, slot)
end

function Api:GetContainerItemLink(bagID, slot)
    return InventoryApi:GetContainerItemLink(bagID, slot)
end

function Api:GetContainerNumFreeSlots(bagID)
    return InventoryApi:GetContainerNumFreeSlots(bagID)
end

function Api:GetInventoryIDForContainer(bagID)
    return InventoryApi:GetInventoryIDForContainer(bagID)
end

function Api:PickupContainerItem(bagID, slot)
    return InventoryApi:PickupContainerItem(bagID, slot)
end

function Api:GetItemInfo(item)
    return InventoryApi:GetItemInfo(item)
end

function Api:GetItemFamily(item)
    return InventoryApi:GetItemFamily(item)
end

function Api:IsEquippableItem(item)
    return InventoryApi:IsEquippableItem(item)
end
