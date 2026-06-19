local VanillaEnhanced = _G.VanillaEnhanced
local Bags = VanillaEnhanced:CreateModule("bags", "Bags")

local defaults = {
    enabled = true,
    sortEnabled = true,
    showSortButton = true,
    sortOrder = "category",
    autoSortAfterLoot = false,
    autoSortOnOpen = false,
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

function Bags:GetSettings()
    return VanillaEnhanced:GetModuleSettings("bags", defaults)
end

function Bags:IsSortEnabled()
    local settings = self:GetSettings()
    return settings.enabled ~= false and settings.sortEnabled ~= false
end

function Bags:PrintMessage(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Vanilla Enhanced:|r " .. message)
    end
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
    local fallback

    for index = 1, GetContainerFrameCount() do
        local frame = _G["ContainerFrame" .. index]
        if IsShown(frame) then
            if frame.GetID and frame:GetID() == 0 then
                return frame
            end
            fallback = fallback or frame
        end
    end

    return fallback
end

local function AnchorSortButton(button, bagFrame)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", bagFrame, "BOTTOMLEFT", 12, 9)
end

local function ShowTooltip(frame)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText("Sort bags")
    GameTooltip:AddLine("Sorts your backpack and equipped bags.", 1, 1, 1, true)
    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function Bags:EnsureButton()
    if self.button then
        return self.button
    end

    local button = CreateFrame("Button", "VanillaEnhancedBagsSortButton", UIParent, "UIPanelButtonTemplate")
    button:SetSize(46, 20)
    button:SetText("Sort")
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

    if not self:IsSortEnabled() then
        if self.ClearAutoSort then
            self:ClearAutoSort()
        end
        if self.sorting and self.StopManualSort then
            self:StopManualSort()
        end
        button:Hide()
        return
    end

    local bagFrame = GetVisibleBagFrame()
    if not bagFrame then
        self.bagsWereVisible = false
        button:Hide()
        return
    end

    if not self.bagsWereVisible then
        self.bagsWereVisible = true
        if self.QueueAutoSort and self:GetSettings().autoSortOnOpen then
            self:QueueAutoSort("open")
        end
    end

    if self:GetSettings().showSortButton == false then
        button:Hide()
        return
    end

    button:SetParent(bagFrame)
    button:SetFrameStrata(bagFrame:GetFrameStrata() or "HIGH")
    button:SetFrameLevel((bagFrame:GetFrameLevel() or 0) + 10)
    AnchorSortButton(button, bagFrame)
    button:Show()
    self:SetSortButtonBusy(self.sorting == true)
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

    if self.button then
        self.button:Hide()
    end
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
