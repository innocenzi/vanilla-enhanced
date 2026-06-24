local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_COLOR = { 1, 0.48, 0.05 }
local HIGH_LEVEL_AVAILABLE_MARKER_RED_COLOR = { 1, 0.18, 0.12 }
local HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_LEVEL_DELTA = 3
local HIGH_LEVEL_AVAILABLE_MARKER_RED_LEVEL_DELTA = 6
local LOW_LEVEL_AVAILABLE_MARKER_ALPHA = 0.30
local TOOLTIP_AVAILABLE_FALLBACK_COLOR = { 0.7, 0.9, 0.65 }
local TOOLTIP_DIFFICULTY_COLORS = {
    trivial = { 0.55, 0.55, 0.55 },
    easy = { 0.25, 0.75, 0.25 },
    normal = { 1, 0.82, 0 },
    hard = { 1, 0.45, 0 },
    impossible = { 1, 0.1, 0.1 },
}
local REPEATABLE_TOOLTIP_ICON = [[Interface\Buttons\UI-RefreshButton]]

local function GetAvailableQuestLevel(dbQuest)
    if not dbQuest then
        return nil
    end

    if dbQuest.ql and dbQuest.ql > 0 then
        return dbQuest.ql
    end
    if dbQuest.rl and dbQuest.rl > 0 then
        return dbQuest.rl
    end
    return nil
end

local function GetDbQuest(quest)
    if not quest or not quest.id or not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        return nil
    end

    return VanillaEnhancedQuestsDB.quests[quest.id]
end

local function GetRepeatableTitleIcon(dbQuest)
    if Quests:IsRepeatableQuest(dbQuest) then
        return REPEATABLE_TOOLTIP_ICON
    end
    return nil
end

local function PastelizeColor(color)
    if not color then
        return TOOLTIP_AVAILABLE_FALLBACK_COLOR
    end

    local blend = 0.35
    return {
        color[1] + ((1 - color[1]) * blend),
        color[2] + ((1 - color[2]) * blend),
        color[3] + ((1 - color[3]) * blend),
    }
end

local function GetAvailableQuestTitleColor(dbQuest)
    local level = GetAvailableQuestLevel(dbQuest)

    if level and GetQuestDifficultyColor then
        local ok, color = pcall(GetQuestDifficultyColor, level)
        if ok and color then
            local red = color.r or color[1]
            local green = color.g or color[2]
            local blue = color.b or color[3]
            if red and green and blue then
                return PastelizeColor({ red, green, blue })
            end
        end
    end

    local playerLevel = UnitLevel and UnitLevel("player") or nil
    if not level or not playerLevel or playerLevel <= 0 then
        return TOOLTIP_AVAILABLE_FALLBACK_COLOR
    end

    local delta = level - playerLevel
    if delta >= 5 then
        return PastelizeColor(TOOLTIP_DIFFICULTY_COLORS.impossible)
    end
    if delta >= 3 then
        return PastelizeColor(TOOLTIP_DIFFICULTY_COLORS.hard)
    end
    if delta >= -2 then
        return PastelizeColor(TOOLTIP_DIFFICULTY_COLORS.normal)
    end
    if delta >= -5 then
        return PastelizeColor(TOOLTIP_DIFFICULTY_COLORS.easy)
    end
    return PastelizeColor(TOOLTIP_DIFFICULTY_COLORS.trivial)
end

local function InterpolateColor(fromColor, toColor, progress)
    return {
        fromColor[1] + ((toColor[1] - fromColor[1]) * progress),
        fromColor[2] + ((toColor[2] - fromColor[2]) * progress),
        fromColor[3] + ((toColor[3] - fromColor[3]) * progress),
    }
end

function Quests:BuildQuestPinData(quest, cluster)
    local localizedObjectives = self:GetLocalizedObjectives(quest, cluster)
    local localizedObjective = localizedObjectives and localizedObjectives[1] or self:GetClusterObjective(cluster)
    local kind = self:GetClusterKind(cluster)
    local countText
    local dbQuest = GetDbQuest(quest)

    if kind ~= "slay" and kind ~= "loot" then
        countText = self:GetLocalizedCountText(cluster.merged and "nearby" or "area", self:GetClusterCount(cluster))
    end

    return {
        questId = quest.id,
        number = quest.number,
        title = self:GetLocalizedQuestTitle(quest, quest.id, quest.title),
        titleIcon = GetRepeatableTitleIcon(dbQuest),
        objective = localizedObjective,
        objectives = localizedObjectives,
        cluster = cluster,
        merged = cluster.merged,
        count = self:GetClusterCount(cluster),
        countText = countText,
    }
end

