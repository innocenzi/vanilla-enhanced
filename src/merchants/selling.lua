local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local AUTO_SELL_LIMIT = 12
local BUTTON_SIZE = 24
local BUTTON_SPACING = 1
local BUTTON_PADDING = 5
local WINDOW_BUTTON_OFFSET_X = 0
local WINDOW_BUTTON_OFFSET_Y = -2
local SELL_SCRAPS_ICON = "Interface\\Icons\\INV_Misc_Coin_02"

local BUTTON_CONTAINER_OPTIONS = {
    buttonCount = 2,
    buttonWidth = BUTTON_SIZE,
    buttonHeight = BUTTON_SIZE,
    buttonSpacing = BUTTON_SPACING,
    padding = BUTTON_PADDING,
}

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

function Merchants:UpdateSellButtonState(report)
    local sellButton = self.sellButton
    if not sellButton then
        return
    end

    local canSell = self.scrapMarkMode ~= true and report and report.stacks > 0
    if canSell then
        if sellButton.Enable then
            sellButton:Enable()
        end
        if sellButton.icon then
            sellButton.icon:SetAlpha(1)
        end
        return
    end

    if sellButton.Disable then
        sellButton:Disable()
    end
    if sellButton.icon then
        sellButton.icon:SetAlpha(0.35)
    end
end

function Merchants:EnsureButtonContainer()
    if self.buttonContainer then
        return self.buttonContainer
    end

    local container = VanillaEnhanced:CreateButtonContainer("VanillaEnhancedMerchantsButtonContainer", BUTTON_CONTAINER_OPTIONS)
    container:SetFrameStrata("HIGH")
    container:Hide()

    self.buttonContainer = container
    return container
end

function Merchants:EnsureButton()
    self:EnsureButtonContainer()
    if self.sellButton and self.markButton then
        return self.button
    end

    local container = self.buttonContainer
    local sellButton = self.sellButton
    if not sellButton then
        sellButton = CreateFrame("Button", "VanillaEnhancedMerchantsSellScrapsButton", container, "UIPanelButtonTemplate")
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
    local container = self.buttonContainer
    local sellButton = self.sellButton
    local markButton = self.markButton
    container:ClearAllPoints()
    sellButton:ClearAllPoints()
    markButton:ClearAllPoints()

    if MerchantFrame then
        container:SetParent(MerchantFrame)
        container:SetFrameStrata(MerchantFrame:GetFrameStrata() or "HIGH")
        container:SetFrameLevel((MerchantFrame:GetFrameLevel() or 0) + 50)
    else
        container:SetParent(UIParent)
        container:SetFrameStrata("HIGH")
        container:SetFrameLevel(100)
    end
    if MerchantFrame then
        container:SetPoint("TOPRIGHT", MerchantFrame, "BOTTOMRIGHT", WINDOW_BUTTON_OFFSET_X, WINDOW_BUTTON_OFFSET_Y)
    else
        container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    VanillaEnhanced:LayoutButtonContainer(container, {
        markButton,
        sellButton,
    }, BUTTON_CONTAINER_OPTIONS)
end

function Merchants:UpdateButton()
    self:EnsureButton()
    local container = self.buttonContainer
    local sellButton = self.sellButton
    local markButton = self.markButton

    if not self:IsMerchantOpen() or not self:IsSellScrapsEnabled() or not MerchantFrame then
        self:SetScrapMarkMode(false)
        self:ClearScrapHighlights()
        container:Hide()
        sellButton:Hide()
        markButton:Hide()
        return
    end

    self:AnchorButton()
    container:Show()
    sellButton:Show()
    markButton:Show()
    self:UpdateScrapMarkButtonState()

    local report = self:GetScrapReportSafely()
    self:UpdateSellButtonState(report)
    if report.stacks > 0 and self:ShouldShowScrapHighlights() then
        self:RefreshScrapHighlights()
    elseif report.stacks <= 0 then
        self:ClearScrapHighlights()
    end
end

function Merchants:SellScrapsBatch(limit)
    if not self:IsSellScrapsEnabled() or not self:IsMerchantOpen() then
        return
    end
    if self.scrapMarkMode == true then
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
