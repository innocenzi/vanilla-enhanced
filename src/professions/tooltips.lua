local VanillaEnhanced = _G.VanillaEnhanced
local Professions = VanillaEnhanced:GetModule("professions")

local TOOLTIP_NAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ShoppingTooltip3",
}

local function IsShiftKey(key)
    return key == "LSHIFT" or key == "RSHIFT"
end

local function OnTooltipSetItem(tooltip)
    if not tooltip or not Professions or not Professions.Api then
        return
    end
    if type(tooltip.GetItem) ~= "function" then
        return
    end

    local _, itemLink = tooltip:GetItem()
    local itemID = Professions.Api:GetItemIDFromLink(itemLink)
    if not itemID then
        return
    end
    if tooltip.VanillaEnhancedProfessionItemID == itemID then
        return
    end

    tooltip.VanillaEnhancedProfessionItemID = itemID
    tooltip.VanillaEnhancedProfessionItemLink = itemLink
    if Professions:AddTooltipLines(tooltip, itemID) then
        tooltip:Show()
    end
end

local function OnTooltipCleared(tooltip)
    if tooltip.VanillaEnhancedProfessionRefreshing then
        return
    end
    tooltip.VanillaEnhancedProfessionItemID = nil
    tooltip.VanillaEnhancedProfessionItemLink = nil
end

local function HookTooltip(tooltip)
    if not tooltip or not tooltip.HookScript or tooltip.VanillaEnhancedProfessionHooked then
        return
    end

    tooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    tooltip:HookScript("OnHide", OnTooltipCleared)
    tooltip:HookScript("OnTooltipCleared", OnTooltipCleared)
    tooltip.VanillaEnhancedProfessionHooked = true
end

for _, tooltipName in ipairs(TOOLTIP_NAMES) do
    HookTooltip(_G[tooltipName])
end

local function RefreshTooltip(tooltip)
    if not tooltip or tooltip.VanillaEnhancedProfessionRefreshing or not tooltip.VanillaEnhancedProfessionItemLink then
        return
    end
    local settings = Professions and Professions.GetSettings and Professions:GetSettings() or nil
    if not settings or settings.displayMode ~= "recipes" then
        return
    end
    if type(tooltip.IsShown) == "function" and not tooltip:IsShown() then
        return
    end
    if type(tooltip.SetHyperlink) ~= "function" or type(tooltip.ClearLines) ~= "function" then
        return
    end

    tooltip.VanillaEnhancedProfessionRefreshing = true
    tooltip.VanillaEnhancedProfessionItemID = nil
    tooltip:ClearLines()
    pcall(tooltip.SetHyperlink, tooltip, tooltip.VanillaEnhancedProfessionItemLink)
    tooltip.VanillaEnhancedProfessionRefreshing = nil
end

local modifierFrame = CreateFrame("Frame")
modifierFrame:SetScript("OnEvent", function(_, _, key)
    if not IsShiftKey(key) then
        return
    end

    for _, tooltipName in ipairs(TOOLTIP_NAMES) do
        RefreshTooltip(_G[tooltipName])
    end
end)
modifierFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
