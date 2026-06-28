local VanillaEnhanced = _G.VanillaEnhanced
local Professions = VanillaEnhanced:GetModule("professions")

local RESPAWN_ESTIMATE_FAST = "fast"
local RESPAWN_ESTIMATE_NORMAL = "normal"
local RESPAWN_ESTIMATE_CONSERVATIVE = "conservative"
local MAP_PROVIDER_KEY = "professions:gathering"
local GATHERING_REFRESH_DELAY_SECONDS = 0.15

local characterGatheringDefaults = {
    nodes = {},
    nextNodeId = 1,
}

local gatheringDefaults = {
    trackGatheredNodes = true,
    showWorldMapNodes = true,
    showMinimapNodes = false,
    showMinimapNodeDirection = false,
    grayFreshNodes = true,
    respawnEstimate = RESPAWN_ESTIMATE_FAST,
    hideTrivialNodes = false,
    includePersonalNodes = true,
    includeSharedNodes = true,
    saveSharedNodes = true,
    sharedNodes = {},
    nextSharedNodeId = 1,
}

local GATHERING_MIGRATION_VERSION = 1
local gatheringSettingKeys = {
    "trackGatheredNodes",
    "showWorldMapNodes",
    "showMinimapNodes",
    "showMinimapNodeDirection",
    "grayFreshNodes",
    "respawnEstimate",
    "respawnEstimateMinutes",
    "hideTrivialNodes",
    "includePersonalNodes",
    "includeSharedNodes",
    "saveSharedNodes",
}
local gatheringSharedKeys = {
    "sharedNodes",
    "nextSharedNodeId",
}

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function CopyStoredValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, childValue in pairs(value) do
        copy[key] = CopyStoredValue(childValue)
    end
    return copy
end

local function CopyMissingSetting(target, source, key)
    if type(target) ~= "table" or type(source) ~= "table" or target[key] ~= nil or source[key] == nil then
        return
    end
    target[key] = CopyStoredValue(source[key])
end

local function NormalizeRespawnEstimate(settings)
    if settings.respawnEstimate == RESPAWN_ESTIMATE_NORMAL
        or settings.respawnEstimate == RESPAWN_ESTIMATE_CONSERVATIVE then
        settings.respawnEstimateMinutes = nil
        return settings.respawnEstimate
    end

    local legacyMinutes = tonumber(settings.respawnEstimateMinutes)
    if legacyMinutes then
        settings.respawnEstimateMinutes = nil
        if legacyMinutes <= 5 then
            return RESPAWN_ESTIMATE_FAST
        end
        if legacyMinutes <= 10 then
            return RESPAWN_ESTIMATE_NORMAL
        end
        return RESPAWN_ESTIMATE_CONSERVATIVE
    end

    settings.respawnEstimateMinutes = nil
    return RESPAWN_ESTIMATE_FAST
end

function Professions:MigrateGatheringSettings()
    local settings = VanillaEnhanced:GetSettings()
    local modules = settings.modules or {}
    settings.modules = modules
    modules.professions = modules.professions or {}
    local professionSettings = modules.professions
    local oldAccountSettings = modules.gathering

    local characterSettings = VanillaEnhanced:GetCharacterSettings()
    local characterModules = characterSettings.modules or {}
    characterSettings.modules = characterModules
    characterModules.professions = characterModules.professions or {}
    local professionCharacterSettings = characterModules.professions
    local oldCharacterSettings = characterModules.gathering

    if professionSettings.gatheringMigrationVersion ~= GATHERING_MIGRATION_VERSION then
        for _, key in ipairs(gatheringSettingKeys) do
            CopyMissingSetting(professionSettings, oldAccountSettings, key)
            CopyMissingSetting(professionSettings, oldCharacterSettings, key)
        end
        for _, key in ipairs(gatheringSharedKeys) do
            CopyMissingSetting(professionSettings, oldAccountSettings, key)
        end
        professionSettings.gatheringMigrationVersion = GATHERING_MIGRATION_VERSION
    end

    if professionCharacterSettings.gatheringMigrationVersion ~= GATHERING_MIGRATION_VERSION then
        CopyMissingSetting(professionCharacterSettings, oldCharacterSettings, "nodes")
        CopyMissingSetting(professionCharacterSettings, oldCharacterSettings, "nextNodeId")
        professionCharacterSettings.gatheringMigrationVersion = GATHERING_MIGRATION_VERSION
    end
