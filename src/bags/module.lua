local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:CreateModule("bags", VanillaEnhanced:T("module.bags"))

local defaults = {
    enabled = true,
    showSortButton = true,
    showSearchField = true,
    showScrapIcon = false,
    showQuestIcon = false,
    showScrapToggleButton = false,
    sortOrder = "category",
    sortFillDirection = "backpack-first",
    sortScrapsLast = true,
    enableItemLocking = true,
    autoSortAfterLoot = false,
    autoSortOnOpen = false,
    autoSortOnClose = false,
    autoOpenMode = "both",
    itemLocks = {},
}

local BAG_FUNCTIONS = {
    "OpenAllBags",
    "CloseAllBags",
    "ToggleBackpack",
    "OpenBackpack",
    "CloseBackpack",
    "ToggleBag",
}

local AUTO_OPEN_REASONS = {
    character = true,
    merchant = true,
}

local updateFrame = CreateFrame("Frame")

local SORT_BUTTON_WIDTH = 46
local SORT_BUTTON_HEIGHT = 20
local SORT_BUTTON_COMPACT_LEFT_OFFSET = -1
local SORT_BUTTON_COMPACT_RIGHT_OFFSET = 0
local BANK_STACK_BUTTON_WIDTH = 60
local SCRAP_TOGGLE_BUTTON_SIZE = 20
local SEARCH_BOX_WIDTH = 122
local SEARCH_BOX_COMPACT_WIDTH = 108
local SEARCH_BOX_HEIGHT = 20
local SORT_BUTTON_SPACING = 4
local SCRAP_TOGGLE_BUTTON_SPACING = 1
local SORT_BUTTON_PADDING = SORT_BUTTON_SPACING
local SCRAP_TOGGLE_BUTTON_PADDING = 3
local SORT_CONTAINER_OFFSET_X = 0
local SORT_CONTAINER_OFFSET_Y = -8
local BANK_CONTAINER_OFFSET_Y = -12
local SEARCH_DIM_ALPHA = 0.55
local SEARCH_ICON_ALPHA = 0.38
local MAX_SEARCH_BUTTONS = 36
local FALLBACK_BANK_BAG_FIRST = 5
local FALLBACK_BANK_BAG_LAST = 11
local SEARCH_BOX_TEXTURE_LEFT_OFFSET = 5
local SEARCH_BOX_TEXTURE_RIGHT_OFFSET = 0
local SEARCH_BOX_TEXTURE_RIGHT_OFFSET_WITH_BUTTON = 5
local SEARCH_BOX_TEXTURE_RIGHT_OFFSET_COMPACT = 0
local SEARCH_BOX_TEXTURE_TOP_OFFSET = 0
local SEARCH_BOX_TEXTURE_BOTTOM_OFFSET = 0

local SORT_BUTTON_CONTAINER_OPTIONS = {
    buttonCount = 1,
    buttonWidth = SORT_BUTTON_WIDTH,
    buttonHeight = SORT_BUTTON_HEIGHT,
    buttonSpacing = SORT_BUTTON_SPACING,
    padding = SORT_BUTTON_PADDING,
}

local BAG_CONTROL_CONTAINER_OPTIONS = {
    buttonSpacing = SORT_BUTTON_SPACING,
    padding = SORT_BUTTON_PADDING,
}

local BAG_CONTROL_COMPACT_CONTAINER_OPTIONS = {
    buttonSpacing = SCRAP_TOGGLE_BUTTON_SPACING,
    padding = SCRAP_TOGGLE_BUTTON_PADDING,
}

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local IsAnyBagVisible

function Bags:GetSettings()
    local settings = VanillaEnhanced:GetModuleSettings("bags", defaults)
    if settings.sortEnabled == false and settings.enabled ~= false then
        settings.enabled = false
    end
    settings.sortEnabled = nil
    settings.autoSortAfterLootMode = nil
    if settings.sortOrder == "name" then
        settings.sortOrder = defaults.sortOrder
    end
    if settings.sortFillDirection ~= "backpack-first" and settings.sortFillDirection ~= "backpack-last" then
        settings.sortFillDirection = defaults.sortFillDirection
    end
    return settings
end

function Bags:IsSortEnabled()
    local settings = self:GetSettings()
    return settings.enabled ~= false
end

function Bags:ShouldAutoOpenBags(reason)
    if not self:IsSortEnabled() or not AUTO_OPEN_REASONS[reason] then
        return false
    end

    local mode = self:GetSettings().autoOpenMode or "disabled"
    return mode == "both" or mode == reason
end

function Bags:ClearAutoOpenBagTracking()
    self.autoOpenedBagsOwned = false
    self.autoOpenBagReasons = nil
end

function Bags:TrackAutoOpenedBags(reason, bagsVisibleBefore)
    if not self.autoOpenedBagsOwned and bagsVisibleBefore then
        return
    end

    self.autoOpenedBagsOwned = true
    self.autoOpenBagReasons = self.autoOpenBagReasons or {}
    self.autoOpenBagReasons[reason] = true
end

function Bags:HasTrackedAutoOpenReason()
    for _, active in pairs(self.autoOpenBagReasons or {}) do
        if active then
            return true
        end
    end
    return false
end

function Bags:AutoOpenBags(reason)
    if not self:ShouldAutoOpenBags(reason) or type(OpenAllBags) ~= "function" then
        return
    end

    local bagsVisibleBefore = IsAnyBagVisible and IsAnyBagVisible()
    local ok = pcall(OpenAllBags)
    if ok and IsAnyBagVisible and IsAnyBagVisible() then
        self:TrackAutoOpenedBags(reason, bagsVisibleBefore)
    end
end

