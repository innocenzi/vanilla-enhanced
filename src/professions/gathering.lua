local VanillaEnhanced = _G.VanillaEnhanced
local Professions = VanillaEnhanced:GetModule("professions")

local DEBUG_EVENT_LIMIT = 40
local DEBUG_COMMAND_KEY = "VANILLAENHANCED_GATHERING_DEBUG"
local DEBUG_PROFESSION_RANK_SPELLS = {
    [182] = {2366, 2368, 3570, 11993, 28695},
    [186] = {2575, 2576, 3564, 10248, 29354},
}
local RESPAWN_ESTIMATE_FAST = "fast"
local RESPAWN_ESTIMATE_NORMAL = "normal"
local RESPAWN_ESTIMATE_CONSERVATIVE = "conservative"
local MAP_PROVIDER_KEY = "professions:gathering"

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

local function DebugValue(value)
    if type(value) == "string" then
        return value
    end
    if type(value) == "number" or type(value) == "boolean" or value == nil then
        return tostring(value)
    end
    return "<" .. type(value) .. ">"
end

local function DebugPair(key, value)
    return tostring(key) .. "=" .. DebugValue(value)
end

local function DebugCount(value)
    local count = 0
    if type(value) ~= "table" then
        return 0
    end
    for _ in pairs(value) do
        count = count + 1
    end
    return count
end