end

function Professions:ApplyGatheringDefaults(settings)
    for key, value in pairs(gatheringDefaults) do
        if settings[key] == nil then
            if type(value) == "table" then
                settings[key] = {}
            else
                settings[key] = value
            end
        end
    end
    settings.saveSharedNodes = true
    settings.includePersonalNodes = true
    if type(settings.sharedNodes) ~= "table" then
        settings.sharedNodes = {}
    end
    if type(settings.nextSharedNodeId) ~= "number" or settings.nextSharedNodeId < 1 then
        settings.nextSharedNodeId = 1
    end
    settings.respawnEstimate = NormalizeRespawnEstimate(settings)
    return settings
end

function Professions:GetGatheringCharacterSettings()
    local settings = VanillaEnhanced:GetCharacterModuleSettings("professions", characterGatheringDefaults)
    if type(settings.nodes) ~= "table" then
        settings.nodes = {}
    end
    if type(settings.nextNodeId) ~= "number" or settings.nextNodeId < 1 then
        settings.nextNodeId = 1
    end
    return settings
end

function Professions:GetGatheringSharedSettings()
    return self:ApplyGatheringDefaults(self:GetSettings())
end

function Professions:GetMapModule()
    local map = VanillaEnhanced:GetModule("map")
    if map and not map.hbd then
        map.hbd = LibStub and LibStub("HereBeDragons-2.0", true)
    end
    return map
end

function Professions:GetHBD()
    local map = self:GetMapModule()
    return map and map.hbd or nil
end

function Professions:RegisterMapProvider()
    local map = self:GetMapModule()
    if not map or not map.RegisterMarkerProvider then
        return false
    end

    if map.markerProviders and map.markerProviders[MAP_PROVIDER_KEY] == self then
        self.mapProviderRegistered = true
        return false
    end

    map:RegisterMarkerProvider(MAP_PROVIDER_KEY, self)
    self.mapProviderRegistered = true
    return true
end

function Professions:UnregisterMapProvider()
    local map = self:GetMapModule()
    if map and map.UnregisterMarkerProvider then
        map:UnregisterMarkerProvider(MAP_PROVIDER_KEY)
    end
    self.mapProviderRegistered = false
end

function Professions:RefreshMap()
    self:InvalidateGatheringDisplayCache()
    local map = self:GetMapModule()
    if map and map.Refresh then
        map:Refresh()
    end
end

function Professions:InvalidateGatheringDisplayCache()
    self.gatheringDisplayNodes = nil
end

function Professions:RefreshGathering()
    self:InvalidateGatheringDisplayCache()

    if not self:IsEnabled() then
        self:UnregisterMapProvider()
        return
    end

    if not self:RegisterMapProvider() then
        self:RefreshMap()
    end
end

