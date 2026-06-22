local VanillaEnhanced = _G.VanillaEnhanced
local Map = VanillaEnhanced:GetModule("map")

local MARKER_SYMBOL = "•"
local MARKER_SIZE_WORLD = 14
local MARKER_SIZE_MINIMAP = 12
local MARKER_COLOR = { 1, 0.82, 0.18, 1 }
local MARKER_SHADOW_COLOR = { 0, 0, 0, 0.95 }
local TOOLTIP_METADATA_COLOR = { 0.56, 0.56, 0.56 }
local COORDINATE_PRECISION = 100000
local MINIMAP_UPDATE_INTERVAL = 0.05
local MINIMAP_EDGE_RADIUS_MULTIPLIER = 0.86
local MINIMAP_SIZE = {
    indoor = {
        [0] = 300,
        [1] = 240,
        [2] = 180,
        [3] = 120,
        [4] = 80,
        [5] = 50,
    },
    outdoor = {
        [0] = 466 + 2 / 3,
        [1] = 400,
        [2] = 333 + 1 / 3,
        [3] = 266 + 2 / 6,
        [4] = 200,
        [5] = 133 + 1 / 3,
    },
}

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function RoundCoordinate(value)
    value = tonumber(value) or 0
    return math.floor((value * COORDINATE_PRECISION) + 0.5) / COORDINATE_PRECISION
end

local function GetCurrentMapId()
    if WorldMapFrame then
        if WorldMapFrame.GetMapID then
            return WorldMapFrame:GetMapID()
        end
        if WorldMapFrame.mapID then
            return WorldMapFrame.mapID
        end
    end
    return nil
end

local function GetMapContentFrame()
    if WorldMapFrame then
        if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
            return WorldMapFrame.ScrollContainer.Child
        end
        if WorldMapDetailFrame then
            return WorldMapDetailFrame
        end
    end
    return WorldMapFrame
end

local function GetFrameCursorPosition(frame)
    if not frame or not frame.GetLeft or not frame.GetTop or not frame.GetWidth or not frame.GetHeight then
        return nil, nil
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or frame:GetScale() or 1
    local left = (frame:GetLeft() or 0) * scale
    local top = (frame:GetTop() or 0) * scale
    local width = (frame:GetWidth() or 0) * scale
    local height = (frame:GetHeight() or 0) * scale

    if width <= 0 or height <= 0 then
        return nil, nil
    end

    local x = (cursorX - left) / width
    local y = (top - cursorY) / height
    if x < 0 or x > 1 or y < 0 or y > 1 then
        return nil, nil
    end

    return x, y
end

local function IsCursorOverFrame(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end
    if not frame.GetLeft or not frame.GetRight or not frame.GetTop or not frame.GetBottom then
        return false
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or frame:GetScale() or 1
    local left = (frame:GetLeft() or 0) * scale
    local right = (frame:GetRight() or 0) * scale
    local top = (frame:GetTop() or 0) * scale
    local bottom = (frame:GetBottom() or 0) * scale

    return cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top
end

local function FindWorldMapMarkerFrameUnderCursor(frames)
    for _, frame in ipairs(frames or {}) do
        if frame.markerId and IsCursorOverFrame(frame) then
            return frame
        end
    end
    return nil
end

local function GetMapName(uiMapId)
    if Map.hbd and Map.hbd.GetLocalizedMap then
        local name = Map.hbd:GetLocalizedMap(uiMapId)
        if name and name ~= "" then
            return name
        end
    end
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, uiMapId)
        if ok and info and info.name then
            return info.name
        end
    end
    return T("map.marker.unknownMap")
end

local function FormatDistance(distance)
    if not distance then
        return nil
    end
    if distance >= 1000 then
        return T("map.marker.tooltipDistanceYards", {
            distance = math.floor((distance / 10) + 0.5) * 10,
        })
    end
    return T("map.marker.tooltipDistanceYards", {
        distance = math.floor(distance + 0.5),
    })
end

