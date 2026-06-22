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

local function GetDropRateText(cluster, npcId, settings)
    if settings and settings.showTooltipDropRates == false then
        return ""
    end
    if cluster.k ~= "loot" or not cluster.dr or not npcId then
        return ""
    end

    for _, entry in ipairs(cluster.dr) do
        if entry[1] == npcId then
            local rate = FormatDropText(entry[2])
            if rate then
                return " |cFF999999[" .. rate .. "%]|r"
            end
        end
    end
    return ""
end

local function BuildTooltipEntry(quest, dbQuest, cluster, npcId, settings)
    local title = Quests:GetLocalizedQuestTitle(quest, quest.id, dbQuest and dbQuest.t or quest.title)
    local objectives = Quests:GetLocalizedObjectives(quest, cluster)
    local objective = objectives and objectives[1]

    if cluster.k == "slay" or cluster.k == "loot" then
        local sourceName = Quests:GetLocalizedSourceName(cluster)
        local progress = GetProgressText(objective)
        local dropRateText = GetDropRateText(cluster, npcId, settings)
        local detail

        if progress and sourceName and sourceName ~= "" then
            detail = "- " .. progress .. " " .. sourceName .. dropRateText
        elseif objective and objective ~= "" then
            detail = "- " .. objective .. dropRateText
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

local function AddEntry(index, quest, dbQuest, cluster, npcId, settings)
    if not npcId then
        return
    end

    index[npcId] = index[npcId] or {}
    local entry = BuildTooltipEntry(quest, dbQuest, cluster, npcId, settings)
    local key = quest.id .. ":" .. tostring(cluster.oi or cluster.k or cluster.o or entry.title)

    if not index[npcId][key] then
        index[npcId][key] = entry
    end
end

local function AddCluster(index, quest, dbQuest, cluster, settings)
    if not cluster then
        return
    end
    if not Quests:ShouldShowObjectiveCluster(quest, cluster, "tooltip") then
        return
    end
    if cluster.k and not TOOLTIP_CLUSTER_KINDS[cluster.k] then
        return
    end

    if cluster.st == "npc" and cluster.sid then
        AddEntry(index, quest, dbQuest, cluster, cluster.sid, settings)
    end

    if cluster.n then
        for _, npcId in ipairs(cluster.n) do
            AddEntry(index, quest, dbQuest, cluster, npcId, settings)
        end
    end
end

local function AddClusters(index, quest, dbQuest, maps, settings)
    if not maps then
        return
    end

    for _, clusters in pairs(maps) do
        for _, cluster in ipairs(clusters) do
            AddCluster(index, quest, dbQuest, cluster, settings)
        end
    end
end

function Quests:RebuildUnitTooltipIndex(quests)
    local index = {}

    if not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        self.unitTooltipIndex = index
        return
    end

    local settings = self:GetSettings()
    for _, quest in ipairs(quests or {}) do
        local dbQuest = VanillaEnhancedQuestsDB.quests[quest.id]
        if dbQuest then
            local maps = quest.isComplete and dbQuest.turnins or dbQuest.maps
            AddClusters(index, quest, dbQuest, maps or dbQuest.maps, settings)
        end
    end

    self.unitTooltipIndex = index
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

    for _, entry in ipairs(entriesToShow) do
        tooltip:AddLine(" ")
        tooltip:AddLine(entry.title, 0.9, 0.82, 0.55, true)
        if entry.detail and entry.detail ~= "" then
            tooltip:AddLine(entry.detail, 0.8, 0.8, 0.8, true)
        end
    end
    tooltip:Show()
end

if GameTooltip and not Quests.unitTooltipHooked then
    GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
    Quests.unitTooltipHooked = true
end