local function BuildProfessionSignature(professions)
    local professionIds = {}
    local parts = {}

    for professionId in pairs(professions or {}) do
        professionIds[#professionIds + 1] = professionId
    end
    table.sort(professionIds)

    for _, professionId in ipairs(professionIds) do
        parts[#parts + 1] = tostring(professionId)
        parts[#parts + 1] = ":"
        parts[#parts + 1] = tostring(professions[professionId] or 0)
        parts[#parts + 1] = ";"
    end

    return table.concat(parts)
end

function Professions:HasPlayerProfessionStateChanged()
    local previous = self.playerProfessionSignature
    self.playerProfessions = nil
    self:RefreshPlayerProfessions()
    self.playerProfessionSignature = BuildProfessionSignature(self.playerProfessions)
    return previous == nil or previous ~= self.playerProfessionSignature
end

function Professions:QueueGatheringRefresh()
    if self.gatheringRefreshQueued then
        return
    end

    self.gatheringRefreshQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(GATHERING_REFRESH_DELAY_SECONDS, function()
            Professions.gatheringRefreshQueued = false
            Professions:RefreshGathering()
        end)
        return
    end

    self.gatheringRefreshQueued = false
    self:RefreshGathering()
end

function Professions:ClearPersonalNodes()
    local settings = self:GetGatheringCharacterSettings()
    settings.nodes = {}
    settings.nextNodeId = 1
    self:RefreshGathering()
    VanillaEnhanced:PrintMessage(T("professions.gathering.nodes.personalCleared"))
end

function Professions:ClearSharedNodes()
    local settings = self:GetGatheringSharedSettings()
    settings.sharedNodes = {}
    settings.nextSharedNodeId = 1
    self:RefreshGathering()
    VanillaEnhanced:PrintMessage(T("professions.gathering.nodes.sharedCleared"))
end

local function ConfirmClear(dialogKey, textKey, acceptKey, onAccept)
    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs[dialogKey] = StaticPopupDialogs[dialogKey] or {
            text = T(textKey),
            button1 = T(acceptKey),
            button2 = CANCEL or T("options.main.resetSettings.cancel"),
            OnAccept = onAccept,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopupDialogs[dialogKey].text = T(textKey)
        StaticPopupDialogs[dialogKey].button1 = T(acceptKey)
        StaticPopupDialogs[dialogKey].button2 = CANCEL or T("options.main.resetSettings.cancel")
        StaticPopupDialogs[dialogKey].OnAccept = onAccept
        StaticPopup_Show(dialogKey)
        return
    end

    onAccept()
end

function Professions:ConfirmClearPersonalNodes()
    ConfirmClear(
        "VANILLAENHANCED_CLEAR_GATHERING_PERSONAL",
        "professions.gathering.nodes.clearPersonal.confirm",
        "professions.gathering.nodes.clear.accept",
        function()
            Professions:ClearPersonalNodes()
        end
    )
end

function Professions:ConfirmClearSharedNodes()
    ConfirmClear(
        "VANILLAENHANCED_CLEAR_GATHERING_SHARED",
        "professions.gathering.nodes.clearShared.confirm",
        "professions.gathering.nodes.clear.accept",
        function()
            Professions:ClearSharedNodes()
        end
    )
end

function Professions:HandleEvent(event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= VanillaEnhanced.addonName then
            return
        end
        self:GetSettings()
        self:GetGatheringCharacterSettings()
        self:GetGatheringSharedSettings()
        self:RefreshPlayerProfessions()
        self.playerProfessionSignature = BuildProfessionSignature(self.playerProfessions)
        self:RefreshGathering()
        return
    end

    if event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        if self.TrackGatherCast then
            self:TrackGatherCast(event, ...)
        end
        return
    end

    if event == "LOOT_OPENED" then
        if self.MarkGatherLootOpened then
            self:MarkGatherLootOpened()
        end
        return
    end

    if event == "CHAT_MSG_LOOT" then
        if self.CaptureGatherLootMessage then
            self:CaptureGatherLootMessage(...)
        end
        return
    end

    if event == "LOOT_CLOSED" then
        if self.CommitPendingGather then
            self:CommitPendingGather()
        end
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        self:GetSettings()
        self:GetGatheringCharacterSettings()
        self:GetGatheringSharedSettings()
        self:RefreshPlayerProfessions()
        self.playerProfessionSignature = BuildProfessionSignature(self.playerProfessions)
        self:RefreshGathering()
        return
    end

    if event == "SKILL_LINES_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
        if self:HasPlayerProfessionStateChanged() then
            self:QueueGatheringRefresh()
        end
        return
    end

    self:RefreshGathering()
end

local eventFrame = CreateFrame("Frame")
Professions.gatheringEventFrame = eventFrame
eventFrame:SetScript("OnEvent", function(_, event, ...)
    Professions:HandleEvent(event, ...)
end)

local function RegisterEventIfAvailable(eventName)
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end

RegisterEventIfAvailable("ADDON_LOADED")
RegisterEventIfAvailable("PLAYER_LOGIN")
RegisterEventIfAvailable("PLAYER_ENTERING_WORLD")
RegisterEventIfAvailable("SKILL_LINES_CHANGED")
RegisterEventIfAvailable("LEARNED_SPELL_IN_SKILL_LINE")
RegisterEventIfAvailable("UNIT_SPELLCAST_SENT")
RegisterEventIfAvailable("UNIT_SPELLCAST_SUCCEEDED")
RegisterEventIfAvailable("LOOT_OPENED")
RegisterEventIfAvailable("CHAT_MSG_LOOT")
RegisterEventIfAvailable("LOOT_CLOSED")
RegisterEventIfAvailable("ZONE_CHANGED")
RegisterEventIfAvailable("ZONE_CHANGED_NEW_AREA")
RegisterEventIfAvailable("ZONE_CHANGED_INDOORS")
