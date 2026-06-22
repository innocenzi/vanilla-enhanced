local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:CreateModule("merchants", VanillaEnhanced:T("module.merchants"))

local MERCHANT_OPEN_REFRESH_SECONDS = 2.0
local DEFAULT_SCRAP_STRATEGY = "poor-sellable"

local VALID_SCRAP_STRATEGIES = {
    ["poor-sellable"] = true,
    ["low-level"] = true,
    ["smart"] = true,
}

local defaults = {
    enabled = true,
    sellScrapsEnabled = true,
    autoSellScraps = false,
    autoRepair = false,
    safeManualSell = true,
    safeAutoSell = true,
    sortBagsAfterSellingScraps = false,
    scrapStrategy = "poor-sellable",
    customScrapItemIds = {},
    ignoredScrapItemIds = {},
}

local eventFrame = CreateFrame("Frame")
local refreshFrame = CreateFrame("Frame")

Merchants.eventFrame = eventFrame
Merchants.scrapStrategies = Merchants.scrapStrategies or {}
Merchants.scrapStrategyOrder = Merchants.scrapStrategyOrder or {}
Merchants.merchantOpen = false
Merchants.refreshRemaining = 0
Merchants.pendingAutoSellScraps = false
Merchants.pendingAutoRepair = false
Merchants.scrapMarkMode = false

function Merchants:GetSettings()
    local settings = VanillaEnhanced:GetModuleSettings("merchants", defaults)
    if not VALID_SCRAP_STRATEGIES[settings.scrapStrategy] then
        settings.scrapStrategy = DEFAULT_SCRAP_STRATEGY
    end
    return settings
end

function Merchants:IsSellScrapsEnabled()
    local settings = self:GetSettings()
    return settings.enabled ~= false and settings.sellScrapsEnabled ~= false
end

function Merchants:IsMerchantOpen()
    return self.merchantOpen == true
end

function Merchants:PrintMessage(message)
    VanillaEnhanced:PrintMessage(message)
end

function Merchants:RefreshBagScrapIcons()
    local Bags = VanillaEnhanced:GetModule("bags")
    if Bags and Bags.RefreshScrapIconOverlays then
        Bags:RefreshScrapIconOverlays()
    end
end

function Merchants:Update()
    self:RefreshBagScrapIcons()
    self:RequestRefresh(0.2)
end

function Merchants:RegisterScrapStrategy(strategy)
    if type(strategy) ~= "table" or type(strategy.key) ~= "string" or type(strategy.isScrap) ~= "function" then
        return
    end

    if not self.scrapStrategies[strategy.key] then
        table.insert(self.scrapStrategyOrder, strategy.key)
    end
    self.scrapStrategies[strategy.key] = strategy
end

function Merchants:GetScrapStrategy()
    local settings = self:GetSettings()
    return self.scrapStrategies[settings.scrapStrategy] or self.scrapStrategies["poor-sellable"]
end

function Merchants:IterateBagItems()
    local bagID = BACKPACK_CONTAINER or 0
    local lastBagID = type(NUM_BAG_SLOTS) == "number" and NUM_BAG_SLOTS or 4
    local slot = 0
    local slotCount = self.Api and self.Api:GetContainerNumSlots(bagID) or 0

    return function()
        while bagID <= lastBagID do
            if slot < (slotCount or 0) then
                slot = slot + 1
            else
                bagID = bagID + 1
                slot = 1
                slotCount = self.Api and self.Api:GetContainerNumSlots(bagID) or 0
            end

            if bagID <= lastBagID then
                local itemContext = self.Api and self.Api:ReadContainerItem(bagID, slot)
                if itemContext then
                    return itemContext
                end
            end
        end
    end
end

function Merchants:TryHookMerchantFrame()
    if self.merchantHooksInstalled or not MerchantFrame then
        return
    end

    if MerchantFrame.HookScript then
        MerchantFrame:HookScript("OnShow", function()
            Merchants:RequestRefresh(0.2)
        end)
        MerchantFrame:HookScript("OnHide", function()
            if not Merchants:IsMerchantOpen() then
                if Merchants.buttonContainer then
                    Merchants.buttonContainer:Hide()
                end
                if Merchants.sellButton then
                    Merchants.sellButton:Hide()
                end
                if Merchants.markButton then
                    Merchants.markButton:Hide()
                end
            end
        end)
    end

    if type(hooksecurefunc) == "function" then
        if type(MerchantFrame_UpdateMerchantInfo) == "function" then
            pcall(hooksecurefunc, "MerchantFrame_UpdateMerchantInfo", function()
                Merchants:RequestRefresh(0.2)
            end)
        end
        if type(MerchantFrame_UpdateRepairButtons) == "function" then
            pcall(hooksecurefunc, "MerchantFrame_UpdateRepairButtons", function()
                Merchants:RequestRefresh(0.2)
            end)
        end
    end

    self.merchantHooksInstalled = true
