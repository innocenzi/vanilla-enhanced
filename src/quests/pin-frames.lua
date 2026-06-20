local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local MARKER_FRAME_SIZE = 16
local MARKER_COLOR = { 1, 0.82, 0.15 }
local MARKER_FONT_SIZE = 9
local MARKER_ICON_SIZE = 12
local SELECTED_MARKER_HIGHLIGHT_SCALE = 1.9
local SELECTED_MARKER_HIGHLIGHT_COLOR = { 1, 0.82, 0.15, 0.85 }
local SELECTED_MARKER_HIGHLIGHT_TEXTURE = [[Interface\Buttons\UI-ActionButton-Border]]

Quests.frames = Quests.frames or {}
Quests.minimapFrames = Quests.minimapFrames or {}
Quests.pool = Quests.pool or {
    area = {},
    marker = {},
    minimapArea = {},
    minimapMarker = {},
}
Quests.pool.area = Quests.pool.area or {}
Quests.pool.marker = Quests.pool.marker or {}
Quests.pool.minimapArea = Quests.pool.minimapArea or {}
Quests.pool.minimapMarker = Quests.pool.minimapMarker or {}

local function ResetPinFrame(frame)
    frame.questsData = nil
    frame.questsAreaFrame = nil
    frame.questsAreaFrames = nil
    frame.questsHovered = nil
    frame.questsPassThroughClicks = nil
    frame.questsMinimapArea = nil
    frame.questsMinimapBasePoints = nil
    frame.questsMinimapAreaRadius = nil
    frame.questsMinimapClipRadius = nil
    frame.UiMapID = nil
    frame.x = nil
    frame.y = nil
    frame:SetAlpha(1)
    frame:EnableMouse(true)
    frame:SetScript("OnUpdate", nil)
    if frame.questsMarkerHighlight then
        frame.questsMarkerHighlight:Hide()
    end
    if frame.SetPropagateMouseClicks then
        frame:SetPropagateMouseClicks(false)
    end
end

local function ReleasePinFrame(self, frame)
    ResetPinFrame(frame)
    frame:Hide()
    self.pool[frame.poolKind][#self.pool[frame.poolKind] + 1] = frame
end

local function HideTextures(textures)
    if not textures then
        return
    end

    for _, texture in ipairs(textures) do
        texture:Hide()
    end
end

local function ConfigureMarkerFrame(frame, settings, resizeFrame)
    local size = math.max(12, math.floor(MARKER_FRAME_SIZE * (settings.scale or 1)))

    if resizeFrame then
        frame:SetSize(size, size)
    end
    frame.background:Hide()
    if frame.questsMarkerHighlight then
        frame.questsMarkerHighlight:SetSize(size * SELECTED_MARKER_HIGHLIGHT_SCALE, size * SELECTED_MARKER_HIGHLIGHT_SCALE)
        frame.questsMarkerHighlight:SetVertexColor(
            SELECTED_MARKER_HIGHLIGHT_COLOR[1],
            SELECTED_MARKER_HIGHLIGHT_COLOR[2],
            SELECTED_MARKER_HIGHLIGHT_COLOR[3],
            SELECTED_MARKER_HIGHLIGHT_COLOR[4] * (settings.opacity or 1)
        )
    end
end

local function ConfigureMarkerText(fontString, symbol, settings, opacityMultiplier, color)
    local opacity = (settings.opacity or 1) * (opacityMultiplier or 1)
    color = color or MARKER_COLOR

    fontString:Show()
    fontString:SetText(tostring(symbol))
    fontString:SetTextColor(color[1], color[2], color[3], opacity)
    fontString:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(MARKER_FONT_SIZE * (settings.scale or 1))), "OUTLINE")
    fontString:SetShadowColor(0, 0, 0, 0.9)
    fontString:SetShadowOffset(1, -1)
end

