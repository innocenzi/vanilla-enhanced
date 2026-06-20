local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local MARKER_FRAME_SIZE = 16
local MARKER_COLOR = { 1, 0.82, 0.15 }
local MARKER_FONT_SIZE = 9
local MARKER_ICON_SIZE = 12
local MARKER_SHADOW_COLOR = { 0, 0, 0, 0.9 }
local SELECTED_MARKER_COLOR = { 1, 1, 1 }
local WORLD_MAP_MARKER_FRAME_LEVEL_OFFSET = 100
local MINIMAP_MARKER_FRAME_LEVEL_OFFSET = 80

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
    frame.questsMarkerStyle = nil
    frame.UiMapID = nil
    frame.x = nil
    frame.y = nil
    frame:SetAlpha(1)
    frame:EnableMouse(true)
    frame:SetScript("OnUpdate", nil)
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

local function IsWorldMapMarkerFrame(frame)
    return frame and frame.poolKind == "marker"
end

local function SafeFrameCall(method, owner, ...)
    if method and owner then
        pcall(method, owner, ...)
    end
end

local function ConfigureMarkerFrame(frame, settings, resizeFrame)
    local size = math.max(12, math.floor(MARKER_FRAME_SIZE * (settings.scale or 1)))

    if resizeFrame then
        frame:SetSize(size, size)
    end
    frame.background:Hide()
end

local function ConfigureMarkerText(frame, symbol, settings, opacityMultiplier, color)
    local opacity = (settings.opacity or 1) * (opacityMultiplier or 1)
    color = color or MARKER_COLOR

    frame.questsMarkerStyle = {
        kind = "symbol",
        color = color,
        opacity = opacity,
    }
    frame.text:Show()
    frame.text:SetText(tostring(symbol))
    frame.text:SetTextColor(color[1], color[2], color[3], opacity)
    frame.text:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(MARKER_FONT_SIZE * (settings.scale or 1))), "OUTLINE")
    frame.text:SetShadowColor(MARKER_SHADOW_COLOR[1], MARKER_SHADOW_COLOR[2], MARKER_SHADOW_COLOR[3], MARKER_SHADOW_COLOR[4])
    frame.text:SetShadowOffset(1, -1)
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
    frame:SetScript("OnShow", function(self)
        if IsWorldMapMarkerFrame(self) then
            Quests:RaiseWorldMapMarkerFrame(self)
        end
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

function Quests:RaiseWorldMapMarkerFrame(frame)
    if not IsWorldMapMarkerFrame(frame) then
        return
    end

    local pin = frame.GetParent and frame:GetParent()
    if not pin or pin == UIParent or pin == WorldMapFrame then
        return
    end

    if pin.SetFrameStrata then
        SafeFrameCall(pin.SetFrameStrata, pin, "HIGH")
    end
    if frame.SetFrameStrata then
        SafeFrameCall(frame.SetFrameStrata, frame, "HIGH")
    end
    if pin.SetFrameLevel and pin.GetFrameLevel then
        local pinLevel = (pin:GetFrameLevel() or 0) + WORLD_MAP_MARKER_FRAME_LEVEL_OFFSET

        SafeFrameCall(pin.SetFrameLevel, pin, pinLevel)
        if frame.SetFrameLevel then
            SafeFrameCall(frame.SetFrameLevel, frame, pinLevel + 1)
        end
    end
end

function Quests:RaiseMinimapMarkerFrame(frame)
    if not frame then
        return
    end

    if frame.SetFrameStrata then
        SafeFrameCall(frame.SetFrameStrata, frame, "HIGH")
    end
    if frame.SetFrameLevel then
        local baseLevel = 0

        if Minimap and Minimap.GetFrameLevel then
            baseLevel = Minimap:GetFrameLevel() or 0
        end
        SafeFrameCall(frame.SetFrameLevel, frame, baseLevel + MINIMAP_MARKER_FRAME_LEVEL_OFFSET)
    end
end

function Quests:ConfigurePinSymbol(frame, symbol, opacityMultiplier, color)
    local settings = self:GetSettings()

    ConfigureMarkerFrame(frame, settings, true)
    frame.texture:Hide()
    HideTextures(frame.lines)
    HideTextures(frame.fills)
    ConfigureMarkerText(frame, symbol, settings, opacityMultiplier, color)
end

function Quests:ConfigurePinIcon(frame, texture, opacityMultiplier, color)
    local settings = self:GetSettings()
    local size = math.max(10, math.floor(MARKER_ICON_SIZE * (settings.scale or 1)))
    local opacity = (settings.opacity or 1) * (opacityMultiplier or 1)
    color = color or { 1, 1, 1 }

    ConfigureMarkerFrame(frame, settings, true)
    HideTextures(frame.lines)
    HideTextures(frame.fills)
    frame.questsMarkerStyle = {
        kind = "icon",
        color = color,
        opacity = opacity,
    }
    frame.text:SetText("")
    frame.texture:Show()
    frame.texture:SetTexture(texture)
    frame.texture:ClearAllPoints()
    frame.texture:SetSize(size, size)
    frame.texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.texture:SetVertexColor(color[1], color[2], color[3], opacity)
end

function Quests:SetPinMarkerHighlighted(frame, highlighted)
    if not frame or frame.kind ~= "marker" then
        return
    end

    local style = frame.questsMarkerStyle
    if not style then
        return
    end

    if highlighted then
        if style.kind == "symbol" then
            frame.text:SetTextColor(SELECTED_MARKER_COLOR[1], SELECTED_MARKER_COLOR[2], SELECTED_MARKER_COLOR[3], style.opacity or 1)
        elseif style.kind == "icon" then
            frame.texture:SetVertexColor(
                SELECTED_MARKER_COLOR[1],
                SELECTED_MARKER_COLOR[2],
                SELECTED_MARKER_COLOR[3],
                style.opacity or 1
            )
        end
        return
    end

    if style.kind == "symbol" then
        frame.text:SetTextColor(style.color[1], style.color[2], style.color[3], style.opacity or 1)
    elseif style.kind == "icon" then
        frame.texture:SetVertexColor(style.color[1], style.color[2], style.color[3], style.opacity or 1)
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
