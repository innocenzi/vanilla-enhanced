local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:CreateModule("bags", VanillaEnhanced:T("module.bags"))

local defaults = {
    enabled = true,
    showSortButton = true,
    showSearchField = true,
    sortOrder = "category",
    enableItemLocking = true,
    autoSortAfterLoot = false,
    autoSortAfterLootMode = "tidy",
    autoSortOnOpen = false,
    autoOpenMode = "disabled",
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
local SEARCH_BOX_WIDTH = 112
local SEARCH_BOX_HEIGHT = 20
local SORT_BUTTON_SPACING = 4
local SORT_BUTTON_PADDING = SORT_BUTTON_SPACING
local SORT_CONTAINER_OFFSET_X = 0
local SORT_CONTAINER_OFFSET_Y = -8
local SEARCH_DIM_ALPHA = 0.55
local SEARCH_ICON_ALPHA = 0.38
local MAX_SEARCH_BUTTONS = 36
local SEARCH_BOX_TEXTURE_LEFT_OFFSET = 5
local SEARCH_BOX_TEXTURE_RIGHT_OFFSET = 0
local SEARCH_BOX_TEXTURE_RIGHT_OFFSET_WITH_BUTTON = 5
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

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

function Bags:GetSettings()
    local settings = VanillaEnhanced:GetModuleSettings("bags", defaults)
    if settings.sortEnabled == false and settings.enabled ~= false then
        settings.enabled = false
    end
    settings.sortEnabled = nil
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

function Bags:AutoOpenBags(reason)
    if not self:ShouldAutoOpenBags(reason) or type(OpenAllBags) ~= "function" then
        return
    end

    pcall(OpenAllBags)
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

local function HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
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

local function FitSearchBox(searchBox, component, hasRightNeighbor)
    FitTextureAwareChild(
        searchBox,
        component,
        SEARCH_BOX_TEXTURE_LEFT_OFFSET,
        hasRightNeighbor and SEARCH_BOX_TEXTURE_RIGHT_OFFSET_WITH_BUTTON or SEARCH_BOX_TEXTURE_RIGHT_OFFSET,
        SEARCH_BOX_TEXTURE_TOP_OFFSET,
        SEARCH_BOX_TEXTURE_BOTTOM_OFFSET
    )
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
    button:SetAllPoints(component)
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
    if self.buttonContainer then
        self.buttonContainer:Hide()
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

function Bags:ClearSearchOverlays()
    for button in pairs(self.searchOverlayButtons or {}) do
        if button.VanillaEnhancedSearchDimOverlay then
            button.VanillaEnhancedSearchDimOverlay:Hide()
        end
        if button.VanillaEnhancedSearchDimmedIcon and button.VanillaEnhancedSearchDimmedIcon.SetAlpha then
            button.VanillaEnhancedSearchDimmedIcon:SetAlpha(button.VanillaEnhancedSearchOriginalIconAlpha or 1)
        end
        button.VanillaEnhancedSearchDimmedIcon = nil
        button.VanillaEnhancedSearchOriginalIconAlpha = nil
        self.searchOverlayButtons[button] = nil
    end
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

function Bags:SetSearchText(text)
    self.searchText = NormalizeSearchText(text)
    self:RefreshSearchResults()
end

function Bags:IsSearchActive()
    return self:IsSortEnabled() and self:GetSettings().showSearchField == true and (self.searchText or "") ~= ""
end

function Bags:DoesItemMatchSearch(bagID, slot)
    local query = self.searchText or ""
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

function Bags:SetButtonSearchDimmed(button, dimmed)
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
        self.searchOverlayButtons[button] = true
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
    self.searchOverlayButtons[button] = nil
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

function Bags:Update()
    local settings = self:GetSettings()
    local showSortButton = settings.showSortButton ~= false
    local showSearchField = settings.showSearchField == true

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
        self:HideControls()
        return
    end

    local bagFrame = GetVisibleBagFrame()
    if not bagFrame then
        self.bagsWereVisible = false
        if self.ClearItemLockOverlays then
            self:ClearItemLockOverlays()
        end
        self:ClearSearchOverlays()
        self:HideControls()
        return
    end

    if not self.bagsWereVisible then
        self.bagsWereVisible = true
        if self.QueueAutoSort and settings.autoSortOnOpen then
            self:QueueAutoSort("open")
        end
    end

    if not showSearchField then
        self:ClearSearchText()
    end

    if not showSortButton and not showSearchField then
        if self.RefreshItemLockOverlays then
            self:RefreshItemLockOverlays()
        end
        self:HideControls()
        return
    end

    local searchBox
    local button
    local controls = {}
    local container = self:EnsureButtonContainer()

    if showSearchField then
        searchBox = self:EnsureSearchBox()
        controls[#controls + 1] = self.searchComponent or searchBox
    elseif self.searchBox then
        self.searchBox:Hide()
        if self.searchComponent then
            self.searchComponent:Hide()
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
    VanillaEnhanced:LayoutButtonContainer(container, controls, BAG_CONTROL_CONTAINER_OPTIONS)
    container:Show()
    if searchBox then
        if self.searchComponent then
            FitSearchBox(searchBox, self.searchComponent, showSortButton)
            self.searchComponent:Show()
        end
        searchBox:Show()
        UpdateSearchPlaceholder(searchBox)
    end
    if button then
        if self.buttonComponent then
            self.buttonComponent:Show()
        end
        button:Show()
        self:SetSortButtonBusy(self.sorting == true)
    end
    if self.RefreshItemLockOverlays then
        self:RefreshItemLockOverlays()
    end
    self:RefreshSearchResults()
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

    if self.ClearItemLockOverlays then
        self:ClearItemLockOverlays()
    end
    self:ClearSearchText()
    self:HideControls()
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

    if event == "LOOT_CLOSED" and Bags.QueueAutoSort and Bags:GetSettings().autoSortAfterLoot then
        Bags:QueueAutoSort("loot")
        return
    end

    if event == "BAG_UPDATE_DELAYED" and Bags.OnBagUpdateDelayed then
        Bags:OnBagUpdateDelayed()
        return
    end

    Bags:QueueUpdate()
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("MERCHANT_SHOW")
