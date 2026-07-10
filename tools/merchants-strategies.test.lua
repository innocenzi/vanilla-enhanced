local function fail(message)
    error(message, 2)
end

local function expect(value, message)
    if not value then fail(message) end
end

local function expectEqual(actual, expected, message)
    if actual ~= expected then
        fail((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function copyDefaults(target, defaults)
    target = type(target) == "table" and target or {}
    for key, value in pairs(defaults or {}) do
        if target[key] == nil then
            target[key] = type(value) == "table" and copyDefaults({}, value) or value
        end
    end
    return target
end

local frameMethods = {}
function frameMethods:SetScript() end
function frameMethods:RegisterEvent() end
function frameMethods:SetSize() end
function frameMethods:SetText() end
function frameMethods:Hide() end
function frameMethods:Show() end
function frameMethods:SetFrameStrata() end
function frameMethods:CreateTexture() return setmetatable({}, { __index = frameMethods }) end

function CreateFrame()
    return setmetatable({}, { __index = frameMethods })
end

UIParent = {}
BACKPACK_CONTAINER = 0
NUM_BAG_SLOTS = 4
INVSLOT_HEAD = 1
INVSLOT_MAINHAND = 2
INVSLOT_OFFHAND = 3
INVSLOT_TRINKET1 = 4
INVSLOT_TRINKET2 = 5
ITEM_CLASS_WEAPON = "Weapon"
ITEM_CLASS_ARMOR = "Armor"
ITEM_CLASS_CONSUMABLE = "Consumable"
ITEM_CLASS_TRADE_GOODS = "Trade Goods"

local playerLevel = 70
function UnitLevel() return playerLevel end

local equippedLevels = {}
function GetInventoryItemLink(_, slotID)
    return equippedLevels[slotID] and ("equipped:" .. slotID) or nil
end

VanillaEnhancedSettings = { modules = { merchants = { scrapStrategy = "smart", autoSellScraps = true } } }
VanillaEnhancedCharacterSettings = { modules = { merchants = {
    customScrapItemIds = { [9001] = true },
    ignoredScrapItemIds = { [9002] = true },
} } }

local professions = {
    IsItemUsedByPlayerProfessionRecipes = function(_, itemID)
        if itemID == 701 then return true end
        return false
    end,
}

VanillaEnhanced = {
    addonName = "VanillaEnhanced",
    modules = {},
    T = function(_, key) return key end,
}
_G.VanillaEnhanced = VanillaEnhanced

function VanillaEnhanced:CreateModule(key)
    self.modules[key] = self.modules[key] or {}
    return self.modules[key]
end
function VanillaEnhanced:GetModule(key)
    if key == "professions" then return professions end
    return self.modules[key] or self:CreateModule(key)
end
function VanillaEnhanced:GetSettings() return VanillaEnhancedSettings end
function VanillaEnhanced:GetModuleSettings(key, defaults)
    VanillaEnhancedSettings.modules[key] = copyDefaults(VanillaEnhancedSettings.modules[key], defaults)
    return VanillaEnhancedSettings.modules[key]
end
function VanillaEnhanced:GetCharacterModuleSettings(key, defaults)
    VanillaEnhancedCharacterSettings.modules[key] = copyDefaults(VanillaEnhancedCharacterSettings.modules[key], defaults)
    return VanillaEnhancedCharacterSettings.modules[key]
end
function VanillaEnhanced:IsModuleEnabled() return true end
function VanillaEnhanced:PrintMessage() end

assert(loadfile("src/merchants/module.lua"))()
local Merchants = VanillaEnhanced:GetModule("merchants")
Merchants.RequestRefresh = function() end
Merchants.RefreshBagScrapIcons = function() end
Merchants.Api = {
    GetItemInfo = function(_, link)
        local slotID = tonumber(string.match(link or "", "equipped:(%d+)"))
        return slotID and { itemLevel = equippedLevels[slotID] } or nil
    end,
}
assert(loadfile("src/merchants/strategies.lua"))()
assert(loadfile("src/merchants/scrap-marking.lua"))()

local settings = Merchants:GetSettings()
expectEqual(settings.scrapPreset, "poor-only", "legacy strategies reset conservatively")
expect(settings.scrapPoorQuality == true, "poor quality is enabled after migration")
expect(settings.scrapUnusedTradeGoods == false, "trade goods are disabled after migration")
expect(settings.autoSellPoorQuality == true, "poor quality automatic selling is enabled")
expect(settings.autoSellOutdatedEquipment == false, "heuristic automatic selling is disabled")
expectEqual(settings.scrapStrategy, nil, "legacy strategy is removed")
expect(Merchants:GetCustomScrapItemIds()[9001] == true, "character scrap overrides survive migration")
expect(Merchants:GetIgnoredScrapItemIds()[9002] == true, "character protection overrides survive migration")

Merchants:ApplyScrapPreset("aggressive")
expect(settings.scrapUnusableEquipment and settings.scrapOutdatedEquipment and settings.scrapOutdatedConsumables,
    "aggressive preset enables cleanup rules")
expect(settings.scrapUnusedTradeGoods == false, "aggressive preset excludes trade goods")
Merchants:ApplyScrapPreset("very-aggressive")
expect(settings.scrapUnusedTradeGoods == true, "very aggressive preset enables trade goods")
Merchants:OnOptionChanged("scrapOutdatedEquipment", false)
expectEqual(settings.scrapPreset, "custom", "individual edits select custom")

local function item(overrides)
    local result = {
        itemID = 100,
        quality = 1,
        sellPrice = 10,
        minLevel = 1,
        itemLevel = 1,
        classID = 15,
        subclassID = 0,
        isEquippable = false,
        isBound = false,
        canPlayerUse = true,
    }
    for key, value in pairs(overrides or {}) do result[key] = value end
    return result
end

Merchants:ApplyScrapPreset("poor-only")
local gray = item({ quality = 0 })
expectEqual(Merchants:EvaluateScrapItem(gray).ruleKey, "poor-quality", "gray items match")
expect(Merchants:EvaluateScrapItem(gray, "automatic") ~= nil, "gray items auto-sell by default")

Merchants:ApplyScrapPreset("aggressive")
local unusable = item({ classID = 4, isEquippable = true, isBound = true, canPlayerUse = false, quality = 2 })
expectEqual(Merchants:EvaluateScrapItem(unusable).ruleKey, "unusable-equipment", "unusable gear matches")
expectEqual(Merchants:EvaluateScrapItem(unusable, "automatic"), nil, "unusable gear is manual by default")
settings.autoSellUnusableEquipment = true
expect(Merchants:EvaluateScrapItem(unusable, "automatic") ~= nil, "unusable gear auto-sells when permitted")
unusable.canPlayerUse = nil
expectEqual(Merchants:EvaluateScrapItem(unusable), nil, "gear with unknown usability is protected")

equippedLevels[INVSLOT_HEAD] = 60
local outdated = item({ classID = 4, isEquippable = true, isBound = true, quality = 2, equipLoc = "INVTYPE_HEAD", itemLevel = 40 })
expectEqual(Merchants:EvaluateScrapItem(outdated).ruleKey, "outdated-equipment", "equipment threshold boundary matches")
outdated.itemLevel = 41
expectEqual(Merchants:EvaluateScrapItem(outdated), nil, "equipment above threshold does not match")

local consumable = item({ classID = 0, minLevel = 50, quality = 1 })
expectEqual(Merchants:EvaluateScrapItem(consumable).ruleKey, "outdated-consumable", "consumable threshold boundary matches")
consumable.minLevel = 51
expectEqual(Merchants:EvaluateScrapItem(consumable), nil, "consumable above threshold does not match")
consumable.minLevel = 0
expectEqual(Merchants:EvaluateScrapItem(consumable), nil, "consumable without a required level does not match")

Merchants:ApplyScrapPreset("very-aggressive")
local tradeGood = item({ itemID = 700, classID = 7, quality = 1 })
expectEqual(Merchants:EvaluateScrapItem(tradeGood).ruleKey, "unused-trade-good", "unused common trade good matches")
expectEqual(Merchants:EvaluateScrapItem(tradeGood, "automatic"), nil, "trade goods never auto-sell")
expectEqual(Merchants:EvaluateScrapItem(item({ itemID = 701, classID = 7, quality = 1 })), nil,
    "profession reagents are protected")
expectEqual(Merchants:EvaluateScrapItem(item({ itemID = 702, classID = 7, quality = 2 })), nil,
    "uncommon trade goods are protected")

local protectedItems = {
    item({ quality = 0, isInEquipmentSet = true }),
    item({ quality = 0, classID = 4, isEquippable = true, isUnique = true }),
    item({ quality = 0, classID = 4, isEquippable = true, hasUseEffect = true }),
    item({ quality = 0, classID = 9 }),
    item({ quality = 0, classID = 13 }),
    item({ quality = 0, classID = 15, subclassID = 2 }),
    item({ quality = 0, classID = 15, subclassID = 5 }),
}
for index, protected in ipairs(protectedItems) do
    expectEqual(Merchants:EvaluateStrategyItem(protected), nil, "protected heuristic item " .. index)
end

expectEqual(Merchants:EvaluateScrapItem(item({ quality = 0, isLocked = true })), nil, "locked items are protected")
expectEqual(Merchants:EvaluateScrapItem(item({ quality = 0, isQuestItem = true })), nil, "quest items are protected")
expectEqual(Merchants:EvaluateScrapItem(item({ quality = 0, sellPrice = 0 })), nil, "valueless items are protected")

Merchants:SetCustomScrapItem(800, true)
local manualProtectedCategory = item({ itemID = 800, quality = 2, classID = 9 })
expectEqual(Merchants:EvaluateScrapItem(manualProtectedCategory).ruleKey, "manual",
    "manual marks override heuristic category protections")
expect(Merchants:EvaluateScrapItem(manualProtectedCategory, "automatic") ~= nil,
    "manual marks are eligible for automatic selling")
manualProtectedCategory.isLocked = true
expectEqual(Merchants:EvaluateScrapItem(manualProtectedCategory), nil, "manual marks do not override hard safety")

assert(loadfile("src/merchants/selling.lua"))()

Merchants:ApplyScrapPreset("very-aggressive")
local reportItems = {
    item({ itemID = 810, quality = 0, stackCount = 2, sellPrice = 3 }),
    item({ itemID = 800, quality = 2, classID = 9, stackCount = 1, sellPrice = 10 }),
    item({ itemID = 703, classID = 7, quality = 1, stackCount = 4, sellPrice = 1 }),
}
function Merchants:IterateBagItems()
    local index = 0
    return function()
        index = index + 1
        return reportItems[index]
    end
end

local report = Merchants:GetScrapReport()
expectEqual(report.stacks, 3, "manual report counts every matched stack")
expectEqual(report.items, 7, "manual report counts stack sizes")
expectEqual(report.value, 20, "manual report totals sell value")
expectEqual(#report.reasons, 3, "manual report groups by match reason")
expectEqual(report.reasons[1].reasonKey, "merchants.scrapReason.poorQuality", "report keeps reason order")
expectEqual(report.reasons[1].items, 2, "poor reason counts stack size")
expectEqual(report.reasons[2].reasonKey, "merchants.scrapReason.manual", "manual marks get their own reason")
expectEqual(report.reasons[3].reasonKey, "merchants.scrapReason.unusedTradeGood", "trade goods get their own reason")

local automaticReport = Merchants:GetScrapReport("automatic")
expectEqual(automaticReport.stacks, 2, "automatic report excludes manual-only trade goods")
expectEqual(automaticReport.items, 3, "automatic report keeps poor and explicit manual scraps")
expectEqual(automaticReport.value, 16, "automatic report values only eligible matches")

ITEM_UNIQUE = "Unique"
ITEM_UNIQUE_MULTIPLE = "Unique (%d)"
ITEM_SPELL_TRIGGER_ONUSE = "Use:"

local scannerLines = {
    [1] = { "Unique", "Use: Reveals a safely protected effect." },
}

local function createScannerTooltip(name)
    local tooltip = { lines = {} }
    function tooltip:SetOwner() end
    function tooltip:ClearLines()
        self.lines = {}
    end
    function tooltip:SetBagItem(_, slot)
        self.lines = scannerLines[slot] or {}
        for lineIndex, text in ipairs(self.lines) do
            _G[name .. "TextLeft" .. lineIndex] = { GetText = function() return text end }
        end
    end
    function tooltip:NumLines()
        return #self.lines
    end
    return tooltip
end

function CreateFrame(frameType, name)
    if frameType == "GameTooltip" and name == "VanillaEnhancedMerchantItemScanner" then
        local tooltip = createScannerTooltip(name)
        _G[name] = tooltip
        return tooltip
    end
    return setmetatable({}, { __index = frameMethods })
end

local apiItems = {
    [1001] = {
        itemID = 1001,
        hyperlink = "item:1001",
        quality = 0,
        stackCount = 1,
        isLocked = false,
    },
}
local apiItemInfo = {
    [1001] = {
        quality = 0,
        sellPrice = 1,
        itemLevel = 1,
        minLevel = 1,
        classID = 4,
        subclassID = 4,
        equipLoc = "INVTYPE_HEAD",
    },
}

local canUseResult = true
C_PlayerInfo = {
    CanUseItem = function(itemID)
        expectEqual(itemID, 1001, "shared character eligibility receives the item ID")
        return canUseResult
    end,
}
assert(loadfile("src/inventory/api.lua"))()
expectEqual(VanillaEnhanced.InventoryApi:CanPlayerUseItem(1001), true,
    "shared character eligibility keeps usable items")
canUseResult = false
expectEqual(VanillaEnhanced.InventoryApi:CanPlayerUseItem(1001), false,
    "shared character eligibility keeps unusable items")
C_PlayerInfo = nil
expectEqual(VanillaEnhanced.InventoryApi:CanPlayerUseItem(1001), nil,
    "missing character eligibility API returns unknown")

local canPlayerUseItemID
VanillaEnhanced.InventoryApi = {
    FindContainer = function() end,
    FindItem = function() end,
    GetContainerNumSlots = function() return 1 end,
    GetContainerItemInfo = function(_, _, slot) return apiItems[1000 + slot] end,
    GetContainerItemLink = function(_, _, slot) return "item:" .. tostring(1000 + slot) end,
    GetContainerItemID = function(_, _, slot) return 1000 + slot end,
    GetContainerItemQuestInfo = function() return nil end,
    GetItemInfo = function(_, item)
        local itemID = tonumber(item)
        if not itemID and type(item) == "string" then
            itemID = tonumber(string.match(item, "item:(%d+)"))
        end
        return apiItemInfo[itemID]
    end,
    IsEquippableItem = function() return true end,
    IsUsableItem = function() return true end,
    CanPlayerUseItem = function(_, itemID)
        canPlayerUseItemID = itemID
        return true
    end,
    UseContainerItem = function() end,
    HasCursorItem = function() return false end,
    IsContainerItemBound = function() return true end,
}

C_EquipmentSet = {
    GetEquipmentSetIDs = function() return { 42 } end,
    GetItemIDs = function() return { 1001 } end,
}

assert(loadfile("src/merchants/api.lua"))()
expect(Merchants.Api:IsItemInEquipmentSet(1001), "C_EquipmentSet item IDs are detected")
expectEqual(Merchants.Api:IsItemInEquipmentSet(1002), false, "C_EquipmentSet non-members are ignored")

local scanned = Merchants.Api:ReadContainerItem(0, 1)
expect(scanned.isUnique == true, "tooltip scanner detects unique items")
expect(scanned.hasUseEffect == true, "tooltip scanner detects use effects")
expect(scanned.isInEquipmentSet == true, "read container context includes equipment-set state")
expect(scanned.canPlayerUse == true, "read container context includes character item eligibility")
expectEqual(canPlayerUseItemID, 1001, "character item eligibility receives the numeric item ID")

Merchants.Api:ClearEquipmentSetCache()
C_EquipmentSet = nil
function GetNumEquipmentSets() return 1 end
function GetEquipmentSetInfo() return "Set A" end
function GetEquipmentSetItemIDs() return nil, 1002 end
expect(Merchants.Api:IsItemInEquipmentSet(1002), "legacy equipment set item IDs are detected")
expectEqual(Merchants.Api:IsItemInEquipmentSet(1001), false, "legacy cache rebuild replaces prior C API data")

Merchants.Api:ClearEquipmentSetCache()
GetNumEquipmentSets = nil
GetEquipmentSetInfo = nil
GetEquipmentSetItemIDs = nil
expectEqual(Merchants.Api:IsItemInEquipmentSet(1002), false, "missing equipment set APIs fail safely")

print("merchant strategy assertions passed")