function Bags:AutoCloseBags(reason)
    if not self.autoOpenedBagsOwned then
        return
    end

    if self.autoOpenBagReasons then
        self.autoOpenBagReasons[reason] = nil
    end

    if self:HasTrackedAutoOpenReason() then
        return
    end

    self:ClearAutoOpenBagTracking()
    if type(CloseAllBags) == "function" and IsAnyBagVisible and IsAnyBagVisible() then
        pcall(CloseAllBags)
    end
end

function Bags:PrintMessage(message)
    VanillaEnhanced:PrintMessage(message)
end

local function IsShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function GetContainerFrameCount()
    if type(NUM_CONTAINER_FRAMES) == "number" then
        return NUM_CONTAINER_FRAMES
    end
    return 13
end

local function GetBankContainerID()
    if type(BANK_CONTAINER) == "number" then
        return BANK_CONTAINER
    end
    return -1
end

local function IsPlayerBagID(bagID)
    if type(bagID) ~= "number" then
        return false
    end
    return bagID >= 0 and bagID <= 4
end

local function IsBankBagID(bagID)
    if type(bagID) ~= "number" then
        return false
    end
    local normalBagCount = type(NUM_BAG_SLOTS) == "number" and NUM_BAG_SLOTS or 4
    local bankBagCount = type(NUM_BANKBAGSLOTS) == "number" and NUM_BANKBAGSLOTS or nil

    if bankBagCount then
        return bagID >= normalBagCount + 1 and bagID <= normalBagCount + bankBagCount
    end

    return bagID >= FALLBACK_BANK_BAG_FIRST and bagID <= FALLBACK_BANK_BAG_LAST
end

local function IsBankFrameVisible()
    return IsShown(BankFrame)
end

IsAnyBagVisible = function()
    for index = 1, GetContainerFrameCount() do
        local frame = _G["ContainerFrame" .. index]
        if IsShown(frame) then
            return true
        end
    end
    return false
end

local function GetVisibleBagFrame()
    for index = 1, GetContainerFrameCount() do
        local frame = _G["ContainerFrame" .. index]
        if IsShown(frame) and frame.GetID and frame:GetID() == 0 then
            return frame
        end
    end
end

local function GetContainerItemButton(frame, index)
    local frameName = frame and frame.GetName and frame:GetName()
    return frameName and _G[frameName .. "Item" .. index] or nil
end

local function GetItemButtonIcon(button)
    if not button then
        return nil
    end
    if button.icon then
        return button.icon
    end
    if button.Icon then
        return button.Icon
    end
    if button.GetName then
        return _G[button:GetName() .. "IconTexture"] or _G[button:GetName() .. "Icon"]
    end
    return nil
end

local function Trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function NormalizeSearchText(text)
    return string.lower(Trim(text))
end

local function TextContains(text, query)
    if type(text) ~= "string" or text == "" then
        return false
    end
    return string.find(string.lower(text), query, 1, true) ~= nil
end

local function EnsureSearchTooltipScanner()
    if not CreateFrame or not UIParent then
        return nil
    end

    local tooltip = VanillaEnhancedBagsSearchTooltipScanner
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "VanillaEnhancedBagsSearchTooltipScanner", UIParent, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return tooltip
end

local function TooltipContainsSearchText(bagID, slot, query)
    local tooltip = EnsureSearchTooltipScanner()
    if not tooltip or type(tooltip.SetBagItem) ~= "function" then
        return false
    end

    tooltip:ClearLines()
    local ok = pcall(tooltip.SetBagItem, tooltip, bagID, slot)
    if not ok then
        return false
    end

    local tooltipName = tooltip:GetName()
    for lineIndex = 1, tooltip:NumLines() do
        local leftLine = _G[tooltipName .. "TextLeft" .. lineIndex]
        local rightLine = _G[tooltipName .. "TextRight" .. lineIndex]
        if TextContains(leftLine and leftLine:GetText(), query) or TextContains(rightLine and rightLine:GetText(), query) then
            return true
        end
    end

    return false
end

local function ShowSortTooltip(frame)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("bags.sort.tooltipTitle"))
    GameTooltip:AddLine(T("bags.sort.tooltipBody"), 1, 1, 1, true)
    GameTooltip:Show()
end

local function ShowSearchTooltip(frame)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("bags.search.tooltipTitle"))
    GameTooltip:AddLine(T("bags.search.tooltipBody"), 1, 1, 1, true)
    GameTooltip:Show()
end

local function ShowBankSortTooltip(frame)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("bags.bank.sort.tooltipTitle"))
    GameTooltip:AddLine(T("bags.bank.sort.tooltipBody"), 1, 1, 1, true)
    GameTooltip:Show()
end

local function ShowBankStackTooltip(frame)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("bags.bank.stack.tooltipTitle"))
    GameTooltip:AddLine(T("bags.bank.stack.tooltipBody"), 1, 1, 1, true)
    GameTooltip:Show()
end

local function ShowBankSearchTooltip(frame)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("bags.bank.search.tooltipTitle"))
    GameTooltip:AddLine(T("bags.bank.search.tooltipBody"), 1, 1, 1, true)
    GameTooltip:Show()
end

local function ShowScrapToggleTooltip(frame)
    local Merchants = VanillaEnhanced:GetModule("merchants")
    if Merchants and Merchants.ShowScrapMarkButtonTooltip then
        Merchants:ShowScrapMarkButtonTooltip(frame)
    end
end

local function HideScrapToggleTooltip()
    local Merchants = VanillaEnhanced:GetModule("merchants")
    if Merchants and Merchants.HideScrapMarkButtonTooltip then
        Merchants:HideScrapMarkButtonTooltip()
    elseif GameTooltip then
        GameTooltip:Hide()
    end
