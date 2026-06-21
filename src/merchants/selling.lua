local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local AUTO_SELL_LIMIT = 12
local BUTTON_SIZE = 24
local BUTTON_SPACING = 4
local SELL_SCRAPS_ICON = "Interface\\Icons\\INV_Misc_Coin_02"

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function FormatMoney(value)
    if type(GetCoinTextureString) == "function" then
        return GetCoinTextureString(value or 0)
    end
    if type(GetMoneyString) == "function" then
        return GetMoneyString(value or 0, true)
    end
    return tostring(value or 0)
end

local function ConfigureSellButton(button)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetText("")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(SELL_SCRAPS_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.icon = icon

    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    end
end

local function ShowSellTooltip(button)
    if not GameTooltip then
        return
    end

    local report = Merchants:GetScrapReportSafely()
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("merchants.sellScraps.tooltipTitle"))
    if report.stacks > 0 then
        GameTooltip:AddLine(T("merchants.sellScraps.tooltipBody", {
            count = report.items,
            money = FormatMoney(report.value),
        }), 1, 1, 1, true)
    else
        GameTooltip:AddLine(T("merchants.sellScraps.tooltipEmpty"), 1, 1, 1, true)
    end
    GameTooltip:Show()
    Merchants:ShowScrapHighlights()
end

local function HideSellTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
    Merchants:ClearScrapHighlights()
end

function Merchants:GetSellLimit(safeEnabled)
    return safeEnabled and AUTO_SELL_LIMIT or nil
end

function Merchants:CanSortBagsAfterSellingScraps()
    if self:GetSettings().sortBagsAfterSellingScraps ~= true then
        return false
    end
    if not VanillaEnhanced:IsModuleEnabled("bags") then
        return false
    end

    local Bags = VanillaEnhanced:GetModule("bags")
    return Bags and Bags.IsSortEnabled and Bags:IsSortEnabled() and Bags.QueueAutoSort
end

function Merchants:GetScrapReport()
    local report = {
        stacks = 0,
        items = 0,
        value = 0,
    }

    if not self:IsSellScrapsEnabled() then
        return report
    end

    for itemContext in self:IterateBagItems() do
        if self:IsScrapItem(itemContext) then
            report.stacks = report.stacks + 1
            report.items = report.items + math.max(1, itemContext.stackCount or 1)
            report.value = report.value + ((itemContext.sellPrice or 0) * math.max(1, itemContext.stackCount or 1))
        end
    end

    return report
end

function Merchants:GetScrapReportSafely()
    local ok, report = pcall(function()
        return self:GetScrapReport()
    end)
    if ok and type(report) == "table" then
        return report
    end
    return {
        stacks = 0,
        items = 0,
        value = 0,
    }
end

function Merchants:EnsureButton()
    if self.sellButton and self.markButton then
        return self.button
    end

    local sellButton = self.sellButton
    if not sellButton then
        sellButton = CreateFrame("Button", "VanillaEnhancedMerchantsSellScrapsButton", UIParent, "UIPanelButtonTemplate")
        ConfigureSellButton(sellButton)
        sellButton:SetFrameStrata("HIGH")
        sellButton:Hide()

        sellButton:SetScript("OnClick", function()
            Merchants:SellScrapsBatch(Merchants:GetSellLimit(Merchants:GetSettings().safeManualSell == true))
        end)
        sellButton:SetScript("OnEnter", ShowSellTooltip)
        sellButton:SetScript("OnLeave", HideSellTooltip)

        self.sellButton = sellButton
        self.button = sellButton
    end

    self:EnsureMarkButton(BUTTON_SIZE)
    return self.button
end

function Merchants:AnchorButton()
    self:EnsureButton()
    local sellButton = self.sellButton
    local markButton = self.markButton
    sellButton:ClearAllPoints()
    markButton:ClearAllPoints()

    if MerchantFrame then
        sellButton:SetParent(MerchantFrame)
        markButton:SetParent(MerchantFrame)
        sellButton:SetFrameStrata(MerchantFrame:GetFrameStrata() or "HIGH")
        markButton:SetFrameStrata(MerchantFrame:GetFrameStrata() or "HIGH")
        sellButton:SetFrameLevel((MerchantFrame:GetFrameLevel() or 0) + 50)
        markButton:SetFrameLevel((MerchantFrame:GetFrameLevel() or 0) + 50)
    else
        sellButton:SetParent(UIParent)
        markButton:SetParent(UIParent)
        sellButton:SetFrameStrata("HIGH")
        markButton:SetFrameStrata("HIGH")
        sellButton:SetFrameLevel(100)
        markButton:SetFrameLevel(100)
    end

    if MerchantFrameCloseButton then
        sellButton:SetPoint("TOPRIGHT", MerchantFrameCloseButton, "BOTTOMRIGHT", -10, 4)
    elseif MerchantFrame then
        sellButton:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -16, -24)
    else
        sellButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    markButton:SetPoint("RIGHT", sellButton, "LEFT", -BUTTON_SPACING, 0)
end

function Merchants:UpdateButton()
    self:EnsureButton()
    local sellButton = self.sellButton
    local markButton = self.markButton

    if not self:IsMerchantOpen() or not self:IsSellScrapsEnabled() or not MerchantFrame then
        self:SetScrapMarkMode(false)
        self:ClearScrapHighlights()
        sellButton:Hide()
        markButton:Hide()
        return
    end

    self:AnchorButton()
    sellButton:Show()
    markButton:Show()
    self:UpdateScrapMarkButtonState()

    local report = self:GetScrapReportSafely()
    if report.stacks > 0 then
        if sellButton.Enable then
            sellButton:Enable()
        end
        if sellButton.icon then
            sellButton.icon:SetAlpha(1)
        end
        if self:ShouldShowScrapHighlights() then
            self:RefreshScrapHighlights()
        end
    elseif sellButton.Disable then
        sellButton:Disable()
        if sellButton.icon then
            sellButton.icon:SetAlpha(0.35)
        end
        self:ClearScrapHighlights()
    end
end

function Merchants:SellScrapsBatch(limit)
    if not self:IsSellScrapsEnabled() or not self:IsMerchantOpen() then
        return
    end
    if self.Api and self.Api:HasCursorItem() then
        self:PrintMessage(T("merchants.sellScraps.errorCursor"))
        return
    end

    local soldStacks = 0
    local soldValue = 0

    for itemContext in self:IterateBagItems() do
        if limit and soldStacks >= limit then
            break
        end
        if self:IsScrapItem(itemContext) then
            local ok = pcall(self.Api.UseContainerItem, self.Api, itemContext.bagID, itemContext.slot)
            if ok then
                soldStacks = soldStacks + 1
                soldValue = soldValue + ((itemContext.sellPrice or 0) * math.max(1, itemContext.stackCount or 1))
            end
        end
    end

    if soldStacks > 0 then
        self:PrintMessage(T("merchants.sellScraps.sold", {
            money = FormatMoney(soldValue),
        }))
        self.pendingSortBagsAfterSellingScraps = self:CanSortBagsAfterSellingScraps()
    end

    self:RequestRefresh(0.5)
end

function Merchants:SortBagsAfterSellingScraps()
    if not self.pendingSortBagsAfterSellingScraps then
        return
    end
    self.pendingSortBagsAfterSellingScraps = false

    if not self:CanSortBagsAfterSellingScraps() then
        return
    end

    local Bags = VanillaEnhanced:GetModule("bags")
    Bags:QueueAutoSort("merchant")
end
