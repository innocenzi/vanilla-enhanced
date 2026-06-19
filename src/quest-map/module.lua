local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:CreateModule("quest-map", "Quest Map")

QuestMap.mediaPath = VanillaEnhanced.mediaPath
QuestMap.refreshQueued = QuestMap.refreshQueued or false
QuestMap.questLogOpenedByMap = QuestMap.questLogOpenedByMap or false
QuestMap.questLogWithMapLayoutTicks = QuestMap.questLogWithMapLayoutTicks or 0
QuestMap.suppressQuestLogWithMapSync = QuestMap.suppressQuestLogWithMapSync or false
QuestMap.worldMapWasUserPlaced = QuestMap.worldMapWasUserPlaced
QuestMap.worldMapHiddenForQuestLog = QuestMap.worldMapHiddenForQuestLog or false

local eventFrame = CreateFrame("Frame")
local clearHiddenFlagFrame = CreateFrame("Frame")
local layoutFrame = CreateFrame("Frame")

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function IsShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function SafeCall(method, owner, ...)
    if not method or not owner then
        return false, nil
    end
    return pcall(method, owner, ...)
end

local function GetFrameNumber(frame, methodName, fallback)
    local method = frame and frame[methodName]
    if not method then
        return fallback
    end

    local ok, value = pcall(method, frame)
    if ok and type(value) == "number" then
        return value
    end
    return fallback
end

local function GetUiParentNumber(methodName, fallback)
    local method = UIParent and UIParent[methodName]
    if method then
        local ok, value = pcall(method, UIParent)
        if ok and type(value) == "number" and value > 0 then
            return value
        end
    end
    return fallback
end

local function HookFrameScript(frame, scriptName, handler)
    if not frame or not handler then
        return
    end

    if frame.HookScript then
        frame:HookScript(scriptName, handler)
        return
    end

    local previous = frame:GetScript(scriptName)
    frame:SetScript(scriptName, function(...)
        if previous then
            previous(...)
        end
        handler(...)
    end)
end

local function ClearWorldMapHiddenFlagSoon()
    clearHiddenFlagFrame:SetScript("OnUpdate", function(self)
        QuestMap.worldMapHiddenForQuestLog = false
        self:SetScript("OnUpdate", nil)
    end)
end

local function ApplyUserPlaced(frame, userPlaced)
    if frame and frame.SetUserPlaced then
        SafeCall(frame.SetUserPlaced, frame, userPlaced)
    end
end

local function RememberWorldMapPlacement()
    if QuestMap.worldMapWasUserPlaced ~= nil or not WorldMapFrame or not WorldMapFrame.IsUserPlaced then
        return
    end

    local ok, userPlaced = pcall(WorldMapFrame.IsUserPlaced, WorldMapFrame)
    QuestMap.worldMapWasUserPlaced = ok and userPlaced == true
end

local function RestoreWorldMapPlacement()
    if QuestMap.worldMapWasUserPlaced == nil then
        return
    end

    ApplyUserPlaced(WorldMapFrame, QuestMap.worldMapWasUserPlaced)
    QuestMap.worldMapWasUserPlaced = nil
end

function QuestMap:IsQuestLogWithMapEnabled()
    if not self.GetSettings then
        return false
    end

    local settings = self:GetSettings()
    return settings.enabled ~= false and settings.keepQuestLogWithMap == true
end

