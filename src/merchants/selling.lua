local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local AUTO_SELL_LIMIT = 12
local BUTTON_SIZE = 24
local BUTTON_SPACING = 1
local BUTTON_PADDING = 5
local WINDOW_BUTTON_OFFSET_X = 0
local WINDOW_BUTTON_OFFSET_Y = -2
local SELL_SCRAPS_ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local CONTAINER_WIDTH = (BUTTON_SIZE * 2) + BUTTON_SPACING + (BUTTON_PADDING * 2)
local CONTAINER_HEIGHT = BUTTON_SIZE + (BUTTON_PADDING * 2)
local CONTAINER_BACKGROUND = "Interface\\DialogFrame\\UI-DialogBox-Background"
local CONTAINER_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

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

local function ConfigureButtonContainer(container)
    container:SetSize(CONTAINER_WIDTH, CONTAINER_HEIGHT)
    if container.SetBackdrop then
        container:SetBackdrop({
            bgFile = CONTAINER_BACKGROUND,
            edgeFile = CONTAINER_BORDER,
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {
                left = 5,
                right = 5,
                top = 5,
                bottom = 5,
            },
        })
        container:SetBackdropColor(0.20, 0.20, 0.20, 0.95)
        container:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    else
        local background = container:CreateTexture(nil, "BACKGROUND")
        background:SetTexture(CONTAINER_BACKGROUND)
        background:SetTexCoord(0.12, 0.88, 0.12, 0.88)
        background:SetAllPoints(container)
        container.background = background

        local top = container:CreateTexture(nil, "BORDER")
        top:SetTexture("Interface\\Buttons\\WHITE8X8")
        top:SetVertexColor(0.58, 0.58, 0.58, 1)
        top:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
        top:SetPoint("TOPRIGHT", container, "TOPRIGHT", -1, -1)
        top:SetHeight(2)

        local bottom = container:CreateTexture(nil, "BORDER")
        bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
        bottom:SetVertexColor(0.18, 0.16, 0.14, 1)
        bottom:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 1, 1)
        bottom:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
        bottom:SetHeight(2)

        local left = container:CreateTexture(nil, "BORDER")
        left:SetTexture("Interface\\Buttons\\WHITE8X8")
        left:SetVertexColor(0.58, 0.58, 0.58, 1)
        left:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
        left:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 1, 1)
        left:SetWidth(2)

        local right = container:CreateTexture(nil, "BORDER")
        right:SetTexture("Interface\\Buttons\\WHITE8X8")
        right:SetVertexColor(0.18, 0.16, 0.14, 1)
        right:SetPoint("TOPRIGHT", container, "TOPRIGHT", -1, -1)
        right:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
        right:SetWidth(2)
    end
end

local function CreateButtonContainer()
    local ok, container = pcall(CreateFrame, "Frame", "VanillaEnhancedMerchantsButtonContainer", UIParent, "BackdropTemplate")
    if ok and container then
        return container
    end
    return CreateFrame("Frame", "VanillaEnhancedMerchantsButtonContainer", UIParent)
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

    local container = CreateButtonContainer()
    ConfigureButtonContainer(container)
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
    sellButton:SetParent(container)
    markButton:SetParent(container)
    sellButton:SetFrameLevel((container:GetFrameLevel() or 0) + 1)
    markButton:SetFrameLevel((container:GetFrameLevel() or 0) + 1)

    if MerchantFrame then
        container:SetPoint("TOPRIGHT", MerchantFrame, "BOTTOMRIGHT", WINDOW_BUTTON_OFFSET_X, WINDOW_BUTTON_OFFSET_Y)
    else
        container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    markButton:SetPoint("LEFT", container, "LEFT", BUTTON_PADDING, 0)
    sellButton:SetPoint("LEFT", markButton, "RIGHT", BUTTON_SPACING, 0)
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
