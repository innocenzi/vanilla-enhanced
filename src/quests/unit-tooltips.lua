local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

Quests.unitTooltipIndex = Quests.unitTooltipIndex or {}

local TOOLTIP_CLUSTER_KINDS = {
    event = true,
    loot = true,
    object = true,
    slay = true,
    talk = true,
    turnin = true,
}

local function GetNpcIdFromGuid(guid)
    if not guid then
        return nil
    end

    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil
    end
    return tonumber(npcId)
end

local function GetProgressText(objective)
    if not objective or objective == "" then
        return nil
    end

    local current, total = string.match(objective, "(%d+)%s*/%s*(%d+)")
    if current and total then
        return current .. "/" .. total
    end
    return nil
end

local function FormatDropText(rate)
    rate = tonumber(rate)
    if not rate then
        return nil
    end

    if rate >= 10 then
        return string.format("%.0f", rate)
    elseif rate >= 2 then
        return string.format("%.1f", rate)
    elseif rate >= 0.01 then
        return string.format("%.2f", rate)
    end
    return string.format("%.3f", rate)
end

local function GetDropRateText(cluster, npcId)
    if Quests:GetClusterKind(cluster) ~= "loot" or not npcId then
        return ""
    end

    local rate = FormatDropText(Quests:GetClusterDropRate(cluster, npcId))
    if rate then
        return " |cFF999999[" .. rate .. "%]|r"
    end
    return ""
end

local function GetQuestLevel(dbQuest)
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

local function IsTooltipDetailsExpanded()
    if VanillaEnhanced.IsTooltipDetailsExpanded then
        return VanillaEnhanced:IsTooltipDetailsExpanded()
    end
    return type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
end

local function BuildTooltipEntry(quest, dbQuest, cluster, npcId)
    local title = Quests:GetLocalizedQuestTitle(quest, quest.id, dbQuest and dbQuest.t or quest.title)
    local objectives = Quests:GetLocalizedObjectives(quest, cluster)
    local objective = objectives and objectives[1]

    local kind = Quests:GetClusterKind(cluster)

    if kind == "slay" or kind == "loot" then
        local sourceName = Quests:GetLocalizedSourceName(cluster)
        local progress = GetProgressText(objective)
        local detail

        if progress and sourceName and sourceName ~= "" then
            detail = "- " .. progress .. " " .. sourceName
        elseif objective and objective ~= "" then
            detail = "- " .. objective
        end

        return {
            number = quest.number,
            title = title,
            detail = detail,
            cluster = cluster,
            npcId = npcId,
            level = GetQuestLevel(dbQuest),
        }
    end

    if objective and objective ~= "" then
        return {
            number = quest.number,
            title = title .. ": " .. objective,
            level = GetQuestLevel(dbQuest),
        }
    end
    return {
        number = quest.number,
        title = title,
        level = GetQuestLevel(dbQuest),
    }
end

local function AddEntry(index, quest, dbQuest, cluster, npcId)
    if not npcId then
        return
    end

    index[npcId] = index[npcId] or {}
    local entry = BuildTooltipEntry(quest, dbQuest, cluster, npcId)
    local key = quest.id .. ":" .. tostring(
        Quests:GetClusterObjectiveIndex(cluster)
        or Quests:GetClusterKind(cluster)
        or Quests:GetClusterObjective(cluster)
        or entry.title
    )

    if not index[npcId][key] then
        index[npcId][key] = entry
    end
end

local function AddCluster(index, quest, dbQuest, cluster)
    if not cluster then
        return
    end
    if not Quests:ShouldShowObjectiveCluster(quest, cluster, "tooltip") then
        return
    end
    local kind = Quests:GetClusterKind(cluster)
    if kind and not TOOLTIP_CLUSTER_KINDS[kind] then
        return
    end

    local sourceType = Quests:GetClusterSourceType(cluster)
    local sourceId = Quests:GetClusterSourceId(cluster)
    if sourceType == "npc" and sourceId then
        AddEntry(index, quest, dbQuest, cluster, sourceId)
    end

    local tooltipNpcIds = Quests:GetClusterTooltipNpcIds(cluster)
    if tooltipNpcIds then
        for _, npcId in ipairs(tooltipNpcIds) do
            AddEntry(index, quest, dbQuest, cluster, npcId)
        end
    end
end