local function CopyPinData(target, source)
    for key in pairs(target) do
        target[key] = nil
    end
    for key, value in pairs(source or {}) do
        target[key] = value
    end
end

local function BuildQuestLookup(quests)
    local lookup = {}

    for _, quest in ipairs(quests or {}) do
        if quest.id then
            lookup[quest.id] = quest
        end
    end

    return lookup
end

local function RefreshQuestPinDataObject(data, questsById, seen)
    if not data or seen[data] then
        return
    end
    seen[data] = true

    if data.entries then
        for _, entry in ipairs(data.entries) do
            RefreshQuestPinDataObject(entry.data, questsById, seen)
        end
        return
    end

    if not data.questId or not data.cluster then
        return
    end

    local quest = questsById[data.questId]
    if not quest then
        return
    end

    CopyPinData(data, Quests:BuildQuestPinData(quest, data.cluster))
end

local function RepaintOwnedPinTooltip(frame)
    if not frame or not GameTooltip or not GameTooltip.IsOwned or not Quests.ShowPinTooltip then
        return
    end
    if GameTooltip:IsOwned(frame) then
        Quests:ShowPinTooltip(frame)
    end
end

function Quests:RefreshQuestPinTooltipData(quests)
    local questsById = BuildQuestLookup(quests)
    local seen = {}

    for _, frame in ipairs(self.frames or {}) do
        RefreshQuestPinDataObject(frame.questsData, questsById, seen)
        RepaintOwnedPinTooltip(frame)
    end
    for _, frame in ipairs(self.minimapFrames or {}) do
        RefreshQuestPinDataObject(frame.questsData, questsById, seen)
        RepaintOwnedPinTooltip(frame)
    end
end

function Quests:BuildAvailableQuestPinData(questId, dbQuest, cluster, uiMapId, x, y)
    local metadataLines = {}

    local questLevel = GetAvailableQuestLevel(dbQuest)
    local hasQuestLevel = questLevel and questLevel > 0
    local questLabel = VanillaEnhanced:T("quests.static.available")
    local levelLabel

    if hasQuestLevel then
        metadataLines[#metadataLines + 1] = VanillaEnhanced:T("quests.static.availableQuestLevel", { level = questLevel })
    elseif dbQuest.rl and dbQuest.rl > 0 then
        levelLabel = VanillaEnhanced:T("quests.static.requiresLevel", { level = dbQuest.rl })
    end

    if not hasQuestLevel then
        metadataLines[#metadataLines + 1] = levelLabel and (questLabel .. " - " .. levelLabel) or questLabel
    end
    if hasQuestLevel and dbQuest.rl and dbQuest.rl > 0 and UnitLevel and UnitLevel("player") < dbQuest.rl then
        metadataLines[#metadataLines + 1] = VanillaEnhanced:T("quests.static.requiresLevel", { level = dbQuest.rl })
    end

    return {
        availableQuestId = questId,
        title = self:GetLocalizedQuestTitle(nil, questId, dbQuest.t),
        titleIcon = GetRepeatableTitleIcon(dbQuest),
        titleColor = GetAvailableQuestTitleColor(dbQuest),
        metadataLines = metadataLines,
        cluster = cluster,
        markerUiMapId = uiMapId,
        markerX = x and x / 100 or nil,
        markerY = y and y / 100 or nil,
    }
end

function Quests:GetAvailableQuestMarkerColor(dbQuest, context)
    local playerLevel = context and context.playerLevel or (UnitLevel and UnitLevel("player") or 0)
    local questLevel = GetAvailableQuestLevel(dbQuest)

    if not playerLevel or playerLevel <= 0 or not questLevel or questLevel <= 0 then
        return nil
    end

    local levelDelta = questLevel - playerLevel
    if levelDelta < HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_LEVEL_DELTA then
        return nil
    end
    if levelDelta >= HIGH_LEVEL_AVAILABLE_MARKER_RED_LEVEL_DELTA then
        return HIGH_LEVEL_AVAILABLE_MARKER_RED_COLOR
    end

    local progress = (levelDelta - HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_LEVEL_DELTA)
        / (HIGH_LEVEL_AVAILABLE_MARKER_RED_LEVEL_DELTA - HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_LEVEL_DELTA)
    return InterpolateColor(HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_COLOR, HIGH_LEVEL_AVAILABLE_MARKER_RED_COLOR, progress)
end

function Quests:GetAvailableQuestMarkerOpacity(dbQuest, context)
    if self.IsAvailableQuestBelowPlayerLevel and self:IsAvailableQuestBelowPlayerLevel(dbQuest, context) then
        return LOW_LEVEL_AVAILABLE_MARKER_ALPHA
    end
    return 1
end