local function DebugAppend(lines, text)
    lines[#lines + 1] = text or ""
end

local function DebugAppendTable(lines, label, value, keys)
    DebugAppend(lines, label .. ":")
    if type(value) ~= "table" then
        DebugAppend(lines, "  " .. DebugValue(value))
        return
    end

    if keys then
        for _, key in ipairs(keys) do
            DebugAppend(lines, "  " .. DebugPair(key, value[key]))
        end
        return
    end

    for key, tableValue in pairs(value) do
        DebugAppend(lines, "  " .. DebugPair(key, tableValue))
    end
end

local function DebugFormatArgs(...)
    local parts = {}
    local count = select("#", ...)
    for index = 1, math.min(count, 8) do
        parts[#parts + 1] = tostring(index) .. ":" .. DebugValue(select(index, ...))
    end
    if count > 8 then
        parts[#parts + 1] = "...+" .. tostring(count - 8)
    end
    return table.concat(parts, ", ")
end

local function DebugFormatCall(fn, ...)
    if type(fn) ~= "function" then
        return "unavailable"
    end

    local ok, result1, result2, result3, result4, result5, result6, result7, result8, result9, result10, result11, result12 = pcall(fn, ...)
    if not ok then
        return "error=" .. DebugValue(result1)
    end
    return DebugFormatArgs(result1, result2, result3, result4, result5, result6, result7, result8, result9, result10, result11, result12)
end

local function DebugAppendProfessionInfo(lines, slot, professionIndex)
    DebugAppend(lines, "  slot" .. tostring(slot) .. "=" .. DebugValue(professionIndex))
    if professionIndex and type(GetProfessionInfo) == "function" then
        DebugAppend(lines, "    GetProfessionInfo=" .. DebugFormatCall(GetProfessionInfo, professionIndex))
    end
end

local function DebugAppendProfessionApi(lines)
    DebugAppend(lines, "professionApi:")
    DebugAppend(lines, "  GetProfessions=" .. DebugValue(type(GetProfessions) == "function"))
    DebugAppend(lines, "  GetProfessionInfo=" .. DebugValue(type(GetProfessionInfo) == "function"))
    if type(GetProfessions) ~= "function" then
        return
    end

    local ok, profession1, profession2, archaeology, fishing, cooking, firstAid = pcall(GetProfessions)
    if not ok then
        DebugAppend(lines, "  GetProfessionsResult=error " .. DebugValue(profession1))
        return
    end

    DebugAppend(lines, "  GetProfessionsResult=" .. DebugFormatArgs(profession1, profession2, archaeology, fishing, cooking, firstAid))
    DebugAppendProfessionInfo(lines, 1, profession1)
    DebugAppendProfessionInfo(lines, 2, profession2)
    DebugAppendProfessionInfo(lines, 3, archaeology)
    DebugAppendProfessionInfo(lines, 4, fishing)
    DebugAppendProfessionInfo(lines, 5, cooking)
    DebugAppendProfessionInfo(lines, 6, firstAid)
end

local function DebugAppendProfessionSpellNames(lines)
    DebugAppend(lines, "professionSpellNames:")
    if type(GetSpellInfo) ~= "function" then
        DebugAppend(lines, "  unavailable")
        return
    end

    for professionID, spellIDs in pairs(DEBUG_PROFESSION_RANK_SPELLS) do
        DebugAppend(lines, "  profession" .. tostring(professionID) .. ":")
        for _, spellID in ipairs(spellIDs) do
            DebugAppend(lines, "    " .. tostring(spellID) .. "=" .. DebugValue(GetSpellInfo(spellID)))
        end
    end
end

local function DebugAppendSkillLines(lines)
    DebugAppend(lines, "skillLines:")
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        DebugAppend(lines, "  unavailable")
        return
    end

    if ExpandSkillHeader then
        pcall(ExpandSkillHeader, 0)
    end

    local okCount, count = pcall(GetNumSkillLines)
    if not okCount or type(count) ~= "number" then
        DebugAppend(lines, "  count=error " .. DebugValue(count))
        return
    end

    DebugAppend(lines, "  count=" .. tostring(count))
    for index = 1, math.min(count, 40) do
        local ok, skillName, isHeader, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable = pcall(GetSkillLineInfo, index)
        if ok then
            DebugAppend(lines, string.format(
                "  %s name=%s header=%s expanded=%s rank=%s temp=%s mod=%s max=%s abandonable=%s",
                tostring(index),
                DebugValue(skillName),
                DebugValue(isHeader),
                DebugValue(isExpanded),
                DebugValue(skillRank),
                DebugValue(numTempPoints),
                DebugValue(skillModifier),
                DebugValue(skillMaxRank),
                DebugValue(isAbandonable)
            ))
        else
            DebugAppend(lines, "  " .. tostring(index) .. " error=" .. DebugValue(skillName))
        end
    end
    if count > 40 then
        DebugAppend(lines, "  ...+" .. tostring(count - 40))
    end
end

function Professions:RecordGatheringDebugEvent(label, details)
    self.gatheringDebugEvents = self.gatheringDebugEvents or {}
    local entry = {
        time = GetTime and GetTime() or 0,
        label = label or "event",
        details = details,
    }
    self.gatheringDebugEvents[#self.gatheringDebugEvents + 1] = entry
    while #self.gatheringDebugEvents > DEBUG_EVENT_LIMIT do
        table.remove(self.gatheringDebugEvents, 1)
    end
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
    local map = self:GetMapModule()
    if map and map.Refresh then
        map:Refresh()
    end
end

function Professions:RefreshGathering()
    if not self:IsEnabled() then
        self:UnregisterMapProvider()
        return
    end

    if not self:RegisterMapProvider() then
        self:RefreshMap()
    end
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

function Professions:AppendGatheringDebugNode(lines, node, index)
    if type(node) ~= "table" then
        return
    end

    local info = self.GetResourceTypeInfo and self:GetResourceTypeInfo(node.resourceType) or nil
    local professions = self.GetPlayerProfessions and self:GetPlayerProfessions() or {}
    local playerSkill = info and professions and professions[info.professionId] or nil
    local graySkill = self.GetNodeGraySkill and self:GetNodeGraySkill(node) or nil
    local respawnRemaining = self.GetNodeRespawnRemainingSeconds and self:GetNodeRespawnRemainingSeconds(node) or nil
    local distance = self.GetNodeDistanceToPlayer and self:GetNodeDistanceToPlayer(node) or nil
    DebugAppend(lines, string.format(
        "  %s. id=%s scope=%s type=%s map=%s x=%s y=%s name=%s itemId=%s known=%s skill=%s grayAt=%s trivial=%s respawnRemaining=%s display=%s distance=%s",
        tostring(index),
        DebugValue(node.id),
        DebugValue(node.scope),
        DebugValue(node.resourceType),
        DebugValue(node.uiMapId),
        DebugValue(node.x),
        DebugValue(node.y),
        DebugValue(node.name),
        DebugValue(node.itemId),
        DebugValue(self.IsNodeProfessionKnown and self:IsNodeProfessionKnown(node) or nil),
        DebugValue(playerSkill),
        DebugValue(graySkill),
        DebugValue(self.IsNodeTrivial and self:IsNodeTrivial(node) or nil),
        DebugValue(respawnRemaining),
        DebugValue(self.ShouldDisplayNode and self:ShouldDisplayNode(node) or nil),
        distance and string.format("%.1f", distance) or "nil"
    ))
end

function Professions:BuildGatheringDebugDump()
    local lines = {}
    local settings = self:GetSettings()
    local characterSettings = self:GetGatheringCharacterSettings()
    local sharedSettings = self:GetGatheringSharedSettings()
    local map = self:GetMapModule()
    local hbd = self:GetHBD()
    local professions = self.GetPlayerProfessions and self:GetPlayerProfessions() or {}
    local hasHerbResourceProfession = self.HasResourceProfession and self:HasResourceProfession("herb")
    local hasOreResourceProfession = self.HasResourceProfession and self:HasResourceProfession("ore")
    local uiMapId, x, y
    if self.GetPlayerMapPosition then
        uiMapId, x, y = self:GetPlayerMapPosition()
    end
    local playerWorldX, playerWorldY, playerInstanceId
    if hbd and hbd.GetPlayerWorldPosition then
        playerWorldX, playerWorldY, playerInstanceId = hbd:GetPlayerWorldPosition()
    end
    local hbdZone, hbdZoneType
    if hbd and hbd.GetPlayerZone then
        hbdZone, hbdZoneType = hbd:GetPlayerZone()
    end

    DebugAppend(lines, "Vanilla Enhanced Gathering Debug")
    DebugAppend(lines, "time=" .. DebugValue(GetTime and GetTime() or nil))
    DebugAppend(lines, "addonName=" .. DebugValue(VanillaEnhanced.addonName))
    DebugAppend(lines, "locale=" .. DebugValue(VanillaEnhanced.GetLocaleKey and VanillaEnhanced:GetLocaleKey() or nil))
    DebugAppend(lines, "")

    DebugAppendTable(lines, "settings", settings, {
        "enabled",
        "trackGatheredNodes",
        "showWorldMapNodes",
        "showMinimapNodes",
        "showMinimapNodeDirection",
        "grayFreshNodes",
        "respawnEstimate",
        "hideTrivialNodes",
        "includePersonalNodes",
        "includeSharedNodes",
        "saveSharedNodes",
        "nextSharedNodeId",
    })
    DebugAppend(lines, "  sharedNodeCount=" .. tostring(#(sharedSettings.sharedNodes or {})))
    DebugAppend(lines, "")

    DebugAppendTable(lines, "characterSettings", characterSettings, {
        "nextNodeId",
    })
    DebugAppend(lines, "  personalNodeCount=" .. tostring(#(characterSettings.nodes or {})))
    DebugAppend(lines, "")

    DebugAppend(lines, "professions:")
    DebugAppend(lines, "  rawCount=" .. tostring(DebugCount(professions)))
    DebugAppend(lines, "  herbalism182=" .. DebugValue(professions and professions[182]))
    DebugAppend(lines, "  mining186=" .. DebugValue(professions and professions[186]))
    DebugAppend(lines, "  herbalismName=" .. DebugValue(self.GetProfessionName and self:GetProfessionName(182) or nil))
    DebugAppend(lines, "  miningName=" .. DebugValue(self.GetProfessionName and self:GetProfessionName(186) or nil))
    DebugAppend(lines, "  hasHerbResourceProfession=" .. DebugValue(hasHerbResourceProfession))
    DebugAppend(lines, "  hasOreResourceProfession=" .. DebugValue(hasOreResourceProfession))
    DebugAppend(lines, "")

    DebugAppendProfessionApi(lines)
    DebugAppend(lines, "")

    DebugAppendProfessionSpellNames(lines)
    DebugAppend(lines, "")

    DebugAppendSkillLines(lines)
    DebugAppend(lines, "")

    DebugAppend(lines, "position:")
    DebugAppend(lines, "  GetPlayerMapPosition map=" .. DebugValue(uiMapId) .. " x=" .. DebugValue(x) .. " y=" .. DebugValue(y))
    DebugAppend(lines, "  HBD zone=" .. DebugValue(hbdZone) .. " zoneType=" .. DebugValue(hbdZoneType))
    DebugAppend(lines, "  HBD worldX=" .. DebugValue(playerWorldX) .. " worldY=" .. DebugValue(playerWorldY) .. " instance=" .. DebugValue(playerInstanceId))
    DebugAppend(lines, "")

    DebugAppend(lines, "mapProvider:")
    DebugAppend(lines, "  mapModule=" .. DebugValue(map ~= nil))
    DebugAppend(lines, "  mapEnabled=" .. DebugValue(map and map.IsEnabled and map:IsEnabled() or nil))
    DebugAppend(lines, "  hbd=" .. DebugValue(hbd ~= nil))
    DebugAppend(lines, "  hbdPins=" .. DebugValue(map and map.hbdPins ~= nil or nil))
    DebugAppend(lines, "  registeredFlag=" .. DebugValue(self.mapProviderRegistered))
    DebugAppend(lines, "  providerInMap=" .. DebugValue(map and map.markerProviders and map.markerProviders[MAP_PROVIDER_KEY] == self or false))
    DebugAppend(lines, "  worldMapFrames=" .. tostring(map and #(map.worldMapFrames or {}) or 0))
    DebugAppend(lines, "  minimapFrames=" .. tostring(map and #(map.minimapFrames or {}) or 0))
    DebugAppend(lines, "")

    local displayNodes = self.GetDisplayNodes and self:GetDisplayNodes() or {}
    local worldMarkers = self.GetWorldMapMarkers and self:GetWorldMapMarkers() or {}
    local minimapMarkers = self.GetMinimapMarkers and self:GetMinimapMarkers() or {}
    DebugAppend(lines, "renderCounts:")
    DebugAppend(lines, "  displayNodes=" .. tostring(#displayNodes))
    DebugAppend(lines, "  worldMarkers=" .. tostring(#worldMarkers))
    DebugAppend(lines, "  minimapMarkers=" .. tostring(#minimapMarkers))
    DebugAppend(lines, "")

    DebugAppend(lines, "savedPersonalNodes:")
    for index, node in ipairs(characterSettings.nodes or {}) do
        if index > 12 then
            DebugAppend(lines, "  ...+" .. tostring(#characterSettings.nodes - 12))
            break
        end
        self:AppendGatheringDebugNode(lines, node, index)
    end
    DebugAppend(lines, "")

    DebugAppend(lines, "savedSharedNodes:")
    for index, node in ipairs(sharedSettings.sharedNodes or {}) do
        if index > 12 then
            DebugAppend(lines, "  ...+" .. tostring(#sharedSettings.sharedNodes - 12))
            break
        end
        self:AppendGatheringDebugNode(lines, node, index)
    end
    DebugAppend(lines, "")

    DebugAppendTable(lines, "pendingGather", self.pendingGather, {
        "resourceType",
        "spellId",
        "spellName",
        "targetName",
        "time",
        "lootOpened",
        "lootOpenedTime",
        "lootName",
        "lootItemId",
        "uiMapId",
        "x",
        "y",
    })
    DebugAppend(lines, "")

    DebugAppendTable(lines, "lastGatherCommit", self.lastGatherCommit, {
        "status",
        "reason",
        "resourceType",
        "spellId",
        "spellName",
        "targetName",
        "lootName",
        "itemId",
        "uiMapId",
        "x",
        "y",
        "nodeId",
    })
    DebugAppend(lines, "")

    DebugAppend(lines, "displayNodes:")
    for index, node in ipairs(displayNodes) do
        if index > 12 then
            DebugAppend(lines, "  ...+" .. tostring(#displayNodes - 12))
            break
        end
        self:AppendGatheringDebugNode(lines, node, index)
    end
    DebugAppend(lines, "")

    DebugAppend(lines, "recentEvents:")
    for _, entry in ipairs(self.gatheringDebugEvents or {}) do
        DebugAppend(lines, string.format(
            "  %.3f %s %s",
            tonumber(entry.time) or 0,
            DebugValue(entry.label),
            DebugValue(entry.details)
        ))
    end

    return table.concat(lines, "\n")
end

function Professions:ShowGatheringDebugDump()
    local frame = self.gatheringDebugFrame
    if not frame then
        frame = CreateFrame("Frame", "VanillaEnhancedGatheringDebugFrame", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(760, 520)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("LEFT", frame.TitleBg or frame, "LEFT", 8, 0)
        title:SetText("Vanilla Enhanced Gathering Debug")

        local scrollFrame = CreateFrame("ScrollFrame", "VanillaEnhancedGatheringDebugScrollFrame", frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
        scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 12)

        local editBox = CreateFrame("EditBox", "VanillaEnhancedGatheringDebugEditBox", scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(700)
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        scrollFrame:SetScrollChild(editBox)

        frame.editBox = editBox
        self.gatheringDebugFrame = frame
    end

    frame.editBox:SetText(self:BuildGatheringDebugDump())
    frame.editBox:HighlightText()
    frame.editBox:SetFocus()
    frame:Show()
end

function Professions:RegisterGatheringDebugCommand()
    if self.gatheringDebugCommandRegistered or not SlashCmdList then
        return
    end

    _G["SLASH_" .. DEBUG_COMMAND_KEY .. "1"] = "/vegatherdebug"
    _G["SLASH_" .. DEBUG_COMMAND_KEY .. "2"] = "/vegdebug"
    SlashCmdList[DEBUG_COMMAND_KEY] = function()
        Professions:ShowGatheringDebugDump()
    end
    self.gatheringDebugCommandRegistered = true
end

function Professions:HandleEvent(event, ...)
    self:RecordGatheringDebugEvent("event:" .. tostring(event), DebugFormatArgs(...))

    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= VanillaEnhanced.addonName then
            return
        end
    end

    self:GetSettings()
    self:GetGatheringCharacterSettings()
    self:GetGatheringSharedSettings()

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
        self:RegisterGatheringDebugCommand()
        self:RefreshGathering()
        return
    end

    if event == "SKILL_LINES_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
        self.playerProfessions = nil
    end

    self:RefreshGathering()
end

local eventFrame = CreateFrame("Frame")
Professions.gatheringEventFrame = eventFrame
eventFrame:SetScript("OnEvent", function(_, event, ...)
    Professions:HandleEvent(event, ...)
end)

Professions:RegisterGatheringDebugCommand()

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
