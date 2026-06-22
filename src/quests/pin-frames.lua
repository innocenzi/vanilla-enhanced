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
local OTHER_FLOOR_MINIMAP_ALPHA = 0.35

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

local function IsInCombatLockdown()
    return InCombatLockdown and InCombatLockdown()
end

function Quests:SetPinFramePropagateMouseClicks(frame, propagate)
    if not frame then
        return false
    end

    local shouldPropagate = propagate == true

    if frame.SetPropagateMouseClicks then
        frame:EnableMouse(true)
        if frame.questsPropagateMouseClicks == shouldPropagate then
            return true
        end
        if IsInCombatLockdown() then
            return false
        end

        frame:SetPropagateMouseClicks(shouldPropagate)
        frame.questsPropagateMouseClicks = shouldPropagate
        return true
    end

    frame:EnableMouse(not shouldPropagate)
    frame.questsPropagateMouseClicks = shouldPropagate
    return true
end

local function ResetPinFrame(frame)
    frame.questsData = nil
    frame.questsAreaFrame = nil
    frame.questsAreaFrames = nil
    frame.questsAreaCluster = nil
    frame.questsAreaPreparedKey = nil
    frame.questsHovered = nil
    frame.questsPassThroughClicks = nil
    frame.questsMinimapArea = nil
    frame.questsMinimapBasePoints = nil
    frame.questsMinimapAreaRadius = nil
    frame.questsMinimapClipRadius = nil
    frame.questsMinimapUiMapId = nil
    frame.questsMarkerStyle = nil
    frame.UiMapID = nil
    frame.x = nil
    frame.y = nil
    frame:SetAlpha(1)
    frame:EnableMouse(true)
    frame:SetScript("OnUpdate", nil)
    Quests:SetPinFramePropagateMouseClicks(frame, false)
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

local function GetMapData(mapId)
    return Quests.hbd and Quests.hbd.mapData and Quests.hbd.mapData[mapId] or nil
end

local function GetMapType(mapId)
    local data = GetMapData(mapId)
    return data and data.mapType or nil
end

local function IsFloorMapType(mapType)
    if not Enum or not Enum.UIMapType then
        return false
    end
    return mapType == Enum.UIMapType.Dungeon or mapType == Enum.UIMapType.Micro
end

local function IsDescendantMap(childMapId, ancestorMapId)
    if not childMapId or not ancestorMapId or childMapId == ancestorMapId then
        return false
    end

    local data = GetMapData(childMapId)
    local parentMapId = data and data.parent or nil
    while parentMapId and GetMapData(parentMapId) do
        if parentMapId == ancestorMapId then
            return true
        end
        parentMapId = GetMapData(parentMapId).parent
    end
    return false
end

local function GetMapGroupId(mapId)
    if not mapId or not C_Map or not C_Map.GetMapGroupID then
        return nil
    end

    local ok, groupId = pcall(C_Map.GetMapGroupID, mapId)
    if ok then
        return groupId
    end
    return nil
end

local function AreDifferentFloorMaps(sourceMapId, playerMapId)
    if not sourceMapId or not playerMapId or sourceMapId == playerMapId then
        return false
    end

    local sourceGroupId = GetMapGroupId(sourceMapId)
    local playerGroupId = GetMapGroupId(playerMapId)
    if sourceGroupId
        and playerGroupId
        and sourceGroupId == playerGroupId
        and (IsFloorMapType(GetMapType(sourceMapId)) or IsFloorMapType(GetMapType(playerMapId))) then
        return true
    end

    if IsDescendantMap(sourceMapId, playerMapId) then
        return IsFloorMapType(GetMapType(sourceMapId))
    end
    if IsDescendantMap(playerMapId, sourceMapId) then
        return IsFloorMapType(GetMapType(playerMapId))
    end
    return false
end

function Quests:IsMinimapPinOnOtherFloor(frame, playerMapId)
    local sourceMapId = frame and frame.questsMinimapUiMapId
    if not sourceMapId then
        return false
    end
    if not playerMapId and self.hbd and self.hbd.GetPlayerZone then
        playerMapId = self.hbd:GetPlayerZone()
    end
    return AreDifferentFloorMaps(sourceMapId, playerMapId)
end

function Quests:ApplyMinimapFloorDimming(frame, playerMapId)
    if not frame then
        return
    end

    local settings = self:GetSettings()
    if settings.dimMinimapMarkersOnOtherFloors == false then
        frame:SetAlpha(1)
        return
    end

    frame:SetAlpha(self:IsMinimapPinOnOtherFloor(frame, playerMapId) and OTHER_FLOOR_MINIMAP_ALPHA or 1)
end

function Quests:RefreshMinimapFloorDimming()
    local playerMapId
    if self.hbd and self.hbd.GetPlayerZone then
        playerMapId = self.hbd:GetPlayerZone()
    end

    for _, frame in ipairs(self.minimapFrames or {}) do
        self:ApplyMinimapFloorDimming(frame, playerMapId)
    end
end

function Quests:RegisterMinimapFloorDimmingCallbacks()
    if self.minimapFloorDimmingCallbacksRegistered or not self.hbd or not self.hbd.RegisterCallback then
        return
    end

    local ok = pcall(self.hbd.RegisterCallback, self, "PlayerZoneChanged", "RefreshMinimapFloorDimming")
    if ok then
        self.minimapFloorDimmingCallbacksRegistered = true
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
    frame.questsPropagateMouseClicks = false
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
    if IsInCombatLockdown() then
        self.refreshAfterCombat = true
        return
    end

    self:ClearWorldMapPins()
    self:ClearMinimapPins()
end

function Quests:ClearWorldMapPins()
    if IsInCombatLockdown() then
        if not self.refreshAfterCombat then
            self.refreshWorldMapAfterCombat = true
        end
        return
    end

    if self.hbdPins then
        if self.hbdPins.RemoveAllWorldMapIcons then
            self.hbdPins:RemoveAllWorldMapIcons(self)
        end
        for _, frame in ipairs(self.frames) do
            if not self.hbdPins.RemoveAllWorldMapIcons then
                self.hbdPins:RemoveWorldMapIcon(self, frame)
            end
            ReleasePinFrame(self, frame)
        end
    end
    wipe(self.frames)
    self.markerCandidates = {}
end

function Quests:ClearMinimapPins()
    if IsInCombatLockdown() then
        self.refreshAfterCombat = true
        return
    end

    if self.hbdPins then
        if self.hbdPins.RemoveAllMinimapIcons then
            self.hbdPins:RemoveAllMinimapIcons(self)
        end
        for _, frame in ipairs(self.minimapFrames) do
            if not self.hbdPins.RemoveAllMinimapIcons then
                self.hbdPins:RemoveMinimapIcon(self, frame)
            end
            ReleasePinFrame(self, frame)
        end
    end
    wipe(self.minimapFrames)
end