local function FormatCoordinates(marker, distance)
    local coordinateVars = {
        x = math.floor(((marker.x or 0) * 1000) + 0.5) / 10,
        y = math.floor(((marker.y or 0) * 1000) + 0.5) / 10,
    }
    local distanceText = FormatDistance(distance)
    if distanceText then
        coordinateVars.distance = distanceText
        return T("map.marker.tooltipCoordinatesWithDistance", coordinateVars)
    end
    return T("map.marker.tooltipCoordinates", coordinateVars)
end

local function IsAltLeftClick(button)
    return button == "LeftButton" and IsAltKeyDown and IsAltKeyDown()
end

local function GetMinimapEdgeRadius()
    if not Minimap or not Minimap.GetWidth or not Minimap.GetHeight then
        return 60
    end
    return math.min(Minimap:GetWidth() or 140, Minimap:GetHeight() or 140) * 0.5 * MINIMAP_EDGE_RADIUS_MULTIPLIER
end

local function GetMinimapWorldRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local radius = C_Minimap.GetViewRadius()
        if radius and radius > 0 then
            return radius
        end
    end
    if not Minimap or not Minimap.GetZoom or not GetCVar then
        return 100
    end

    local zoom = Minimap:GetZoom() or 0
    local indoors = GetCVar("minimapZoom") == GetCVar("minimapInsideZoom")
        and "outdoor"
        or ((tonumber(GetCVar("minimapZoom")) or 0) == zoom and "outdoor" or "indoor")
    local size = MINIMAP_SIZE[indoors] and MINIMAP_SIZE[indoors][zoom] or nil

    return (size or 200) / 2
end

local function ResetMarkerFrame(frame)
    frame.markerId = nil
    frame.markerData = nil
    frame.markerKind = nil
    frame.markerWorldX = nil
    frame.markerWorldY = nil
    frame.markerInstanceId = nil
    frame:SetAlpha(1)
    frame:SetScript("OnUpdate", nil)
end

local function EnsureMarkerTextures(frame)
    if not frame.outline then
        frame.outline = frame:CreateTexture(nil, "ARTWORK")
    end
    if not frame.texture then
        frame.texture = frame:CreateTexture(nil, "OVERLAY")
    end
    if not frame.center then
        frame.center = frame:CreateTexture(nil, "OVERLAY")
    end
    if not frame.text then
        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end
end

local function ConfigureMarkerFrame(frame, kind)
    local size = kind == "minimap" and MARKER_SIZE_MINIMAP or MARKER_SIZE_WORLD

    EnsureMarkerTextures(frame)
    frame.markerKind = kind
    frame:SetSize(size, size)
    frame.outline:Hide()
    frame.texture:Hide()
    frame.center:Hide()
    frame.text:SetText(MARKER_SYMBOL)
    frame.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    frame.text:SetTextColor(MARKER_COLOR[1], MARKER_COLOR[2], MARKER_COLOR[3], MARKER_COLOR[4])
    frame.text:SetShadowColor(MARKER_SHADOW_COLOR[1], MARKER_SHADOW_COLOR[2], MARKER_SHADOW_COLOR[3], MARKER_SHADOW_COLOR[4])
    frame.text:SetShadowOffset(1, -1)
    frame.text:Show()
    frame:EnableMouse(true)
    if frame.SetPropagateMouseClicks then
        frame:SetPropagateMouseClicks(true)
    end
    if frame.SetFrameStrata then
        frame:SetFrameStrata("HIGH")
    end
end

local function SetFramePropagateMouseClicks(frame, propagate)
    if frame and frame.SetPropagateMouseClicks then
        frame:SetPropagateMouseClicks(propagate == true)
    end
end

function Map:AcquireMarkerFrame(kind, parent)
    local poolKey = kind == "minimap" and "minimap" or "worldMap"
    local frame = table.remove(self.pool[poolKey])
    if frame then
        ResetMarkerFrame(frame)
        frame:SetParent(parent)
        ConfigureMarkerFrame(frame, kind)
        frame:Show()
        return frame
    end

    frame = CreateFrame("Button", nil, parent)
    EnsureMarkerTextures(frame)
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnEnter", function(self)
        Map:ShowMarkerTooltip(self)
    end)
    frame:SetScript("OnLeave", function(self)
        Map:HideMarkerTooltip(self)
    end)
    frame:SetScript("OnClick", function(self, button)
        Map:HandleMarkerClick(self, button)
    end)
    ConfigureMarkerFrame(frame, kind)
    return frame
