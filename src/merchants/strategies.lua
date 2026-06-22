local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local QUALITY_POOR = 0
local QUALITY_UNCOMMON = 2
local ITEM_CLASS_CONSUMABLE = 0
local ITEM_CLASS_WEAPON = 2
local ITEM_CLASS_ARMOR = 4
local ITEM_CLASS_TRADE_GOODS = 7
local LOW_CONSUMABLE_LEVEL_RATIO = 0.25
local LOW_EQUIPMENT_LEVEL_RATIO = 0.50

local EQUIPMENT_SLOTS = {
    INVTYPE_HEAD = { "HEAD" },
    INVTYPE_NECK = { "NECK" },
    INVTYPE_SHOULDER = { "SHOULDER" },
    INVTYPE_CHEST = { "CHEST" },
    INVTYPE_ROBE = { "CHEST" },
    INVTYPE_WAIST = { "WAIST" },
    INVTYPE_LEGS = { "LEGS" },
    INVTYPE_FEET = { "FEET" },
    INVTYPE_WRIST = { "WRIST" },
    INVTYPE_HAND = { "HAND" },
    INVTYPE_CLOAK = { "BACK" },
    INVTYPE_WEAPON = { "MAINHAND", "OFFHAND" },
    INVTYPE_SHIELD = { "OFFHAND" },
    INVTYPE_2HWEAPON = { "MAINHAND" },
    INVTYPE_WEAPONMAINHAND = { "MAINHAND" },
    INVTYPE_WEAPONOFFHAND = { "OFFHAND" },
    INVTYPE_HOLDABLE = { "OFFHAND" },
    INVTYPE_RANGED = { "RANGED" },
    INVTYPE_RANGEDRIGHT = { "RANGED" },
    INVTYPE_THROWN = { "RANGED" },
    INVTYPE_RELIC = { "RANGED" },
    INVTYPE_FINGER = { "FINGER1", "FINGER2" },
    INVTYPE_TRINKET = { "TRINKET1", "TRINKET2" },
}

local function IsSellableItem(itemContext)
    return itemContext
        and itemContext.isLocked ~= true
        and itemContext.isUserLocked ~= true
        and itemContext.isQuestItem ~= true
        and (itemContext.sellPrice or 0) > 0
end

local function IsEquipment(itemContext)
    local itemType = itemContext and itemContext.itemType
    return itemContext
        and itemContext.isEquippable == true
        and (
            itemContext.classID == ITEM_CLASS_WEAPON
            or itemContext.classID == ITEM_CLASS_ARMOR
            or itemType == _G.ITEM_CLASS_WEAPON
            or itemType == _G.ITEM_CLASS_ARMOR
        )
end

local function IsBoundEquipmentCandidate(itemContext)
    return IsSellableItem(itemContext)
        and IsEquipment(itemContext)
        and itemContext.isBound == true
        and (itemContext.quality or -1) <= QUALITY_UNCOMMON
        and (itemContext.minLevel or 0) <= (UnitLevel and UnitLevel("player") or 0)
end

local function IsPoorSellable(itemContext)
    return IsSellableItem(itemContext)
        and itemContext.quality == QUALITY_POOR
end

local function IsUnusableBoundEquipment(itemContext)
    return IsBoundEquipmentCandidate(itemContext)
        and itemContext.quality ~= QUALITY_POOR
        and itemContext.isUsable == false
end

local function IsLowConsumable(itemContext)
    local itemType = itemContext and itemContext.itemType
    local isConsumable = itemContext
        and (itemContext.classID == ITEM_CLASS_CONSUMABLE or itemType == _G.ITEM_CLASS_CONSUMABLE)

    if not IsSellableItem(itemContext) or not isConsumable then
        return false
    end

    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local itemLevel = itemContext.itemLevel or 0
    return playerLevel > 0
        and itemLevel > 1
        and itemLevel < playerLevel * LOW_CONSUMABLE_LEVEL_RATIO
        and (itemContext.quality or 0) <= QUALITY_UNCOMMON
end

local function GetInventorySlotID(slotName)
    return _G["INVSLOT_" .. slotName]
end

local function GetEquippedItemLevel(slotName)
    local slotID = GetInventorySlotID(slotName)
    if not slotID or type(GetInventoryItemLink) ~= "function" then
        return nil
    end

    local link = GetInventoryItemLink("player", slotID)
    if not link or not Merchants.Api then
        return nil
    end

    local itemInfo = Merchants.Api:GetItemInfo(link)
    return itemInfo and itemInfo.itemLevel
end

local function IsBelowAllComparedSlots(itemContext, slots)
    local compared = false

    for _, slotName in ipairs(slots or {}) do
        local equippedLevel = GetEquippedItemLevel(slotName)
        if equippedLevel and equippedLevel > 0 then
            compared = true
            if (itemContext.itemLevel or 0) >= equippedLevel * LOW_EQUIPMENT_LEVEL_RATIO then
                return false
            end
        end
    end

    return compared
end

local function IsLowBoundEquipment(itemContext)
    if not IsBoundEquipmentCandidate(itemContext) or itemContext.quality == QUALITY_POOR then
        return false
    end

    local slots = EQUIPMENT_SLOTS[itemContext.equipLoc or ""]
    return IsBelowAllComparedSlots(itemContext, slots)
end

local function IsTradeGood(itemContext)
    local itemType = itemContext and itemContext.itemType
    return itemContext
        and (
            itemContext.classID == ITEM_CLASS_TRADE_GOODS
            or itemType == _G.ITEM_CLASS_TRADE_GOODS
            or itemType == _G.ITEM_CLASS_TRADEGOODS
        )
end

local function IsTradeGoodUnusedByPlayerProfessions(itemContext)
    if not IsSellableItem(itemContext) or not IsTradeGood(itemContext) or not itemContext.itemID then
        return false
    end

    local Professions = VanillaEnhanced:GetModule("professions")
    if not Professions or not Professions.IsItemUsedByPlayerProfessionRecipes then
        return false
    end

    return Professions:IsItemUsedByPlayerProfessionRecipes(itemContext.itemID) == false
end

local function AnyRule(itemContext, rules)
    for _, rule in ipairs(rules) do
        if rule(itemContext) then
            return true
        end
    end
    return false
end

local LOW_LEVEL_RULES = {
    IsPoorSellable,
    IsUnusableBoundEquipment,
    IsLowConsumable,
    IsLowBoundEquipment,
}

local SMART_RULES = {
    IsPoorSellable,
    IsUnusableBoundEquipment,
    IsLowConsumable,
    IsLowBoundEquipment,
    IsTradeGoodUnusedByPlayerProfessions,
}

Merchants:RegisterScrapStrategy({
    key = "poor-sellable",
    labelKey = "options.merchants.scrapStrategy.poorSellable",
    isScrap = IsPoorSellable,
})

Merchants:RegisterScrapStrategy({
    key = "low-level",
    labelKey = "options.merchants.scrapStrategy.lowLevel",
    isScrap = function(itemContext)
        return AnyRule(itemContext, LOW_LEVEL_RULES)
    end,
})

Merchants:RegisterScrapStrategy({
    key = "smart",
    labelKey = "options.merchants.scrapStrategy.smart",
    isScrap = function(itemContext)
        return AnyRule(itemContext, SMART_RULES)
    end,
})