function QuestMap:PositionQuestLogWithMap()
    if not self:IsQuestLogWithMapEnabled() or not IsShown(WorldMapFrame) or not IsShown(QuestLogFrame) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local spacing = 8
    local horizontalOffset = -140
    local verticalOffset = -30
    local sideMargin = 12
    local screenWidth = GetUiParentNumber("GetWidth", 1024)
    local screenHeight = GetUiParentNumber("GetHeight", 768)
    local mapWidth = GetFrameNumber(WorldMapFrame, "GetWidth", 700)
    local mapHeight = GetFrameNumber(WorldMapFrame, "GetHeight", 560)
    local questWidth = GetFrameNumber(QuestLogFrame, "GetWidth", 384)
    local questHeight = GetFrameNumber(QuestLogFrame, "GetHeight", 512)
    if mapWidth <= 0 then
        mapWidth = 700
    end
    if mapHeight <= 0 then
        mapHeight = 560
    end
    if questWidth <= 0 then
        questWidth = 384
    end
    if questHeight <= 0 then
        questHeight = 512
    end

    local totalWidth = mapWidth + spacing + questWidth
    local mapLeft = Clamp(((screenWidth - totalWidth) / 2) + horizontalOffset, sideMargin, math.max(sideMargin, screenWidth - mapWidth - sideMargin))
    local maxQuestLeft = math.max(sideMargin, screenWidth - questWidth - sideMargin)
    local questLeft = Clamp(mapLeft + mapWidth + spacing, sideMargin, maxQuestLeft)
    local mapTop = Clamp(((screenHeight + mapHeight) / 2) + verticalOffset, math.min(mapHeight, screenHeight), screenHeight)
    local questTop = Clamp(((screenHeight + questHeight) / 2) + verticalOffset, math.min(questHeight, screenHeight), screenHeight)

    RememberWorldMapPlacement()
    ApplyUserPlaced(WorldMapFrame, true)
    SafeCall(WorldMapFrame.ClearAllPoints, WorldMapFrame)
    SafeCall(WorldMapFrame.SetPoint, WorldMapFrame, "TOPLEFT", UIParent, "BOTTOMLEFT", mapLeft, mapTop)
    SafeCall(QuestLogFrame.ClearAllPoints, QuestLogFrame)
    if mapLeft + mapWidth + spacing + questWidth <= screenWidth - sideMargin then
        SafeCall(QuestLogFrame.SetPoint, QuestLogFrame, "LEFT", WorldMapFrame, "RIGHT", spacing, 0)
    else
        SafeCall(QuestLogFrame.SetPoint, QuestLogFrame, "TOPLEFT", UIParent, "BOTTOMLEFT", questLeft, questTop)
    end
end