end

local function HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function DisableScrapMarkModeForClosedBags(scrapToggleButton)
    local Merchants = VanillaEnhanced:GetModule("merchants")
    if Merchants and Merchants.scrapMarkMode == true and Merchants.SetScrapMarkMode then
        Merchants:SetScrapMarkMode(false)
    end
    if scrapToggleButton and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(scrapToggleButton) then
        HideScrapToggleTooltip()
    end
end

local function GetBagMoneyFrame(bagFrame)
    local frameName = bagFrame and bagFrame.GetName and bagFrame:GetName()
    local moneyFrame = frameName and _G[frameName .. "MoneyFrame"] or nil
    if moneyFrame then
        return moneyFrame
    end
    return bagFrame
end

local function GetBankMoneyFrame()
    if BankFrameMoneyFrame then
        return BankFrameMoneyFrame
    end
    return BankFrame
end

local function GetBankMainItemButton(index)
    return _G["BankFrameItem" .. index] or _G["BankFrameItemButton" .. index]
end

local function GetMaxContainerButtons()
    if type(MAX_CONTAINER_BUTTONS) == "number" then
        return MAX_CONTAINER_BUTTONS
    end
    return MAX_SEARCH_BUTTONS
end

local function UpdateSearchPlaceholder(searchBox)
    if not searchBox or not searchBox.placeholder then
        return
    end

    local text = searchBox.GetText and searchBox:GetText() or ""
    if text == "" and not (searchBox.HasFocus and searchBox:HasFocus()) then
        searchBox.placeholder:Show()
        return
    end

    searchBox.placeholder:Hide()
end

local function CreateControlComponent(name, parent, width, height)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(width, height)
    frame:Hide()
    return frame
end

local function FitTextureAwareChild(child, component, leftOffset, rightOffset, topOffset, bottomOffset)
    child:ClearAllPoints()
    child:SetPoint("TOPLEFT", component, "TOPLEFT", leftOffset or 0, -(topOffset or 0))
    child:SetPoint("BOTTOMRIGHT", component, "BOTTOMRIGHT", rightOffset or 0, bottomOffset or 0)
end

local function FitSearchBox(searchBox, component, hasRightNeighbor, compact)
    FitTextureAwareChild(
        searchBox,
        component,
        SEARCH_BOX_TEXTURE_LEFT_OFFSET,
        compact and SEARCH_BOX_TEXTURE_RIGHT_OFFSET_COMPACT
            or (hasRightNeighbor and SEARCH_BOX_TEXTURE_RIGHT_OFFSET_WITH_BUTTON or SEARCH_BOX_TEXTURE_RIGHT_OFFSET),
        SEARCH_BOX_TEXTURE_TOP_OFFSET,
        SEARCH_BOX_TEXTURE_BOTTOM_OFFSET
    )
end

local function SetSearchComponentCompact(component, compact)
    if component then
        component:SetSize(compact and SEARCH_BOX_COMPACT_WIDTH or SEARCH_BOX_WIDTH, SEARCH_BOX_HEIGHT)
    end
end

local function FitSortButton(button, component, compact)
    if not button or not component then
        return
    end

    button:ClearAllPoints()
    if compact then
        button:SetPoint("TOPLEFT", component, "TOPLEFT", SORT_BUTTON_COMPACT_LEFT_OFFSET, 0)
        button:SetPoint("BOTTOMRIGHT", component, "BOTTOMRIGHT", SORT_BUTTON_COMPACT_RIGHT_OFFSET, 0)
        return
    end

    button:SetAllPoints(component)
end

function Bags:EnsureButtonContainer()
    if self.buttonContainer then
        return self.buttonContainer
    end

    local container = VanillaEnhanced:CreateButtonContainer("VanillaEnhancedBagsButtonContainer", SORT_BUTTON_CONTAINER_OPTIONS)
    container:SetFrameStrata("HIGH")
    container:Hide()

    self.buttonContainer = container
    return container
end

function Bags:EnsureButton()
    if self.button then
        return self.button
    end

    local container = self:EnsureButtonContainer()
    local component = CreateControlComponent("VanillaEnhancedBagsSortButtonComponent", container, SORT_BUTTON_WIDTH, SORT_BUTTON_HEIGHT)
    local button = CreateFrame("Button", "VanillaEnhancedBagsSortButton", component, "UIPanelButtonTemplate")
    FitSortButton(button, component, false)
    button:SetText(T("bags.sort.button"))
    button:SetFrameStrata("HIGH")
    button:Hide()

    button:SetScript("OnClick", function()
        Bags:SortItems()
    end)
    button:SetScript("OnEnter", ShowSortTooltip)
    button:SetScript("OnLeave", HideTooltip)

    self.buttonComponent = component
    self.button = button
    return button
end

