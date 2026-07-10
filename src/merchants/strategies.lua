local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local QUALITY_POOR = 0
local QUALITY_COMMON = 1
local QUALITY_UNCOMMON = 2
local ITEM_CLASS_CONSUMABLE = 0
local ITEM_CLASS_WEAPON = 2
local ITEM_CLASS_ARMOR = 4
local ITEM_CLASS_RECIPE = 9
local ITEM_CLASS_KEY = 13
local ITEM_CLASS_MISCELLANEOUS = 15
local ITEM_CLASS_TRADE_GOODS = 7
local MISC_SUBCLASS_COMPANION_PET = _G.LE_ITEM_MISCELLANEOUS_COMPANION_PET or 2
local MISC_SUBCLASS_MOUNT = _G.LE_ITEM_MISCELLANEOUS_MOUNT or 5

local EQUIPMENT_SLOTS = {
    INVTYPE_HEAD = { "HEAD" }, INVTYPE_NECK = { "NECK" }, INVTYPE_SHOULDER = { "SHOULDER" },
    INVTYPE_CHEST = { "CHEST" }, INVTYPE_ROBE = { "CHEST" }, INVTYPE_WAIST = { "WAIST" },
    INVTYPE_LEGS = { "LEGS" }, INVTYPE_FEET = { "FEET" }, INVTYPE_WRIST = { "WRIST" },
    INVTYPE_HAND = { "HAND" }, INVTYPE_CLOAK = { "BACK" }, INVTYPE_WEAPON = { "MAINHAND", "OFFHAND" },
    INVTYPE_SHIELD = { "OFFHAND" }, INVTYPE_2HWEAPON = { "MAINHAND" }, INVTYPE_WEAPONMAINHAND = { "MAINHAND" },
    INVTYPE_WEAPONOFFHAND = { "OFFHAND" }, INVTYPE_HOLDABLE = { "OFFHAND" }, INVTYPE_RANGED = { "RANGED" },
    INVTYPE_RANGEDRIGHT = { "RANGED" }, INVTYPE_THROWN = { "RANGED" }, INVTYPE_RELIC = { "RANGED" },
    INVTYPE_FINGER = { "FINGER1", "FINGER2" }, INVTYPE_TRINKET = { "TRINKET1", "TRINKET2" },
}

function Merchants:IsSellableScrapCandidate(itemContext)
    return itemContext and itemContext.isLocked ~= true and itemContext.isUserLocked ~= true
        and itemContext.isQuestItem ~= true and (itemContext.sellPrice or 0) > 0
end

local function IsEquipment(itemContext)
    local itemType = itemContext and itemContext.itemType
    return itemContext and itemContext.isEquippable == true and (
        itemContext.classID == ITEM_CLASS_WEAPON or itemContext.classID == ITEM_CLASS_ARMOR
        or (_G.ITEM_CLASS_WEAPON and itemType == _G.ITEM_CLASS_WEAPON)
        or (_G.ITEM_CLASS_ARMOR and itemType == _G.ITEM_CLASS_ARMOR)
    )
end

local function IsTradeGood(itemContext)
    local itemType = itemContext and itemContext.itemType
    return itemContext and (
        itemContext.classID == ITEM_CLASS_TRADE_GOODS
        or (_G.ITEM_CLASS_TRADE_GOODS and itemType == _G.ITEM_CLASS_TRADE_GOODS)
        or (_G.ITEM_CLASS_TRADEGOODS and itemType == _G.ITEM_CLASS_TRADEGOODS)
    )
end

local function IsProtectedCollectible(itemContext)
    if itemContext.classID == ITEM_CLASS_RECIPE or itemContext.classID == ITEM_CLASS_KEY then
        return true
    end
    return itemContext.classID == ITEM_CLASS_MISCELLANEOUS and (
        itemContext.subclassID == MISC_SUBCLASS_COMPANION_PET or itemContext.subclassID == MISC_SUBCLASS_MOUNT
    )
end

local function IsProtectedFromHeuristics(itemContext)
    if itemContext.isInEquipmentSet == true or IsProtectedCollectible(itemContext) then return true end
    if IsEquipment(itemContext) and (itemContext.isUnique == true or itemContext.hasUseEffect == true) then return true end
    return IsTradeGood(itemContext) and (itemContext.quality or -1) >= QUALITY_UNCOMMON
end

local function IsBoundEquipmentCandidate(itemContext)
    return Merchants:IsSellableScrapCandidate(itemContext) and IsEquipment(itemContext)
        and itemContext.isBound == true and (itemContext.quality or -1) <= QUALITY_UNCOMMON
        and (itemContext.minLevel or 0) <= (UnitLevel and UnitLevel("player") or 0)