local function CreateMarkerHighlight(frame)
    local highlight = frame:CreateTexture(nil, "OVERLAY")
    highlight:SetTexture(SELECTED_MARKER_HIGHLIGHT_TEXTURE)
    highlight:SetPoint("CENTER", frame, "CENTER", 0, 0)
    highlight:SetVertexColor(
        SELECTED_MARKER_HIGHLIGHT_COLOR[1],
        SELECTED_MARKER_HIGHLIGHT_COLOR[2],
        SELECTED_MARKER_HIGHLIGHT_COLOR[3],
        SELECTED_MARKER_HIGHLIGHT_COLOR[4]
    )
    if highlight.SetBlendMode then
        highlight:SetBlendMode("ADD")
    end
    if highlight.SetDrawLayer then
        highlight:SetDrawLayer("OVERLAY", -1)
    end
    highlight:Hide()
    return highlight
end

local function EnsureMarkerHighlight(frame)
    if not frame.questsMarkerHighlight then
        frame.questsMarkerHighlight = CreateMarkerHighlight(frame)
    end
    return frame.questsMarkerHighlight
end

function Quests:AcquirePinFrame(kind, poolKind, parent)
    local frame = table.remove(self.pool[poolKind])
    if frame then
        frame.kind = kind
        frame.poolKind = poolKind
        ResetPinFrame(frame)
        frame:Show()
        return frame
    end

    frame = CreateFrame("Button", nil, parent)
    frame.kind = kind
    frame.poolKind = poolKind
    frame.background = frame:CreateTexture(nil, "ARTWORK")
    frame.background:Hide()
    frame.texture = frame:CreateTexture(nil, kind == "area" and "ARTWORK" or "OVERLAY")
    if kind == "marker" then
        frame.questsMarkerHighlight = CreateMarkerHighlight(frame)
    end
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame:SetScript("OnEnter", function(self)
        Quests:ShowPinTooltip(self)
    end)
    frame:SetScript("OnLeave", function(self)
        Quests:HidePinTooltip(self)
    end)
    frame:SetScript("OnClick", function(self)
        Quests:OpenPinQuestLog(self)
    end)
    frame:RegisterForClicks("LeftButtonUp")
    frame:EnableMouse(true)
    return frame
end

function Quests:TrackWorldMapPinFrame(frame)
    self.frames[#self.frames + 1] = frame
end

function Quests:TrackMinimapPinFrame(frame)
    self.minimapFrames[#self.minimapFrames + 1] = frame
end

function Quests:ConfigurePinSymbol(frame, symbol, opacityMultiplier, color)
    local settings = self:GetSettings()

    ConfigureMarkerFrame(frame, settings, true)
    frame.texture:Hide()
    HideTextures(frame.lines)
    HideTextures(frame.fills)
    ConfigureMarkerText(frame.text, symbol, settings, opacityMultiplier, color)
end

function Quests:ConfigurePinIcon(frame, texture)
    local settings = self:GetSettings()
    local size = math.max(10, math.floor(MARKER_ICON_SIZE * (settings.scale or 1)))

    ConfigureMarkerFrame(frame, settings, true)
    HideTextures(frame.lines)
    HideTextures(frame.fills)
    frame.text:SetText("")
    frame.texture:Show()
    frame.texture:SetTexture(texture)
    frame.texture:ClearAllPoints()
    frame.texture:SetSize(size, size)
    frame.texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.texture:SetVertexColor(1, 1, 1, settings.opacity or 1)
end

function Quests:SetPinMarkerHighlighted(frame, highlighted)
    if not frame or frame.kind ~= "marker" then
        return
    end

    local highlight = EnsureMarkerHighlight(frame)
    if highlighted then
        highlight:Show()
    else
        highlight:Hide()
    end
end

function Quests:ClearPins()
    if self.hbdPins then
        for _, frame in ipairs(self.frames) do
            self.hbdPins:RemoveWorldMapIcon(self, frame)
            ReleasePinFrame(self, frame)
        end
        for _, frame in ipairs(self.minimapFrames) do
            self.hbdPins:RemoveMinimapIcon(self, frame)
            ReleasePinFrame(self, frame)
        end
    end
    wipe(self.frames)
    wipe(self.minimapFrames)
    self.markerCandidates = {}
end