function Bags:EnsureSearchBox()
    if self.searchBox then
        return self.searchBox
    end

    local container = self:EnsureButtonContainer()
    local component = CreateControlComponent("VanillaEnhancedBagsSearchComponent", container, SEARCH_BOX_WIDTH, SEARCH_BOX_HEIGHT)
    local searchBox = CreateFrame("EditBox", "VanillaEnhancedBagsSearchBox", component, "InputBoxTemplate")
    FitSearchBox(searchBox, component, false)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(64)
    searchBox:SetFrameStrata("HIGH")
    if searchBox.SetTextInsets then
        searchBox:SetTextInsets(6, 4, 0, 0)
    end
    if searchBox.SetFontObject then
        searchBox:SetFontObject(GameFontHighlightSmall)
    end
    searchBox:Hide()

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
    placeholder:SetPoint("RIGHT", searchBox, "RIGHT", -4, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetText(T("bags.search.placeholder"))
    searchBox.placeholder = placeholder

    searchBox:SetScript("OnTextChanged", function(self)
        UpdateSearchPlaceholder(self)
        Bags:SetSearchText(self:GetText() or "")
    end)
    searchBox:SetScript("OnEditFocusGained", UpdateSearchPlaceholder)
    searchBox:SetScript("OnEditFocusLost", UpdateSearchPlaceholder)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnter", ShowSearchTooltip)
    searchBox:SetScript("OnLeave", HideTooltip)

    UpdateSearchPlaceholder(searchBox)
    self.searchComponent = component
    self.searchBox = searchBox
    return searchBox
end

function Bags:EnsureBankButtonContainer()
    if self.bankButtonContainer then
        return self.bankButtonContainer
    end

    local container = VanillaEnhanced:CreateButtonContainer("VanillaEnhancedBagsBankButtonContainer", SORT_BUTTON_CONTAINER_OPTIONS)
    container:SetFrameStrata("HIGH")
    container:Hide()

    self.bankButtonContainer = container
    return container
end

function Bags:EnsureBankSearchBox()
    if self.bankSearchBox then
        return self.bankSearchBox
    end

    local container = self:EnsureBankButtonContainer()
    local component = CreateControlComponent("VanillaEnhancedBagsBankSearchComponent", container, SEARCH_BOX_WIDTH, SEARCH_BOX_HEIGHT)
    local searchBox = CreateFrame("EditBox", "VanillaEnhancedBagsBankSearchBox", component, "InputBoxTemplate")
    FitSearchBox(searchBox, component, false)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(64)
    searchBox:SetFrameStrata("HIGH")
    if searchBox.SetTextInsets then
        searchBox:SetTextInsets(6, 4, 0, 0)
    end
    if searchBox.SetFontObject then
        searchBox:SetFontObject(GameFontHighlightSmall)
    end
    searchBox:Hide()

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
    placeholder:SetPoint("RIGHT", searchBox, "RIGHT", -4, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetText(T("bags.search.placeholder"))
    searchBox.placeholder = placeholder

    searchBox:SetScript("OnTextChanged", function(self)
        UpdateSearchPlaceholder(self)
        Bags:SetBankSearchText(self:GetText() or "")
    end)
    searchBox:SetScript("OnEditFocusGained", UpdateSearchPlaceholder)
    searchBox:SetScript("OnEditFocusLost", UpdateSearchPlaceholder)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnter", ShowBankSearchTooltip)
    searchBox:SetScript("OnLeave", HideTooltip)

    UpdateSearchPlaceholder(searchBox)
    self.bankSearchComponent = component
    self.bankSearchBox = searchBox
    return searchBox
end

function Bags:EnsureBankStackButton()
    if self.bankStackButton then
        return self.bankStackButton
    end

    local container = self:EnsureBankButtonContainer()
    local component = CreateControlComponent(
        "VanillaEnhancedBagsBankStackButtonComponent",
        container,
        BANK_STACK_BUTTON_WIDTH,
        SORT_BUTTON_HEIGHT
    )
    local button = CreateFrame("Button", "VanillaEnhancedBagsBankStackButton", component, "UIPanelButtonTemplate")
    button:SetAllPoints(component)
    button:SetText(T("bags.bank.stack.button"))
    button:SetFrameStrata("HIGH")
    button:Hide()

    button:SetScript("OnClick", function()
        Bags:StackItemsToBank()
    end)
    button:SetScript("OnEnter", ShowBankStackTooltip)
    button:SetScript("OnLeave", HideTooltip)

    self.bankStackButtonComponent = component
    self.bankStackButton = button
    return button
end

function Bags:EnsureBankSortButton()
    if self.bankSortButton then
        return self.bankSortButton
    end

    local container = self:EnsureBankButtonContainer()
    local component = CreateControlComponent("VanillaEnhancedBagsBankSortButtonComponent", container, SORT_BUTTON_WIDTH, SORT_BUTTON_HEIGHT)
    local button = CreateFrame("Button", "VanillaEnhancedBagsBankSortButton", component, "UIPanelButtonTemplate")
    FitSortButton(button, component, false)
    button:SetText(T("bags.sort.button"))
    button:SetFrameStrata("HIGH")
    button:Hide()

    button:SetScript("OnClick", function()
        Bags:SortBankItems()
    end)
    button:SetScript("OnEnter", ShowBankSortTooltip)
    button:SetScript("OnLeave", HideTooltip)

    self.bankSortButtonComponent = component
    self.bankSortButton = button
    return button
end

function Bags:EnsureScrapToggleButton()
    if self.scrapToggleButton then
        return self.scrapToggleButton
    end

    local container = self:EnsureButtonContainer()
    local component = CreateControlComponent(
        "VanillaEnhancedBagsScrapToggleButtonComponent",
        container,
        SCRAP_TOGGLE_BUTTON_SIZE,
        SCRAP_TOGGLE_BUTTON_SIZE
    )
    local button = CreateFrame("Button", "VanillaEnhancedBagsScrapToggleButton", component, "UIPanelButtonTemplate")
    button:SetAllPoints(component)
    button:SetFrameStrata("HIGH")
    button:Hide()

    local Merchants = VanillaEnhanced:GetModule("merchants")
    if Merchants and Merchants.ConfigureScrapMarkButton then
        Merchants:ConfigureScrapMarkButton(button, SCRAP_TOGGLE_BUTTON_SIZE)
    end

    button:SetScript("OnClick", function()
        local MerchantModule = VanillaEnhanced:GetModule("merchants")
        if MerchantModule and MerchantModule.SetScrapMarkMode then
            MerchantModule:SetScrapMarkMode(MerchantModule.scrapMarkMode ~= true)
            if GameTooltip and GameTooltip:IsOwned(button) and MerchantModule.ShowScrapMarkButtonTooltip then
                MerchantModule:ShowScrapMarkButtonTooltip(button)
            end
        end
    end)
    button:SetScript("OnEnter", ShowScrapToggleTooltip)
    button:SetScript("OnLeave", HideScrapToggleTooltip)

    self.scrapToggleButtonComponent = component
    self.scrapToggleButton = button
    return button
end

function Bags:HideControls()
    if self.button then
        self.button:Hide()
    end
    if self.buttonComponent then
        self.buttonComponent:Hide()
    end
    if self.searchBox then
        if self.searchBox.ClearFocus then
            self.searchBox:ClearFocus()
        end
        self.searchBox:Hide()
    end
    if self.searchComponent then
        self.searchComponent:Hide()
    end
    if self.scrapToggleButton then
        self.scrapToggleButton:Hide()
    end
    if self.scrapToggleButtonComponent then
        self.scrapToggleButtonComponent:Hide()
    end
    if self.buttonContainer then
        self.buttonContainer:Hide()
    end
end

function Bags:HideBankControls()
    if self.bankSortButton then
        self.bankSortButton:Hide()
    end
    if self.bankSortButtonComponent then
        self.bankSortButtonComponent:Hide()
    end
    if self.bankStackButton then
        self.bankStackButton:Hide()
    end
    if self.bankStackButtonComponent then
        self.bankStackButtonComponent:Hide()
    end
    if self.bankSearchBox then
        if self.bankSearchBox.ClearFocus then
            self.bankSearchBox:ClearFocus()
        end
        self.bankSearchBox:Hide()
    end
    if self.bankSearchComponent then
        self.bankSearchComponent:Hide()
    end
    if self.bankButtonContainer then
        self.bankButtonContainer:Hide()
    end
end

function Bags:SetSortButtonBusy(busy)
    if not self.button then
        return
    end

    if busy then
        if self.button.Disable then
            self.button:Disable()
        end
        return
    end

    if self.button.Enable then
        self.button:Enable()
    end
end

function Bags:SetBankSortButtonBusy(busy)
    if not self.bankSortButton then
        return
    end

    if busy then
        if self.bankSortButton.Disable then
            self.bankSortButton:Disable()
        end
        return
    end

    if self.bankSortButton.Enable then
        self.bankSortButton:Enable()
    end
end

function Bags:SetBankStackButtonBusy(busy)
    if not self.bankStackButton then
        return
    end

    if busy then
        if self.bankStackButton.Disable then
            self.bankStackButton:Disable()
        end
        return
    end

    if self.bankStackButton.Enable then
        self.bankStackButton:Enable()
    end
end

function Bags:ClearSearchOverlaySet(overlayKey)
    for button in pairs(self[overlayKey] or {}) do
        if button.VanillaEnhancedSearchDimOverlay then
            button.VanillaEnhancedSearchDimOverlay:Hide()
        end
        if button.VanillaEnhancedSearchDimmedIcon and button.VanillaEnhancedSearchDimmedIcon.SetAlpha then
            button.VanillaEnhancedSearchDimmedIcon:SetAlpha(button.VanillaEnhancedSearchOriginalIconAlpha or 1)
        end
        button.VanillaEnhancedSearchDimmedIcon = nil
        button.VanillaEnhancedSearchOriginalIconAlpha = nil
        self[overlayKey][button] = nil
    end
end

function Bags:ClearSearchOverlays()
    self:ClearSearchOverlaySet("searchOverlayButtons")
end

function Bags:ClearBankSearchOverlays()
    self:ClearSearchOverlaySet("bankSearchOverlayButtons")
end

function Bags:ClearSearchText()
    self.searchText = ""
    if self.searchBox and self.searchBox.GetText and self.searchBox:GetText() ~= "" then
        self.searchBox:SetText("")
    end
    if self.searchBox then
        UpdateSearchPlaceholder(self.searchBox)
    end
    self:ClearSearchOverlays()
end

function Bags:ClearBankSearchText()
    self.bankSearchText = ""
    if self.bankSearchBox and self.bankSearchBox.GetText and self.bankSearchBox:GetText() ~= "" then
        self.bankSearchBox:SetText("")
    end
    if self.bankSearchBox then
        UpdateSearchPlaceholder(self.bankSearchBox)
    end
    self:ClearBankSearchOverlays()
end

function Bags:SetSearchText(text)
    self.searchText = NormalizeSearchText(text)
    self:RefreshSearchResults()
end

function Bags:SetBankSearchText(text)
    self.bankSearchText = NormalizeSearchText(text)
    self:RefreshBankSearchResults()
end

function Bags:IsSearchActive()
    return self:IsSortEnabled() and self:GetSettings().showSearchField == true and (self.searchText or "") ~= ""
end

function Bags:IsBankSearchActive()
    return self:IsSortEnabled() and self:GetSettings().showSearchField == true and (self.bankSearchText or "") ~= ""
end

function Bags:DoesItemMatchSearch(bagID, slot, query)
    query = query or self.searchText or ""
    if query == "" then
        return true
    end
    if not self.Api then
        return false
    end

    local containerItem = self.Api:GetContainerItemInfo(bagID, slot)
    if not containerItem then
        return true
    end

    local link = containerItem.hyperlink or self.Api:GetContainerItemLink(bagID, slot)
    local itemID = containerItem.itemID
    local itemInfo = self.Api:GetItemInfo(link or itemID)

    return TextContains(itemInfo and itemInfo.name, query)
        or TextContains(link, query)
        or TextContains(itemInfo and itemInfo.itemType, query)
        or TextContains(itemInfo and itemInfo.itemSubType, query)
        or TextContains(itemID and tostring(itemID), query)
        or TooltipContainsSearchText(bagID, slot, query)
end

function Bags:EnsureSearchDimOverlay(button)
    if button.VanillaEnhancedSearchDimOverlay then
        return button.VanillaEnhancedSearchDimOverlay
    end

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    overlay:SetVertexColor(0, 0, 0, SEARCH_DIM_ALPHA)
    overlay:Hide()

    local icon = GetItemButtonIcon(button)
    if icon then
        overlay:SetAllPoints(icon)
    else
        overlay:SetAllPoints(button)
    end

    button.VanillaEnhancedSearchDimOverlay = overlay
    return overlay
end

function Bags:SetButtonSearchDimmed(button, dimmed, overlayKey)
    overlayKey = overlayKey or "searchOverlayButtons"
    local icon = GetItemButtonIcon(button)

    if dimmed then
        local overlay = self:EnsureSearchDimOverlay(button)
        overlay:Show()
        if icon and icon.SetAlpha then
            if not button.VanillaEnhancedSearchDimmedIcon then
                button.VanillaEnhancedSearchOriginalIconAlpha = icon.GetAlpha and icon:GetAlpha() or 1
            end
            icon:SetAlpha(SEARCH_ICON_ALPHA)
            button.VanillaEnhancedSearchDimmedIcon = icon
        end
        self[overlayKey] = self[overlayKey] or {}
        self[overlayKey][button] = true
        return
    end

    if button.VanillaEnhancedSearchDimOverlay then
        button.VanillaEnhancedSearchDimOverlay:Hide()
    end
    if button.VanillaEnhancedSearchDimmedIcon and button.VanillaEnhancedSearchDimmedIcon.SetAlpha then
        button.VanillaEnhancedSearchDimmedIcon:SetAlpha(button.VanillaEnhancedSearchOriginalIconAlpha or 1)
    end
    button.VanillaEnhancedSearchDimmedIcon = nil
    button.VanillaEnhancedSearchOriginalIconAlpha = nil
    if self[overlayKey] then
        self[overlayKey][button] = nil
    end
end

function Bags:RefreshSearchResults()
    if not self:IsSearchActive() then
        self:ClearSearchOverlays()
        return
    end

    self.searchOverlayButtons = self.searchOverlayButtons or {}

    for index = 1, GetContainerFrameCount() do
        local frame = _G["ContainerFrame" .. index]
        if IsShown(frame) and frame.GetID then
            local bagID = frame:GetID()
            if IsPlayerBagID(bagID) then
                local slotCount = self.Api and self.Api:GetContainerNumSlots(bagID) or 0
                local buttonCount = math.max(slotCount or 0, frame.size or 0)
                if buttonCount <= 0 then
                    buttonCount = GetMaxContainerButtons()
                end
                buttonCount = math.min(buttonCount, GetMaxContainerButtons())

                for buttonIndex = 1, buttonCount do
                    local button = GetContainerItemButton(frame, buttonIndex)
                    if button then
                        local slot = button.GetID and button:GetID() or buttonIndex
                        local containerItem = self.Api and self.Api:GetContainerItemInfo(bagID, slot) or nil
                        local hasItem = containerItem
                            and (containerItem.hyperlink or containerItem.itemID or containerItem.iconFileID)

                        self:SetButtonSearchDimmed(button, IsShown(button) and hasItem and not self:DoesItemMatchSearch(bagID, slot))
                    end
                end
            end
        end
    end
end

function Bags:RefreshBankSearchButton(button, bagID, slot)
    if not button then
        return
    end

    local containerItem = self.Api and self.Api:GetContainerItemInfo(bagID, slot) or nil
    local hasItem = containerItem and (containerItem.hyperlink or containerItem.itemID or containerItem.iconFileID)
    local dimmed = IsShown(button)
        and hasItem
        and not self:DoesItemMatchSearch(bagID, slot, self.bankSearchText or "")
    self:SetButtonSearchDimmed(button, dimmed, "bankSearchOverlayButtons")
end

function Bags:RefreshBankSearchResults()
    if not self:IsBankSearchActive() or not IsBankFrameVisible() then
        self:ClearBankSearchOverlays()
        return
    end

    self.bankSearchOverlayButtons = self.bankSearchOverlayButtons or {}

    local bankBagID = GetBankContainerID()
    local bankSlotCount = self.Api and self.Api:GetContainerNumSlots(bankBagID) or 0
    for slot = 1, bankSlotCount do
        self:RefreshBankSearchButton(GetBankMainItemButton(slot), bankBagID, slot)
    end

    for index = 1, GetContainerFrameCount() do
        local frame = _G["ContainerFrame" .. index]
        if IsShown(frame) and frame.GetID then
            local bagID = frame:GetID()
            if IsBankBagID(bagID) then
                local slotCount = self.Api and self.Api:GetContainerNumSlots(bagID) or 0
                local buttonCount = math.max(slotCount or 0, frame.size or 0)
                if buttonCount <= 0 then
                    buttonCount = GetMaxContainerButtons()
                end
                buttonCount = math.min(buttonCount, GetMaxContainerButtons())

                for buttonIndex = 1, buttonCount do
                    local button = GetContainerItemButton(frame, buttonIndex)
                    if button then
                        local slot = button.GetID and button:GetID() or buttonIndex
                        self:RefreshBankSearchButton(button, bagID, slot)
                    end
                end
            end
        end
    end
end

function Bags:UpdateBankControls(settings)
    if not IsBankFrameVisible() then
        self:ClearBankSearchText()
        self:HideBankControls()
        return
    end

    local showSortButton = settings.showSortButton ~= false
    local showSearchField = settings.showSearchField == true
    local controls = {}
    local container = self:EnsureBankButtonContainer()
    local searchBox
    local stackButton = self:EnsureBankStackButton()
    local sortButton

    if showSearchField then
        searchBox = self:EnsureBankSearchBox()
        SetSearchComponentCompact(self.bankSearchComponent, false)
        controls[#controls + 1] = self.bankSearchComponent or searchBox
    elseif self.bankSearchBox then
        self:ClearBankSearchText()
        SetSearchComponentCompact(self.bankSearchComponent, false)
        self.bankSearchBox:Hide()
        if self.bankSearchComponent then
            self.bankSearchComponent:Hide()
        end
    end

    controls[#controls + 1] = self.bankStackButtonComponent or stackButton

    if showSortButton then
        sortButton = self:EnsureBankSortButton()
        controls[#controls + 1] = self.bankSortButtonComponent or sortButton
    elseif self.bankSortButton then
        self.bankSortButton:Hide()
        if self.bankSortButtonComponent then
            self.bankSortButtonComponent:Hide()
        end
    end

    container:SetParent(BankFrame)
    container:SetFrameStrata(BankFrame:GetFrameStrata() or "HIGH")
    container:SetFrameLevel((BankFrame:GetFrameLevel() or 0) + 10)
    container:ClearAllPoints()
    container:SetPoint("TOPRIGHT", GetBankMoneyFrame(), "BOTTOMRIGHT", SORT_CONTAINER_OFFSET_X, BANK_CONTAINER_OFFSET_Y)
    VanillaEnhanced:LayoutButtonContainer(container, controls, BAG_CONTROL_CONTAINER_OPTIONS)
    container:Show()

    if searchBox then
        if self.bankSearchComponent then
            FitSearchBox(searchBox, self.bankSearchComponent, true, false)
            self.bankSearchComponent:Show()
        end
        searchBox:Show()
        UpdateSearchPlaceholder(searchBox)
    end

    if stackButton then
        if self.bankStackButtonComponent then
            self.bankStackButtonComponent:Show()
        end
        stackButton:Show()
        self:SetBankStackButtonBusy(self.sorting == true)
    end

    if sortButton then
        if self.bankSortButtonComponent then
            FitSortButton(sortButton, self.bankSortButtonComponent, false)
            self.bankSortButtonComponent:Show()
        end
        sortButton:Show()
        self:SetBankSortButtonBusy(self.sorting == true)
    end

    self:RefreshBankSearchResults()
end

function Bags:Update()
    local settings = self:GetSettings()
    local showSortButton = settings.showSortButton ~= false
    local showSearchField = settings.showSearchField == true
    local Merchants = VanillaEnhanced:GetModule("merchants")
    local showScrapToggleButton = settings.showScrapIcon == true
        and settings.showScrapToggleButton == true
        and Merchants
        and Merchants.IsSellScrapsEnabled
        and Merchants:IsSellScrapsEnabled()

    if not self:IsSortEnabled() then
        if self.ClearAutoSort then
            self:ClearAutoSort()
        end
        if self.sorting and self.StopManualSort then
            self:StopManualSort()
        end
        if self.ClearItemLockOverlays then
            self:ClearItemLockOverlays()
        end
        self:ClearSearchText()
        self:ClearBankSearchText()
        self:HideControls()
        self:HideBankControls()
        return
    end

    local bagFrame = GetVisibleBagFrame()
    if not bagFrame then
        local allBagsClosed = IsAnyBagVisible and not IsAnyBagVisible()
        if allBagsClosed then
            if self.bagsWereVisible and settings.autoSortOnClose and self.QueueAutoSort then
                self:QueueAutoSort()
            end
            self:ClearAutoOpenBagTracking()
            DisableScrapMarkModeForClosedBags(self.scrapToggleButton)
        end
        self.bagsWereVisible = false
        if self.ClearItemLockOverlays then
            self:ClearItemLockOverlays()
        end
        self:ClearSearchOverlays()
        self:HideControls()
        self:UpdateBankControls(settings)
        return
    end

    if not self.bagsWereVisible then
        self.bagsWereVisible = true
        if self.QueueAutoSort and settings.autoSortOnOpen then
            self:QueueAutoSort()
        end
    end

    if not showSearchField then
        self:ClearSearchText()
    end

    if not showSortButton and not showSearchField and not showScrapToggleButton then
        if self.RefreshItemLockOverlays then
            self:RefreshItemLockOverlays()
        end
        self:HideControls()
        self:UpdateBankControls(settings)
        return
    end

    local searchBox
    local scrapToggleButton
    local button
    local controls = {}
    local container = self:EnsureButtonContainer()

    if showSearchField then
        searchBox = self:EnsureSearchBox()
        SetSearchComponentCompact(self.searchComponent, showScrapToggleButton)
        controls[#controls + 1] = self.searchComponent or searchBox
    elseif self.searchBox then
        SetSearchComponentCompact(self.searchComponent, false)
        self.searchBox:Hide()
        if self.searchComponent then
            self.searchComponent:Hide()
        end
    end

    if showScrapToggleButton then
        scrapToggleButton = self:EnsureScrapToggleButton()
        controls[#controls + 1] = self.scrapToggleButtonComponent or scrapToggleButton
    elseif self.scrapToggleButton then
        self.scrapToggleButton:Hide()
        if self.scrapToggleButtonComponent then
            self.scrapToggleButtonComponent:Hide()
        end
    end

    if showSortButton then
        button = self:EnsureButton()
        controls[#controls + 1] = self.buttonComponent or button
    elseif self.button then
        self.button:Hide()
        if self.buttonComponent then
            self.buttonComponent:Hide()
        end
    end

    container:SetParent(bagFrame)
    container:SetFrameStrata(bagFrame:GetFrameStrata() or "HIGH")
    container:SetFrameLevel((bagFrame:GetFrameLevel() or 0) + 10)
    container:ClearAllPoints()
    container:SetPoint("TOPRIGHT", GetBagMoneyFrame(bagFrame), "BOTTOMRIGHT", SORT_CONTAINER_OFFSET_X, SORT_CONTAINER_OFFSET_Y)
    VanillaEnhanced:LayoutButtonContainer(
        container,
        controls,
        showScrapToggleButton and BAG_CONTROL_COMPACT_CONTAINER_OPTIONS or BAG_CONTROL_CONTAINER_OPTIONS
    )
    container:Show()
    if searchBox then
        if self.searchComponent then
            FitSearchBox(searchBox, self.searchComponent, showScrapToggleButton or showSortButton, showScrapToggleButton)
            self.searchComponent:Show()
        end
        searchBox:Show()
        UpdateSearchPlaceholder(searchBox)
    end
    if scrapToggleButton then
        if self.scrapToggleButtonComponent then
            self.scrapToggleButtonComponent:Show()
        end
        scrapToggleButton:Show()
        if Merchants and Merchants.UpdateScrapMarkButtonState then
            Merchants:UpdateScrapMarkButtonState()
        end
    end
    if button then
        if self.buttonComponent then
            FitSortButton(button, self.buttonComponent, showScrapToggleButton)
            self.buttonComponent:Show()
        end
        button:Show()
        self:SetSortButtonBusy(self.sorting == true)
    end
    if self.RefreshItemLockOverlays then
        self:RefreshItemLockOverlays()
    end
    self:RefreshSearchResults()
    self:UpdateBankControls(settings)
end

function Bags:QueueUpdate()
    updateFrame:SetScript("OnUpdate", function(frame)
        frame:SetScript("OnUpdate", nil)
        Bags:Update()
    end)
end

function Bags:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("bags", enabled)
    if self.RefreshItemLockClickOverlays then
        self:RefreshItemLockClickOverlays()
    end

    if enabled then
        self:QueueUpdate()
        return
    end

    if self.StopManualSort then
        self:StopManualSort()
    end

    self:ClearAutoOpenBagTracking()
    if self.ClearItemLockOverlays then
        self:ClearItemLockOverlays()
    end
    self:ClearSearchText()
    self:ClearBankSearchText()
    self:HideControls()
    self:HideBankControls()
end

function Bags:HookBagFunctions()
    if self.bagFunctionHooksInstalled or type(hooksecurefunc) ~= "function" then
        return
    end

    for _, functionName in ipairs(BAG_FUNCTIONS) do
        if type(_G[functionName]) == "function" then
            pcall(hooksecurefunc, functionName, function()
                Bags:QueueUpdate()
            end)
        end
    end

    self.bagFunctionHooksInstalled = true
end

function Bags:HookContainerFrames()
    self.hookedContainerFrames = self.hookedContainerFrames or {}

    for index = 1, GetContainerFrameCount() do
        local frame = _G["ContainerFrame" .. index]
        if frame and frame.HookScript and not self.hookedContainerFrames[frame] then
            frame:HookScript("OnShow", function()
                Bags:QueueUpdate()
            end)
            frame:HookScript("OnHide", function()
                Bags:QueueUpdate()
            end)
            self.hookedContainerFrames[frame] = true
        end
    end
end

function Bags:HookCharacterFrame()
    if self.characterFrameHooksInstalled then
        return
    end

    if CharacterFrame and CharacterFrame.HookScript then
        CharacterFrame:HookScript("OnShow", function()
            Bags:AutoOpenBags("character")
        end)
        CharacterFrame:HookScript("OnHide", function()
            Bags:AutoCloseBags("character")
        end)
    end

    if type(hooksecurefunc) == "function" and type(ShowUIPanel) == "function" then
        pcall(hooksecurefunc, "ShowUIPanel", function(frame)
            if frame == CharacterFrame then
                Bags:AutoOpenBags("character")
            end
        end)
    end

    self.characterFrameHooksInstalled = true
end

local eventFrame = CreateFrame("Frame")
Bags.eventFrame = eventFrame

eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName ~= VanillaEnhanced.addonName then
        return
    end

    Bags:GetSettings()
    if Bags.InstallItemLockHooks then
        Bags:InstallItemLockHooks()
    end
    Bags:HookBagFunctions()
    Bags:HookContainerFrames()
    Bags:HookCharacterFrame()

    if event == "MERCHANT_SHOW" then
        Bags:AutoOpenBags("merchant")
        Bags:QueueUpdate()
        return
    end

    if event == "MERCHANT_CLOSED" then
        Bags:AutoCloseBags("merchant")
        Bags:QueueUpdate()
        return
    end

    if event == "LOOT_CLOSED" and Bags.QueueAutoSort and Bags:GetSettings().autoSortAfterLoot then
        Bags:QueueAutoSort()
        return
    end

    if event == "BAG_UPDATE_DELAYED" and Bags.OnBagUpdateDelayed then
        Bags:OnBagUpdateDelayed()
        return
    end

    if event == "BANKFRAME_CLOSED" then
        Bags:ClearBankSearchText()
        Bags:HideBankControls()
        Bags:QueueUpdate()
        return
    end

    Bags:QueueUpdate()
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