local function AddClusters(index, quest, dbQuest, maps)
    if not maps then
        return
    end

    for _, clusters in pairs(maps) do
        for _, cluster in ipairs(clusters) do
            AddCluster(index, quest, dbQuest, cluster)
        end
    end
end

function Quests:RebuildUnitTooltipIndex(quests)
    local index = {}

    if not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        self.unitTooltipIndex = index
        return
    end

    for _, quest in ipairs(quests or {}) do
        local dbQuest = VanillaEnhancedQuestsDB.quests[quest.id]
        if dbQuest then
            local maps = quest.isComplete and dbQuest.turnins or dbQuest.maps
            AddClusters(index, quest, dbQuest, maps or dbQuest.maps)
        end
    end

    self.unitTooltipIndex = index
end

local function FormatTooltipEntryTitle(entry, expanded)
    if expanded and entry.number then
        return entry.number .. ". " .. entry.title
    end
    return entry.title
end

local function FormatTooltipEntryDetail(entry, settings, expanded)
    local detail = entry.detail
    if not detail or detail == "" then
        return detail
    end
    if expanded or not settings or settings.alwaysShowTooltipDropRates ~= false then
        detail = detail .. GetDropRateText(entry.cluster, entry.npcId)
    end
    return detail
end

local function OnTooltipSetUnit(tooltip)
    local settings = Quests:GetSettings()
    if not settings.enabled or not Quests.unitTooltipIndex then
        return
    end
    if settings.showObjectiveTooltipHints == false then
        return
    end

    local _, unit = tooltip:GetUnit()
    local guid = unit and UnitGUID(unit) or UnitGUID("mouseover")
    local npcId = GetNpcIdFromGuid(guid)
    if not npcId then
        return
    end

    local entries = Quests.unitTooltipIndex[npcId]
    if not entries then
        return
    end

    local entriesToShow = {}
    local seen = {}
    for _, entry in pairs(entries) do
        local key = (entry.title or "") .. "\n" .. (entry.detail or "")
        if not seen[key] then
            seen[key] = true
            entriesToShow[#entriesToShow + 1] = entry
        end
    end

    if #entriesToShow == 0 then
        return
    end

    local expanded = IsTooltipDetailsExpanded()
    tooltip.VanillaEnhancedQuestUnit = unit or "mouseover"
    for _, entry in ipairs(entriesToShow) do
        tooltip:AddLine(" ")
        tooltip:AddLine(FormatTooltipEntryTitle(entry, expanded), 0.9, 0.82, 0.55, true)
        if expanded and entry.level then
            tooltip:AddLine(VanillaEnhanced:T("quests.static.questLevel", { level = entry.level }), 0.56, 0.64, 0.72, true)
        end
        local detail = FormatTooltipEntryDetail(entry, settings, expanded)
        if detail and detail ~= "" then
            tooltip:AddLine(detail, 0.8, 0.8, 0.8, true)
        end
    end
    tooltip:Show()
end

local function OnTooltipCleared(tooltip)
    if tooltip.VanillaEnhancedQuestRefreshing then
        return
    end
    tooltip.VanillaEnhancedQuestUnit = nil
end

local function RefreshUnitTooltip()
    local tooltip = GameTooltip
    if not tooltip or tooltip.VanillaEnhancedQuestRefreshing or not tooltip.VanillaEnhancedQuestUnit then
        return
    end
    if type(tooltip.IsShown) == "function" and not tooltip:IsShown() then
        return
    end
    if type(tooltip.SetUnit) ~= "function" or type(tooltip.ClearLines) ~= "function" then
        return
    end

    tooltip.VanillaEnhancedQuestRefreshing = true
    local unit = tooltip.VanillaEnhancedQuestUnit
    tooltip:ClearLines()
    pcall(tooltip.SetUnit, tooltip, unit)
    tooltip.VanillaEnhancedQuestRefreshing = nil
end

if GameTooltip and not Quests.unitTooltipHooked then
    GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
    GameTooltip:HookScript("OnHide", OnTooltipCleared)
    GameTooltip:HookScript("OnTooltipCleared", OnTooltipCleared)
    Quests.unitTooltipHooked = true
end

if VanillaEnhanced.RegisterTooltipDetailsRefresh then
    VanillaEnhanced:RegisterTooltipDetailsRefresh(RefreshUnitTooltip)
end