end

local function GetEquippedItemLevel(slotName)
    local slotID = _G["INVSLOT_" .. slotName]
    if not slotID or type(GetInventoryItemLink) ~= "function" then return nil end
    local link = GetInventoryItemLink("player", slotID)
    local itemInfo = link and Merchants.Api and Merchants.Api:GetItemInfo(link)
    return itemInfo and itemInfo.itemLevel
end

local function IsBelowAllComparedSlots(itemContext, slots, gap)
    local compared = false
    for _, slotName in ipairs(slots or {}) do
        local equippedLevel = GetEquippedItemLevel(slotName)
        if equippedLevel and equippedLevel > 0 then
            compared = true
            if (itemContext.itemLevel or 0) > equippedLevel - gap then return false end
        end
    end
    return compared
end

local function MatchPoorQuality(itemContext, settings)
    return settings.scrapPoorQuality == true and itemContext.quality == QUALITY_POOR
end

local function MatchUnusableEquipment(itemContext, settings)
    return settings.scrapUnusableEquipment == true and IsBoundEquipmentCandidate(itemContext)
        and itemContext.quality ~= QUALITY_POOR and itemContext.canPlayerUse == false
end

local function MatchOutdatedEquipment(itemContext, settings)
    if settings.scrapOutdatedEquipment ~= true or not IsBoundEquipmentCandidate(itemContext)
        or itemContext.quality == QUALITY_POOR then return false end
    local gap = math.max(5, math.min(50, tonumber(settings.outdatedEquipmentLevelGap) or 20))
    return IsBelowAllComparedSlots(itemContext, EQUIPMENT_SLOTS[itemContext.equipLoc or ""], gap)
end

local function MatchOutdatedConsumable(itemContext, settings)
    local itemType = itemContext and itemContext.itemType
    local isConsumable = itemContext and (
        itemContext.classID == ITEM_CLASS_CONSUMABLE
        or (_G.ITEM_CLASS_CONSUMABLE and itemType == _G.ITEM_CLASS_CONSUMABLE)
    )
    local requiredLevel = itemContext and tonumber(itemContext.minLevel) or 0
    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local gap = math.max(5, math.min(40, tonumber(settings.outdatedConsumableLevelGap) or 20))
    return settings.scrapOutdatedConsumables == true and isConsumable and requiredLevel > 0 and playerLevel > 0
        and requiredLevel <= playerLevel - gap and (itemContext.quality or 0) <= QUALITY_UNCOMMON
end

local function MatchUnusedTradeGood(itemContext, settings)
    if settings.scrapUnusedTradeGoods ~= true or not IsTradeGood(itemContext) or not itemContext.itemID
        or (itemContext.quality or 0) > QUALITY_COMMON then return false end
    local Professions = VanillaEnhanced:GetModule("professions")
    if not Professions or not Professions.IsItemUsedByPlayerProfessionRecipes then return false end
    return Professions:IsItemUsedByPlayerProfessionRecipes(itemContext.itemID) == false
end

local RULES = {
    { key = "poor-quality", reasonKey = "merchants.scrapReason.poorQuality", automaticSetting = "autoSellPoorQuality", matches = MatchPoorQuality },
    { key = "unusable-equipment", reasonKey = "merchants.scrapReason.unusableEquipment", automaticSetting = "autoSellUnusableEquipment", matches = MatchUnusableEquipment },
    { key = "outdated-equipment", reasonKey = "merchants.scrapReason.outdatedEquipment", automaticSetting = "autoSellOutdatedEquipment", matches = MatchOutdatedEquipment },
    { key = "outdated-consumable", reasonKey = "merchants.scrapReason.outdatedConsumable", automaticSetting = "autoSellOutdatedConsumables", matches = MatchOutdatedConsumable },
    { key = "unused-trade-good", reasonKey = "merchants.scrapReason.unusedTradeGood", matches = MatchUnusedTradeGood },
}

function Merchants:EvaluateStrategyItem(itemContext)
    if not self:IsSellableScrapCandidate(itemContext) or IsProtectedFromHeuristics(itemContext) then return nil end
    local settings = self:GetSettings()
    for _, rule in ipairs(RULES) do
        if rule.matches(itemContext, settings) then
            return { isScrap = true, ruleKey = rule.key, reasonKey = rule.reasonKey,
                automatic = rule.automaticSetting ~= nil and settings[rule.automaticSetting] == true }
        end
    end
    return nil
end
