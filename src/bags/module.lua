local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:CreateModule("bags", VanillaEnhanced:T("module.bags"))

local defaults = {
    enabled = true,
    showSortButton = true,
    sortOrder = "category",
    enableItemLocking = true,
    autoSortAfterLoot = false,
    autoSortAfterLootMode = "tidy",
    autoSortOnOpen = false,
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

local updateFrame = CreateFrame("Frame")

local SORT_BUTTON_WIDTH = 46
local SORT_BUTTON_HEIGHT = 20
local SORT_BUTTON_SPACING = 1
local SORT_BUTTON_PADDING = 5
local SORT_CONTAINER_OFFSET_X = 0
local SORT_CONTAINER_OFFSET_Y = -8

local SORT_BUTTON_CONTAINER_OPTIONS = {
    buttonCount = 1,
    buttonWidth = SORT_BUTTON_WIDTH,
    buttonHeight = SORT_BUTTON_HEIGHT,
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

local function ShowTooltip(frame)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("bags.sort.tooltipTitle"))
    GameTooltip:AddLine(T("bags.sort.tooltipBody"), 1, 1, 1, true)
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
    local button = CreateFrame("Button", "VanillaEnhancedBagsSortButton", container, "UIPanelButtonTemplate")
    button:SetSize(SORT_BUTTON_WIDTH, SORT_BUTTON_HEIGHT)
    button:SetText(T("bags.sort.button"))
    button:SetFrameStrata("HIGH")
    button:Hide()

    button:SetScript("OnClick", function()
        Bags:SortItems()
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", HideTooltip)

    self.button = button
    return button
end

function Bags:HideSortButton()
    if self.button then
        self.button:Hide()
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

function Bags:Update()
    local button = self:EnsureButton()
    local container = self:EnsureButtonContainer()

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
        self:HideSortButton()
        return
    end

    local bagFrame = GetVisibleBagFrame()
    if not bagFrame then
        self.bagsWereVisible = false
        if self.ClearItemLockOverlays then
            self:ClearItemLockOverlays()
        end
        self:HideSortButton()
        return
    end

    if not self.bagsWereVisible then
        self.bagsWereVisible = true
        if self.QueueAutoSort and self:GetSettings().autoSortOnOpen then
            self:QueueAutoSort("open")
        end
    end

    if self:GetSettings().showSortButton == false then
        if self.RefreshItemLockOverlays then
            self:RefreshItemLockOverlays()
        end
        self:HideSortButton()
        return
    end

    container:SetParent(bagFrame)
    container:SetFrameStrata(bagFrame:GetFrameStrata() or "HIGH")
    container:SetFrameLevel((bagFrame:GetFrameLevel() or 0) + 10)
    container:ClearAllPoints()
    container:SetPoint("TOPRIGHT", GetBagMoneyFrame(bagFrame), "BOTTOMRIGHT", SORT_CONTAINER_OFFSET_X, SORT_CONTAINER_OFFSET_Y)
    VanillaEnhanced:LayoutButtonContainer(container, {
        button,
    }, SORT_BUTTON_CONTAINER_OPTIONS)
    container:Show()
    button:Show()
    self:SetSortButtonBusy(self.sorting == true)
    if self.RefreshItemLockOverlays then
        self:RefreshItemLockOverlays()
    end
end

function Bags:QueueUpdate()
    updateFrame:SetScript("OnUpdate", function(frame)
        frame:SetScript("OnUpdate", nil)
        Bags:Update()
    end)
end

function Bags:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("bags", enabled)

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
    self:HideSortButton()
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
    if Bags.PruneItemLocks then
        Bags:PruneItemLocks()
    end
    Bags:HookBagFunctions()
    Bags:HookContainerFrames()

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