function QuestMap:QueueQuestLogWithMapLayout(ticks)
    if not self:IsQuestLogWithMapEnabled() then
        return
    end

    self.questLogWithMapLayoutTicks = math.max(self.questLogWithMapLayoutTicks or 0, ticks or 6)
    layoutFrame:SetScript("OnUpdate", function(frame)
        if not QuestMap:IsQuestLogWithMapEnabled() or not IsShown(WorldMapFrame) or not IsShown(QuestLogFrame) then
            QuestMap.questLogWithMapLayoutTicks = 0
            frame:SetScript("OnUpdate", nil)
            return
        end

        QuestMap:PositionQuestLogWithMap()
        QuestMap.questLogWithMapLayoutTicks = (QuestMap.questLogWithMapLayoutTicks or 1) - 1
        if QuestMap.questLogWithMapLayoutTicks <= 0 then
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

function QuestMap:ShowQuestLogWithMap()
    if not self:IsQuestLogWithMapEnabled() or not QuestLogFrame then
        return false
    end

    local wasShown = IsShown(QuestLogFrame)
    self.suppressQuestLogWithMapSync = true
    local ok = SafeCall(QuestLogFrame.Show, QuestLogFrame)
    self.suppressQuestLogWithMapSync = false

    if not ok then
        return false
    end

    if not wasShown and IsShown(QuestLogFrame) then
        self.questLogOpenedByMap = true
    end

    self:PositionQuestLogWithMap()
    self:QueueQuestLogWithMapLayout(8)
    return IsShown(QuestLogFrame)
end

function QuestMap:RestoreWorldMapForQuestLog()
    if not self:IsQuestLogWithMapEnabled() or not self.worldMapHiddenForQuestLog then
        return false
    end

    if WorldMapFrame and not IsShown(WorldMapFrame) then
        self.suppressQuestLogWithMapSync = true
        SafeCall(WorldMapFrame.Show, WorldMapFrame)
        self.suppressQuestLogWithMapSync = false
    end

    self.worldMapHiddenForQuestLog = false
    self:ShowQuestLogWithMap()
    return true
end

function QuestMap:ApplyQuestLogWithMapSetting()
    if self:IsQuestLogWithMapEnabled() then
        if IsShown(WorldMapFrame) then
            self:ShowQuestLogWithMap()
        elseif IsShown(QuestLogFrame) then
            self:PositionQuestLogWithMap()
            self:QueueQuestLogWithMapLayout(8)
        end
        return
    end

    RestoreWorldMapPlacement()
    if self.questLogOpenedByMap and IsShown(QuestLogFrame) then
        self.suppressQuestLogWithMapSync = true
        SafeCall(QuestLogFrame.Hide, QuestLogFrame)
        self.suppressQuestLogWithMapSync = false
    end
    self.questLogOpenedByMap = false
    self.worldMapHiddenForQuestLog = false
end

function QuestMap:HookQuestLogWithMapFrames()
    if self.HookQuestLogSelection then
        self:HookQuestLogSelection()
    end

    if self.questLogWithMapHooksInstalled then
        self:ApplyQuestLogWithMapSetting()
        return
    end
    if not WorldMapFrame or not QuestLogFrame then
        return
    end

    HookFrameScript(WorldMapFrame, "OnShow", function()
        if QuestMap.suppressQuestLogWithMapSync then
            return
        end
        QuestMap.worldMapHiddenForQuestLog = false
        QuestMap:ShowQuestLogWithMap()
    end)

    HookFrameScript(WorldMapFrame, "OnHide", function()
        if QuestMap.suppressQuestLogWithMapSync then
            return
        end

        if not QuestMap:IsQuestLogWithMapEnabled() then
            QuestMap.questLogOpenedByMap = false
            return
        end

        QuestMap.worldMapHiddenForQuestLog = true
        ClearWorldMapHiddenFlagSoon()

        if QuestMap.questLogOpenedByMap and IsShown(QuestLogFrame) then
            QuestMap.suppressQuestLogWithMapSync = true
            SafeCall(QuestLogFrame.Hide, QuestLogFrame)
            QuestMap.suppressQuestLogWithMapSync = false
            QuestMap.questLogOpenedByMap = false
        end
    end)

    HookFrameScript(QuestLogFrame, "OnShow", function()
        if QuestMap.suppressQuestLogWithMapSync or not QuestMap:IsQuestLogWithMapEnabled() then
            return
        end

        if not QuestMap:RestoreWorldMapForQuestLog() then
            QuestMap:ShowQuestLogWithMap()
        end
    end)

    HookFrameScript(QuestLogFrame, "OnHide", function()
        if not QuestMap.suppressQuestLogWithMapSync then
            QuestMap.questLogOpenedByMap = false
        end
    end)

    if type(hooksecurefunc) == "function" and type(ShowUIPanel) == "function" then
        hooksecurefunc("ShowUIPanel", function(frame)
            if frame == QuestLogFrame then
                QuestMap:RestoreWorldMapForQuestLog()
            end
        end)
    end

    self.questLogWithMapHooksInstalled = true
    self:ApplyQuestLogWithMapSetting()
end

local function RegisterEventIfAvailable(frame, eventName)
    pcall(frame.RegisterEvent, frame, eventName)
end

RegisterEventIfAvailable(eventFrame, "ADDON_LOADED")
RegisterEventIfAvailable(eventFrame, "PLAYER_LOGIN")
RegisterEventIfAvailable(eventFrame, "PLAYER_ENTERING_WORLD")
RegisterEventIfAvailable(eventFrame, "QUEST_LOG_UPDATE")
RegisterEventIfAvailable(eventFrame, "ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == VanillaEnhanced.addonName then
        QuestMap:GetSettings()
        QuestMap:HookQuestLogWithMapFrames()
        QuestMap.hbdPins = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
    elseif event == "PLAYER_LOGIN" then
        QuestMap:HookQuestLogWithMapFrames()
        QuestMap:QueueRefresh()
    elseif event ~= "ADDON_LOADED" then
        QuestMap:HookQuestLogWithMapFrames()
        QuestMap:QueueRefresh()
    end
end)

QuestMap:HookQuestLogWithMapFrames()

if WorldMapFrame then
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        QuestMap:QueueRefresh()
    end)
end