end

function Map:ReleaseMarkerFrame(frame)
    if not frame then
        return
    end

    local poolKey = frame.markerKind == "minimap" and "minimap" or "worldMap"
    ResetMarkerFrame(frame)
    frame:Hide()
    self.pool[poolKey][#self.pool[poolKey] + 1] = frame
end

function Map:GetMarkerStore()
    local settings = self:GetSettings()
    if type(settings.markers) ~= "table" then
        settings.markers = {}
    end
    return settings.markers
end

function Map:GetNextMarkerId()
    local settings = self:GetSettings()
    local markerId = settings.nextMarkerId

    settings.nextMarkerId = markerId + 1
    return markerId
end

function Map:CanPlaceMarker(uiMapId, x, y)
    if not self.hbd or not self.hbd.GetWorldCoordinatesFromZone then
        return false
    end

    local worldX, worldY = self.hbd:GetWorldCoordinatesFromZone(x, y, uiMapId)
    return worldX ~= nil and worldY ~= nil
end

function Map:AddMarker(uiMapId, x, y)
    if not self:IsEnabled() then
        return nil
    end
    if type(uiMapId) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    x = RoundCoordinate(x)
    y = RoundCoordinate(y)
    if x < 0 or x > 1 or y < 0 or y > 1 or not self:CanPlaceMarker(uiMapId, x, y) then
        VanillaEnhanced:PrintMessage(T("map.marker.unsupportedMap"))
        return nil
    end

    local marker = {
        id = self:GetNextMarkerId(),
        uiMapId = uiMapId,
        x = x,
        y = y,
    }
    local markers = self:GetMarkerStore()

    markers[#markers + 1] = marker
    VanillaEnhanced:PrintMessage(T("map.marker.added", {
        map = GetMapName(uiMapId),
        x = math.floor((x * 100) + 0.5),
        y = math.floor((y * 100) + 0.5),
    }))
    self:Refresh()
    return marker
end

function Map:RemoveMarker(markerId)
    local markers = self:GetMarkerStore()

    for index = #markers, 1, -1 do
        if markers[index].id == markerId then
            table.remove(markers, index)
            VanillaEnhanced:PrintMessage(T("map.marker.removed"))
            self:Refresh()
            return true
        end
    end
    return false
end

function Map:ClearMarkers()
    local settings = self:GetSettings()

    settings.markers = {}
    settings.nextMarkerId = 1
    VanillaEnhanced:PrintMessage(T("map.marker.cleared"))
    self:Refresh()
end

function Map:ConfirmClearMarkers()
    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs.VANILLAENHANCED_CLEAR_MAP_MARKERS = StaticPopupDialogs.VANILLAENHANCED_CLEAR_MAP_MARKERS or {
            text = T("map.marker.clearConfirm"),
            button1 = T("map.marker.clearAccept"),
            button2 = CANCEL or T("map.marker.clearCancel"),
            OnAccept = function()
                Map:ClearMarkers()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopupDialogs.VANILLAENHANCED_CLEAR_MAP_MARKERS.text = T("map.marker.clearConfirm")
        StaticPopupDialogs.VANILLAENHANCED_CLEAR_MAP_MARKERS.button1 = T("map.marker.clearAccept")
        StaticPopupDialogs.VANILLAENHANCED_CLEAR_MAP_MARKERS.button2 = CANCEL or T("map.marker.clearCancel")
        StaticPopup_Show("VANILLAENHANCED_CLEAR_MAP_MARKERS")
        return
    end

    self:ClearMarkers()
end

function Map:ShowMarkerTooltip(frame)
    local marker = frame and frame.markerData
    if not marker or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("map.marker.tooltipTitle"), 1, 1, 1)
    GameTooltip:AddLine(GetMapName(marker.uiMapId), TOOLTIP_METADATA_COLOR[1], TOOLTIP_METADATA_COLOR[2], TOOLTIP_METADATA_COLOR[3], true)
    local distance = self.GetMarkerDistanceToPlayer and self:GetMarkerDistanceToPlayer(marker) or nil
    GameTooltip:AddLine(FormatCoordinates(marker, distance), 0.9, 0.82, 0.55)
    GameTooltip:Show()
end

function Map:GetMarkerDistanceToPlayer(marker)
    if not marker or not self.hbd or not self.hbd.GetPlayerWorldPosition or not self.hbd.GetWorldCoordinatesFromZone then
        return nil
    end

    local markerX, markerY, markerInstanceId = self.hbd:GetWorldCoordinatesFromZone(marker.x, marker.y, marker.uiMapId)
    local playerX, playerY, playerInstanceId = self.hbd:GetPlayerWorldPosition()
    if not markerX or not markerY or not playerX or not playerY or markerInstanceId ~= playerInstanceId then
        return nil
    end

    local distance = self.hbd:GetWorldDistance(playerInstanceId, playerX, playerY, markerX, markerY)
    return distance
end

function Map:HideMarkerTooltip(frame)
    if GameTooltip and GameTooltip:IsOwned(frame) then
        GameTooltip:Hide()
    end
end

function Map:HandleMarkerClick(frame, button)
    if not IsAltLeftClick(button) or not frame or not frame.markerId then
        return
    end

    self.suppressPlacementUntil = (GetTime and GetTime() or 0) + 0.15
    self:HideMarkerTooltip(frame)
    self:RemoveMarker(frame.markerId)
end

function Map:RemoveMarkerUnderCursor()
    local frame = FindWorldMapMarkerFrameUnderCursor(self.worldMapFrames)
    if frame then
        self:HideMarkerTooltip(frame)
        self.overlayTooltipFrame = nil
        self.suppressPlacementUntil = (GetTime and GetTime() or 0) + 0.15
        self:RemoveMarker(frame.markerId)
        return true
    end
    return false
end

function Map:ClearWorldMapMarkers()
    if self.HidePlacementOverlayTooltip then
        self:HidePlacementOverlayTooltip()
    end
    if self.hbdPins and self.hbdPins.RemoveAllWorldMapIcons then
        self.hbdPins:RemoveAllWorldMapIcons(self)
    end
    for _, frame in ipairs(self.worldMapFrames or {}) do
        if self.hbdPins and not self.hbdPins.RemoveAllWorldMapIcons then
            self.hbdPins:RemoveWorldMapIcon(self, frame)
        end
        self:ReleaseMarkerFrame(frame)
    end
    wipe(self.worldMapFrames)
end

function Map:ClearMinimapMarkers()
    if self.hbdPins and self.hbdPins.RemoveAllMinimapIcons then
        self.hbdPins:RemoveAllMinimapIcons(self)
    end
    for _, frame in ipairs(self.minimapFrames or {}) do
        if self.hbdPins and not self.hbdPins.RemoveAllMinimapIcons then
            self.hbdPins:RemoveMinimapIcon(self, frame)
        end
        self:ReleaseMarkerFrame(frame)
    end
    wipe(self.minimapFrames)
    if self.StopMinimapMarkerUpdates then
        self:StopMinimapMarkerUpdates()
    end
end

function Map:AddWorldMapMarker(marker)
    if not self.hbdPins or not marker.uiMapId or not marker.x or not marker.y then
        return
    end
    if not self:CanPlaceMarker(marker.uiMapId, marker.x, marker.y) then
        return
    end

    local frame = self:AcquireMarkerFrame("worldMap", WorldMapFrame)
    frame.markerId = marker.id
    frame.markerData = marker
    self.hbdPins:AddWorldMapIconMap(
        self,
        frame,
        marker.uiMapId,
        marker.x,
        marker.y,
        HBD_PINS_WORLDMAP_SHOW_WORLD or 3
    )
    SetFramePropagateMouseClicks(frame:GetParent(), true)
    self.worldMapFrames[#self.worldMapFrames + 1] = frame
end

function Map:AddMinimapMarker(marker)
    if not self.hbd or not Minimap or not marker.uiMapId or not marker.x or not marker.y then
        return
    end
    if not self:CanPlaceMarker(marker.uiMapId, marker.x, marker.y) then
        return
    end

    local worldX, worldY, instanceId = self.hbd:GetWorldCoordinatesFromZone(marker.x, marker.y, marker.uiMapId)
    if not worldX or not worldY or not instanceId then
        return
    end

    local frame = self:AcquireMarkerFrame("minimap", Minimap)
    frame.markerId = marker.id
    frame.markerData = marker
    frame.markerWorldX = worldX
    frame.markerWorldY = worldY
    frame.markerInstanceId = instanceId
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    self.minimapFrames[#self.minimapFrames + 1] = frame
    self:StartMinimapMarkerUpdates()
end

function Map:RefreshWorldMapMarkers()
    local settings = self:GetSettings()

    self:ClearWorldMapMarkers()
    if settings.enabled == false or settings.showWorldMapMarkers == false then
        return
    end
    for _, marker in ipairs(self:GetMarkerStore()) do
        self:AddWorldMapMarker(marker)
    end
end

function Map:RefreshMinimapMarkers()
    local settings = self:GetSettings()

    self:ClearMinimapMarkers()
    if settings.enabled == false or settings.showMinimapDirections == false then
        return
    end
    for _, marker in ipairs(self:GetMarkerStore()) do
        self:AddMinimapMarker(marker)
    end
    self:UpdateMinimapMarkers()
end

function Map:Refresh()
    if not self.hbdPins then
        self.hbd = LibStub and LibStub("HereBeDragons-2.0", true)
        self.hbdPins = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
    end
    if not self.hbdPins then
        return
    end

    self:RefreshWorldMapMarkers()
    self:RefreshMinimapMarkers()
end

function Map:UpdateMinimapMarkerFrame(frame, playerX, playerY, playerInstanceId, playerFacing, rotateMinimap)
    if not frame or not frame.markerWorldX or not frame.markerWorldY or frame.markerInstanceId ~= playerInstanceId then
        if frame then
            frame:Hide()
        end
        return
    end

    local xDist = playerX - frame.markerWorldX
    local yDist = playerY - frame.markerWorldY
    local distance = math.sqrt((xDist * xDist) + (yDist * yDist))
    if distance <= 0 then
        frame:Hide()
        return
    end

    if rotateMinimap and playerFacing then
        local sinFacing = math.sin(playerFacing)
        local cosFacing = math.cos(playerFacing)
        local rotatedX = (xDist * cosFacing) - (yDist * sinFacing)
        local rotatedY = (xDist * sinFacing) + (yDist * cosFacing)

        xDist = rotatedX
        yDist = rotatedY
    end

    local edgeRadius = GetMinimapEdgeRadius()
    local worldRadius = GetMinimapWorldRadius()
    local scale = edgeRadius / math.max(1, worldRadius)
    local offsetX = xDist * scale
    local offsetY = -yDist * scale
    local offsetDistance = math.sqrt((offsetX * offsetX) + (offsetY * offsetY))

    if offsetDistance > edgeRadius then
        offsetX = (offsetX / offsetDistance) * edgeRadius
        offsetY = (offsetY / offsetDistance) * edgeRadius
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", Minimap, "CENTER", offsetX, offsetY)
    frame:Show()
end

function Map:UpdateMinimapMarkers()
    if not self.hbd or not self.hbd.GetPlayerWorldPosition then
        return
    end

    local playerX, playerY, playerInstanceId = self.hbd:GetPlayerWorldPosition()
    if not playerX or not playerY or not playerInstanceId then
        for _, frame in ipairs(self.minimapFrames or {}) do
            frame:Hide()
        end
        return
    end

    local rotateMinimap = GetCVar and GetCVar("rotateMinimap") == "1"
    local playerFacing = rotateMinimap and GetPlayerFacing and GetPlayerFacing() or nil

    for _, frame in ipairs(self.minimapFrames or {}) do
        self:UpdateMinimapMarkerFrame(frame, playerX, playerY, playerInstanceId, playerFacing, rotateMinimap)
    end
end

function Map:StartMinimapMarkerUpdates()
    if self.minimapUpdateFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(updateFrame, elapsed)
        updateFrame.elapsed = (updateFrame.elapsed or 0) + (elapsed or 0)
        if updateFrame.elapsed < MINIMAP_UPDATE_INTERVAL then
            return
        end
        updateFrame.elapsed = 0
        Map:UpdateMinimapMarkers()
    end)
    self.minimapUpdateFrame = frame
end

function Map:StopMinimapMarkerUpdates()
    if not self.minimapUpdateFrame then
        return
    end

    self.minimapUpdateFrame:SetScript("OnUpdate", nil)
    self.minimapUpdateFrame:Hide()
    self.minimapUpdateFrame = nil
end

function Map:GetCursorWorldMapPosition()
    return GetFrameCursorPosition(GetMapContentFrame())
end

function Map:HandleWorldMapClick(button)
    if not IsAltLeftClick(button) or not self:IsEnabled() then
        return
    end

    local now = GetTime and GetTime() or 0
    if self.suppressPlacementUntil and now < self.suppressPlacementUntil then
        return
    end
    if self.lastPlacementTime and now - self.lastPlacementTime < 0.05 then
        return
    end
    if self:RemoveMarkerUnderCursor() then
        return
    end

    local uiMapId = GetCurrentMapId()
    local x, y = self:GetCursorWorldMapPosition()
    if not uiMapId or not x or not y then
        return
    end

    self.lastPlacementTime = now
    self:AddMarker(uiMapId, x, y)
end

function Map:RefreshPlacementOverlay()
    local overlay = self.placementOverlay
    if not overlay then
        return
    end

    local enabled = self:IsEnabled() and IsAltKeyDown and IsAltKeyDown()
    if enabled then
        overlay:Show()
        overlay:EnableMouse(true)
        self:RefreshPlacementOverlayTooltip()
        return
    end

    overlay:EnableMouse(false)
    overlay:Show()
    self:HidePlacementOverlayTooltip()
end

function Map:HidePlacementOverlayTooltip()
    if self.overlayTooltipFrame then
        self:HideMarkerTooltip(self.overlayTooltipFrame)
        self.overlayTooltipFrame = nil
    end
end

function Map:RefreshPlacementOverlayTooltip()
    local frame = FindWorldMapMarkerFrameUnderCursor(self.worldMapFrames)
    if frame == self.overlayTooltipFrame then
        return
    end

    self:HidePlacementOverlayTooltip()
    if frame then
        self.overlayTooltipFrame = frame
        self:ShowMarkerTooltip(frame)
    end
end

function Map:CreatePlacementOverlay(parent)
    if self.placementOverlay or not parent then
        return
    end

    local overlay = CreateFrame("Button", nil, parent)
    overlay:SetAllPoints(parent)
    overlay:RegisterForClicks("LeftButtonUp")
    overlay:SetScript("OnMouseUp", function(_, button)
        Map:HandleWorldMapClick(button)
    end)
    overlay:SetScript("OnUpdate", function()
        Map:RefreshPlacementOverlay()
    end)
    overlay:EnableMouse(false)
    overlay:Show()

    if overlay.SetFrameLevel and parent.GetFrameLevel then
        overlay:SetFrameLevel((parent:GetFrameLevel() or 0) + 1)
    end

    self.placementOverlay = overlay
    self:RefreshPlacementOverlay()
end

function Map:HookWorldMapMarkerPlacement()
    if not WorldMapFrame then
        return
    end

    self:CreatePlacementOverlay(_G.WorldMapButton or WorldMapFrame.ScrollContainer or WorldMapDetailFrame or WorldMapFrame)

    if not WorldMapFrame.vanillaEnhancedMapMarkersShowHooked and WorldMapFrame.HookScript then
        WorldMapFrame.vanillaEnhancedMapMarkersShowHooked = true
        WorldMapFrame:HookScript("OnShow", function()
            Map:HookWorldMapMarkerPlacement()
            Map:RefreshWorldMapMarkers()
        end)
    end
end