end

function Merchants:RequestRefresh(duration)
    self.refreshRemaining = math.max(self.refreshRemaining or 0, duration or 0)
    refreshFrame:SetScript("OnUpdate", function(frame, elapsed)
        if Merchants.InstallScrapMarkHooks then
            Merchants:InstallScrapMarkHooks()
        end
        Merchants:TryHookMerchantFrame()
        if Merchants.UpdateButton then
            Merchants:UpdateButton()
        end

        if Merchants.pendingAutoSellScraps and Merchants:IsMerchantOpen() and MerchantFrame then
            Merchants.pendingAutoSellScraps = false
            Merchants:SellScrapsBatch(Merchants:GetSellLimit(Merchants:GetSettings().safeAutoSell ~= false))
        end
        if Merchants.pendingAutoRepair and Merchants:IsMerchantOpen() and MerchantFrame then
            Merchants.pendingAutoRepair = not Merchants:AutoRepair()
        end

        Merchants.refreshRemaining = (Merchants.refreshRemaining or 0) - (elapsed or 0)
        if Merchants.refreshRemaining <= 0 then
            Merchants.refreshRemaining = 0
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

function Merchants:OpenMerchant()
    self.merchantOpen = true
    self.pendingAutoSellScraps = self:IsSellScrapsEnabled() and self:GetSettings().autoSellScraps == true
    self.pendingAutoRepair = self:GetSettings().autoRepair == true
    self:EnsureButton()
    self:InstallScrapMarkHooks()
    local Bags = VanillaEnhanced:GetModule("bags")
    if Bags and Bags.RefreshItemLockOverlays then
        Bags:RefreshItemLockOverlays()
    end
    self:RequestRefresh(MERCHANT_OPEN_REFRESH_SECONDS)
end

function Merchants:CloseMerchant()
    self.merchantOpen = false
    self:SetScrapMarkMode(false)
    self.scrapMarkButtonHovered = false
    self.pendingAutoSellScraps = false
    self.pendingAutoRepair = false
    self.pendingSortBagsAfterSellingScraps = false
    self.refreshRemaining = 0
    refreshFrame:SetScript("OnUpdate", nil)
    self:ClearScrapHighlights()
    if self.buttonContainer then
        self.buttonContainer:Hide()
    end
    if self.sellButton then
        self.sellButton:Hide()
    end
    if self.markButton then
        self.markButton:Hide()
    end
end

function Merchants:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("merchants", enabled)
    self:RefreshBagScrapIcons()
    if enabled then
        self:RequestRefresh(0.2)
    else
        self:SetScrapMarkMode(false)
        self.scrapMarkButtonHovered = false
        self:ClearScrapHighlights()
        if self.buttonContainer then
            self.buttonContainer:Hide()
        end
        if self.sellButton then
            self.sellButton:Hide()
        end
        if self.markButton then
            self.markButton:Hide()
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName ~= VanillaEnhanced.addonName then
        return
    end

    if event == "ADDON_LOADED" then
        Merchants:GetSettings()
        Merchants:EnsureButton()
        Merchants:InstallScrapMarkHooks()
        Merchants:TryHookMerchantFrame()
        return
    end

    if event == "PLAYER_LOGIN" then
        Merchants:EnsureButton()
        Merchants:InstallScrapMarkHooks()
        Merchants:TryHookMerchantFrame()
        return
    end

    if event == "MERCHANT_SHOW" then
        Merchants:OpenMerchant()
        return
    end

    if event == "MERCHANT_CLOSED" then
        Merchants:CloseMerchant()
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        Merchants:SortBagsAfterSellingScraps()
        if Merchants:ShouldShowScrapHighlights() then
            Merchants:RefreshScrapHighlights()
        else
            Merchants:ClearScrapHighlights()
        end
        Merchants:RequestRefresh(0.2)
        return
    end

    if event == "MERCHANT_UPDATE" then
        if Merchants:IsMerchantOpen() and Merchants:GetSettings().autoRepair == true then
            Merchants.pendingAutoRepair = true
        end
        Merchants:RequestRefresh(0.2)
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
pcall(eventFrame.RegisterEvent, eventFrame, "MERCHANT_UPDATE")
