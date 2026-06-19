local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:GetModule("quest-map")

QuestMap.unitTooltipIndex = QuestMap.unitTooltipIndex or {}

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

local function BuildTooltipEntry(quest, dbQuest, cluster)
    local title = QuestMap:GetLocalizedQuestTitle(quest, quest.id, dbQuest and dbQuest.t or quest.title)
    local objectives = QuestMap:GetLocalizedObjectives(quest, cluster)
    local objective = objectives and objectives[1]

    if cluster.k == "slay" or cluster.k == "loot" then
        local sourceName = QuestMap:GetLocalizedSourceName(cluster)
        local progress = GetProgressText(objective)
        local detail

        if progress and sourceName and sourceName ~= "" then
            detail = "- " .. progress .. " " .. sourceName
        elseif objective and objective ~= "" then
            detail = "- " .. objective
        end

        return {
            title = title,
            detail = detail,
        }
    end

    if objective and objective ~= "" then
        return {
            title = quest.number .. ". " .. title .. ": " .. objective,
        }
    end
    return {
        title = quest.number .. ". " .. title,
    }
end

local function AddEntry(index, quest, dbQuest, cluster, npcId)
    if not npcId then
        return
    end

    index[npcId] = index[npcId] or {}
    local entry = BuildTooltipEntry(quest, dbQuest, cluster)
    local key = quest.id .. ":" .. tostring(cluster.oi or cluster.k or cluster.o or entry.title)

    if not index[npcId][key] then
        index[npcId][key] = entry
    end
end

local function AddCluster(index, quest, dbQuest, cluster)
    if not cluster then
        return
    end
    if not QuestMap:ShouldShowObjectiveCluster(quest, cluster, "tooltip") then
        return
    end
    if cluster.k and not TOOLTIP_CLUSTER_KINDS[cluster.k] then
        return
    end

    if cluster.st == "npc" and cluster.sid then
        AddEntry(index, quest, dbQuest, cluster, cluster.sid)
    end

    if cluster.n then
        for _, npcId in ipairs(cluster.n) do
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

function QuestMap:RebuildUnitTooltipIndex(quests)
    local index = {}

    if not VanillaEnhancedQuestMapDB or not VanillaEnhancedQuestMapDB.quests then
        self.unitTooltipIndex = index
        return
    end

    for _, quest in ipairs(quests or {}) do
        local dbQuest = VanillaEnhancedQuestMapDB.quests[quest.id]
        if dbQuest then
            local maps = quest.isComplete and dbQuest.turnins or dbQuest.maps
            AddClusters(index, quest, dbQuest, maps or dbQuest.maps)
        end
    end

    self.unitTooltipIndex = index
end

local function OnTooltipSetUnit(tooltip)
    local settings = QuestMap:GetSettings()
    if not settings.enabled or not QuestMap.unitTooltipIndex then
        return
    end

    local _, unit = tooltip:GetUnit()
    local guid = unit and UnitGUID(unit) or UnitGUID("mouseover")
    local npcId = GetNpcIdFromGuid(guid)
    if not npcId then
        return
    end

    local entries = QuestMap.unitTooltipIndex[npcId]
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

    for _, entry in ipairs(entriesToShow) do
        tooltip:AddLine(" ")
        tooltip:AddLine(entry.title, 0.9, 0.82, 0.55, true)
        if entry.detail and entry.detail ~= "" then
            tooltip:AddLine(entry.detail, 0.8, 0.8, 0.8, true)
        end
    end
    tooltip:Show()
end

if GameTooltip and not QuestMap.unitTooltipHooked then
    GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
    QuestMap.unitTooltipHooked = true
end
