local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")
local InventoryApi = VanillaEnhanced.InventoryApi

local TOOLTIP_NAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ShoppingTooltip3",
}

local pendingItemIDs = {}

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function GetItemIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(string.match(link, "item:(%d+)"))
end

local function FormatMoney(value)
    value = tonumber(value) or 0
    if type(GetCoinTextureString) == "function" then
        return GetCoinTextureString(value)
    end
    return tostring(value)
end

local function IsSellPriceText(text)
    if type(text) ~= "string" then
        return false
    end
    if type(ITEM_SELL_PRICE) == "string" and string.find(text, ITEM_SELL_PRICE, 1, true) == 1 then
        return true
    end
    if type(SELL_PRICE) == "string" and string.find(text, SELL_PRICE, 1, true) == 1 then
        return true
    end
    return false
end

local function TooltipAlreadyHasSellPrice(tooltip)
    if not tooltip or type(tooltip.GetName) ~= "function" or type(tooltip.NumLines) ~= "function" then
        return false
    end

    local name = tooltip:GetName()
    if not name then
        return false
    end

    for lineIndex = 1, tooltip:NumLines() do
        local leftLine = _G[name .. "TextLeft" .. lineIndex]
        if leftLine and leftLine.GetText and IsSellPriceText(leftLine:GetText()) then
            return true
        end
    end

    return false
end

local function GetTooltipBagSlot(tooltip)
    if not tooltip or type(tooltip.GetOwner) ~= "function" then
        return nil, nil
    end

    local owner = tooltip:GetOwner()
    if not owner or type(owner.GetID) ~= "function" or type(owner.GetParent) ~= "function" then
        return nil, nil
    end

    local parent = owner:GetParent()
    if not parent or type(parent.GetID) ~= "function" then
        return nil, nil
    end

    return parent:GetID(), owner:GetID()
end

local function IsMerchantFrameShown()
    return MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()
end

local function GetTooltipStackCount(tooltip, itemLink)
    local bagID, slot = GetTooltipBagSlot(tooltip)
    if bagID == nil or slot == nil or not InventoryApi then
        return 1, false
    end

    local containerItem = InventoryApi:GetContainerItemInfo(bagID, slot)
    if not containerItem then
        return 1, true
    end

    local link = containerItem.hyperlink or InventoryApi:GetContainerItemLink(bagID, slot)
    if link and itemLink and link ~= itemLink then
        return 1, true
    end

    return math.max(1, tonumber(containerItem.stackCount) or 1), true
end

local function RequestItemData(itemID)
    itemID = tonumber(itemID)
    if not itemID or pendingItemIDs[itemID] then
        return
    end

    local requested = false
    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        local ok = pcall(C_Item.RequestLoadItemDataByID, itemID)
        requested = ok == true
    end

    if requested then
        pendingItemIDs[itemID] = true
    end
end

local function ResetTooltipState(tooltip)
    if tooltip and not tooltip.VanillaEnhancedMerchantTooltipRefreshing then
        tooltip.VanillaEnhancedMerchantTooltipLink = nil
        tooltip.VanillaEnhancedMerchantTooltipPriceLink = nil
    end
end

function Merchants:IsVendorSellPriceTooltipEnabled()
    local settings = self:GetSettings()
    return settings.enabled ~= false and settings.showVendorSellPrice ~= false
end

function Merchants:AddVendorSellPriceTooltipLine(tooltip, itemLink)
    if not self:IsVendorSellPriceTooltipEnabled() or not tooltip or not itemLink or not InventoryApi then
        return false
    end
    if tooltip.VanillaEnhancedMerchantTooltipPriceLink == itemLink then
        return false
    end
    local stackCount, isBagTooltip = GetTooltipStackCount(tooltip, itemLink)
    if isBagTooltip and IsMerchantFrameShown() then
        tooltip.VanillaEnhancedMerchantTooltipPriceLink = itemLink
        return false
    end
    if TooltipAlreadyHasSellPrice(tooltip) then
        tooltip.VanillaEnhancedMerchantTooltipPriceLink = itemLink
        return false
    end

    local itemInfo = InventoryApi:GetItemInfo(itemLink)
    if not itemInfo then
        RequestItemData(GetItemIDFromLink(itemLink))
        return false
    end

    local sellPrice = tonumber(itemInfo.sellPrice) or 0
    if sellPrice <= 0 then
        return false
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(T("merchants.tooltip.vendorSellPrice", {
        price = FormatMoney(sellPrice * stackCount),
    }), 1, 1, 1, true)
    tooltip.VanillaEnhancedMerchantTooltipPriceLink = itemLink
    return true
end

local function OnTooltipSetItem(tooltip)
    if not tooltip or not Merchants or type(tooltip.GetItem) ~= "function" then
        return
    end

    local _, itemLink = tooltip:GetItem()
    if not itemLink then
        return
    end

    tooltip.VanillaEnhancedMerchantTooltipLink = itemLink
    if Merchants:AddVendorSellPriceTooltipLine(tooltip, itemLink) then
        tooltip:Show()
    end
end

local function HookTooltip(tooltip)
    if not tooltip or not tooltip.HookScript or tooltip.VanillaEnhancedMerchantTooltipHooked then
        return
    end

    tooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    tooltip:HookScript("OnHide", ResetTooltipState)
    tooltip:HookScript("OnTooltipCleared", ResetTooltipState)
    tooltip.VanillaEnhancedMerchantTooltipHooked = true
end

local function RefreshTooltip(tooltip)
    if not tooltip or tooltip.VanillaEnhancedMerchantTooltipRefreshing or not tooltip.VanillaEnhancedMerchantTooltipLink then
        return
    end
    if type(tooltip.IsShown) == "function" and not tooltip:IsShown() then
        return
    end
    if type(tooltip.SetHyperlink) ~= "function" or type(tooltip.ClearLines) ~= "function" then
        return
    end

    local itemLink = tooltip.VanillaEnhancedMerchantTooltipLink
    tooltip.VanillaEnhancedMerchantTooltipRefreshing = true
    tooltip.VanillaEnhancedMerchantTooltipPriceLink = nil
    tooltip:ClearLines()
    pcall(tooltip.SetHyperlink, tooltip, itemLink)
    tooltip.VanillaEnhancedMerchantTooltipRefreshing = nil
end

function Merchants:RefreshVendorSellPriceTooltips()
    for _, tooltipName in ipairs(TOOLTIP_NAMES) do
        RefreshTooltip(_G[tooltipName])
    end
end

for _, tooltipName in ipairs(TOOLTIP_NAMES) do
    HookTooltip(_G[tooltipName])
end

local eventFrame = CreateFrame("Frame")
Merchants.tooltipEventFrame = eventFrame

eventFrame:SetScript("OnEvent", function(_, event, itemID, success)
    if event ~= "GET_ITEM_INFO_RECEIVED" then
        return
    end

    itemID = tonumber(itemID)
    if itemID then
        pendingItemIDs[itemID] = nil
    end
    if success then
        Merchants:RefreshVendorSellPriceTooltips()
    end
end)

eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
