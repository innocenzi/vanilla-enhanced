local Quests = _G.VanillaEnhanced:GetModule("quests")

local function SafeCall(method, ...)
    if not method then
        return false, nil
    end

    return pcall(method, ...)
end

local function PositiveNumber(value)
    value = tonumber(value)
    if value and value > 0 then
        return value
    end
    return nil
end

local function GetTextureNumber(texture, ...)
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        local value = texture and texture[key]
        value = PositiveNumber(value)
        if value then
            return value
        end
    end
    return nil
end

local function GetFirstLayerSize(layers)
    local layer = layers and layers[1]
    if not layer then
        return nil, nil
    end

    return PositiveNumber(layer.layerWidth or layer.width or layer[1]),
        PositiveNumber(layer.layerHeight or layer.height or layer[2])
end

local function GetMapArtLayerSize(uiMapId)
    if not C_Map or not C_Map.GetMapArtLayers then
        return nil, nil
    end

    if C_Map.GetMapArtID then
        local artOk, mapArtId = SafeCall(C_Map.GetMapArtID, uiMapId)
        if artOk and mapArtId then
            local layersOk, layers = SafeCall(C_Map.GetMapArtLayers, mapArtId)
            if layersOk then
                local width, height = GetFirstLayerSize(layers)
                if width and height then
                    return width, height
                end
            end
        end
    end

    local layersOk, layers = SafeCall(C_Map.GetMapArtLayers, uiMapId)
    if layersOk then
        return GetFirstLayerSize(layers)
    end

    return nil, nil
end

local function GetExploredMapTextures(uiMapId)
    local api = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
    if not api then
        return nil
    end

    local ok, textures = SafeCall(api, uiMapId)
    if ok and type(textures) == "table" and #textures > 0 then
        return textures
    end

    return nil
end

local function GetFallbackTextureBounds(textures)
    local maxX, maxY = 0, 0

    for _, texture in ipairs(textures or {}) do
        local offsetX = GetTextureNumber(texture, "offsetX", "x", 1) or 0
        local offsetY = GetTextureNumber(texture, "offsetY", "y", 2) or 0
        local width = GetTextureNumber(texture, "textureWidth", "width", 3)
        local height = GetTextureNumber(texture, "textureHeight", "height", 4)

        if width and height then
            maxX = math.max(maxX, offsetX + width)
            maxY = math.max(maxY, offsetY + height)
        end
    end

    return PositiveNumber(maxX), PositiveNumber(maxY)
end

local function GetExploredAreaIDsAtPosition(uiMapId, x, y)
    local api = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredAreaIDsAtPosition
    if not api or not CreateVector2D then
        return false, nil
    end

    local ok, areaIds = SafeCall(api, uiMapId, CreateVector2D(x / 100, y / 100))
    if not ok then
        return false, nil
    end

    return true, type(areaIds) == "table" and areaIds or {}
end

local function BuildExplorationCacheEntry(uiMapId)
    local textures = GetExploredMapTextures(uiMapId)
    local apiAvailable = C_MapExplorationInfo
        and C_MapExplorationInfo.GetExploredMapTextures
        and true
        or false

    if not textures then
        return {
            apiAvailable = apiAvailable,
            hasFogData = false,
        }
    end

    local width, height = GetMapArtLayerSize(uiMapId)
    if not width or not height then
        width, height = GetFallbackTextureBounds(textures)
    end
    if not width or not height then
        return {
            apiAvailable = true,
            hasFogData = false,
        }
    end

    return {
        apiAvailable = true,
        hasFogData = true,
        width = width,
        height = height,
        textures = textures,
    }
end

local function GetExplorationCacheEntry(self, uiMapId)
    self.mapExplorationCache = self.mapExplorationCache or {}

    local entry = self.mapExplorationCache[uiMapId]
    if not entry then
        entry = BuildExplorationCacheEntry(uiMapId)
        self.mapExplorationCache[uiMapId] = entry
    end
    return entry
end

local function TextureContainsPoint(texture, pixelX, pixelY)
    local offsetX = GetTextureNumber(texture, "offsetX", "x", 1) or 0
    local offsetY = GetTextureNumber(texture, "offsetY", "y", 2) or 0
    local width = GetTextureNumber(texture, "textureWidth", "width", 3)
    local height = GetTextureNumber(texture, "textureHeight", "height", 4)

    if not width or not height then
        return false
    end

    return pixelX >= offsetX
        and pixelX <= offsetX + width
        and pixelY >= offsetY
        and pixelY <= offsetY + height
end

local function IsLocationInsideExploredTexture(entry, x, y)
    local pixelX = (x / 100) * entry.width
    local pixelY = (y / 100) * entry.height

    for _, texture in ipairs(entry.textures) do
        if TextureContainsPoint(texture, pixelX, pixelY) then
            return true
        end
    end

    return false
end

function Quests:ClearMapExplorationCache()
    self.mapExplorationCache = {}
end

function Quests:IsQuestMapFogFilterEnabled()
    local settings = self:GetSettings()
    return settings.enabled ~= false
        and settings.showMapMarkers ~= false
        and settings.hideMapMarkersInFogOfWar == true
end

function Quests:DoesQuestMapHaveFogData(uiMapId)
    if not uiMapId then
        return false
    end

    local entry = GetExplorationCacheEntry(self, uiMapId)
    return entry.hasFogData == true
end

function Quests:IsQuestWorldMapLocationVisible(uiMapId, x, y, hideIfExplorationApiHasNoData)
    if not self:IsQuestMapFogFilterEnabled() then
        return true
    end
    if not uiMapId or not x or not y then
        return true
    end

    local entry = GetExplorationCacheEntry(self, uiMapId)
    if not entry.hasFogData then
        return not (hideIfExplorationApiHasNoData == true and entry.apiAvailable == true)
    end

    local hasPreciseResult, areaIds = GetExploredAreaIDsAtPosition(uiMapId, x, y)
    if hasPreciseResult then
        return #areaIds > 0
    end

    return IsLocationInsideExploredTexture(entry, x, y)
end
