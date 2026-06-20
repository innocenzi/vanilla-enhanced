local Quests = _G.VanillaEnhanced:GetModule("quests")

local MARKER_SYMBOLS = {
    available = "!",
    turnin = "?",
}

local MARKER_TEXTURES = {
    talk = [[Interface\GossipFrame\GossipGossipIcon]],
}

local AREA_KINDS = {
    loot = true,
    slay = true,
}

function Quests:GetPinMarkerSymbol(kind, fallback)
    return MARKER_SYMBOLS[kind] or fallback
end

function Quests:GetPinMarkerTexture(kind)
    return MARKER_TEXTURES[kind]
end

function Quests:IsQuestObjectiveAreaKind(kind)
    return AREA_KINDS[kind] == true
end
