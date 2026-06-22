local VanillaEnhanced = _G.VanillaEnhanced
local Map = VanillaEnhanced:GetModule("map")

local TOMTOM_ADDON_NAME = "TomTom"
local TOMTOM_ADDON_KEY = string.lower(TOMTOM_ADDON_NAME)
local COMMAND_KEY = "VANILLAENHANCED_WAY"

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function Trim(value)
    if type(value) ~= "string" then
        return nil
    end
    return string.gsub(value, "^%s*(.-)%s*$", "%1")
end

local function NormalizeName(value)
    value = Trim(value)
    if not value or value == "" then
        return nil
    end
    return string.lower(value)
end

local function Tokenize(message)
    local tokens = {}
    for token in string.gmatch(message or "", "%S+") do
        tokens[#tokens + 1] = token
    end
    return tokens
end

local function ParseCoordinateToken(token)
    if type(token) ~= "string" then
        return nil
    end

    token = string.gsub(token, "%%", "")
    token = string.gsub(token, ",$", "")
    token = string.gsub(token, ",", ".")

    local value = tonumber(token)
    if not value or value < 0 or value > 100 then
        return nil
    end
    return value / 100
end

local function ConcatTokens(tokens, firstIndex, lastIndex)
    if not firstIndex or firstIndex < 1 or firstIndex > #tokens then
        return nil
    end

    lastIndex = lastIndex or #tokens
    if lastIndex < firstIndex then
        return nil
    end

    local value = table.concat(tokens, " ", firstIndex, lastIndex)
    value = Trim(value)
    if value == "" then
        return nil
    end
    return value
end

local function GetCurrentWorldMapId()
    if WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown() then
        if WorldMapFrame.GetMapID then
            return WorldMapFrame:GetMapID()
        end
        if WorldMapFrame.mapID then
            return WorldMapFrame.mapID
        end
    end
    return nil
end

local function GetMapInfoName(uiMapId)
    if not C_Map or not C_Map.GetMapInfo then
        return nil
    end

    local ok, info = pcall(C_Map.GetMapInfo, uiMapId)
    if ok and info and info.name and info.name ~= "" then
        return info.name
    end
    return nil
end

local function AddMatchedMap(matches, matchedIds, uiMapId)
    if not uiMapId or matchedIds[uiMapId] then
        return
    end
    matchedIds[uiMapId] = true
    matches[#matches + 1] = uiMapId
end

local function ParseMapIdReference(mapName)
    if type(mapName) ~= "string" then
        return nil
    end

    local mapId = string.match(mapName, "^#(%d+)$")
    if mapId then
        return tonumber(mapId)
    end
    return nil
end

local function IsTomTomAddonName(value)
    return type(value) == "string" and string.lower(value) == TOMTOM_ADDON_KEY
end

local function IsMissingAddOnReason(reason)
    return type(reason) == "string" and string.upper(reason) == "MISSING"
end

local function AddOnInfoIndicatesTomTomInstalled(info, title, reason)
    if IsMissingAddOnReason(reason) then
        return false
    end
    if IsTomTomAddonName(info) or IsTomTomAddonName(title) then
        return true
    end
    if type(info) == "table" then
        if IsMissingAddOnReason(info.reason) then
            return false
        end
        return IsTomTomAddonName(info.name) or IsTomTomAddonName(info.title)
    end
    return false
end

function Map:IsTomTomInstalled()
    if _G.TomTom then
        return true
    end

    if IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, TOMTOM_ADDON_NAME)
        if ok and loaded then
            return true
        end
    end

    if C_AddOns and C_AddOns.GetAddOnInfo then
        local ok, info, title, notes, loadable, reason = pcall(C_AddOns.GetAddOnInfo, TOMTOM_ADDON_NAME)
        if ok and AddOnInfoIndicatesTomTomInstalled(info, title, reason) then
            return true
        end
    end

    if GetAddOnInfo then
        local ok, name, title, notes, loadable, reason = pcall(GetAddOnInfo, TOMTOM_ADDON_NAME)
        if ok and AddOnInfoIndicatesTomTomInstalled(name, title, reason) then
            return true
        end
    end

    return false
end

function Map:RegisterTomTomCommands()
    if self.tomTomCommandsRegistered then
        return
    end

    _G["SLASH_" .. COMMAND_KEY .. "1"] = "/way"
    SlashCmdList[COMMAND_KEY] = function(message)
        Map:HandleWayCommand(message)
    end
    self.tomTomCommandsRegistered = true
end

function Map:UnregisterTomTomCommands()
    if not self.tomTomCommandsRegistered then
        return
    end

    _G["SLASH_" .. COMMAND_KEY .. "1"] = nil
    if SlashCmdList then
        SlashCmdList[COMMAND_KEY] = nil
    end
    self.tomTomCommandsRegistered = false
end

function Map:RefreshTomTomCommands()
    local settings = self:GetSettings()
    if not self:IsEnabled() or settings.enableTomTomCommands ~= true or self:IsTomTomInstalled() then
        self:UnregisterTomTomCommands()
        return
    end

    self:RegisterTomTomCommands()
end

function Map:GetWayCommandCurrentMapId()
    local uiMapId = GetCurrentWorldMapId()
    if uiMapId then
        return uiMapId
    end

    if self.hbd and self.hbd.GetPlayerZone then
        return self.hbd:GetPlayerZone()
    end
    return nil
end

function Map:FindWayCommandMapId(mapName)
    local explicitMapId = ParseMapIdReference(mapName)
    if explicitMapId then
        return explicitMapId
    end

    local normalizedMapName = NormalizeName(mapName)
    if not normalizedMapName or not self.hbd or not self.hbd.GetAllMapIDs then
        return nil, "unknown"
    end

    local matches = {}
    local matchedIds = {}
    local mapIds = self.hbd:GetAllMapIDs()
    for _, uiMapId in ipairs(mapIds or {}) do
        local hbdName = self.hbd.GetLocalizedMap and self.hbd:GetLocalizedMap(uiMapId) or nil
        if NormalizeName(hbdName) == normalizedMapName then
            AddMatchedMap(matches, matchedIds, uiMapId)
        end

        local cMapName = GetMapInfoName(uiMapId)
        if NormalizeName(cMapName) == normalizedMapName then
            AddMatchedMap(matches, matchedIds, uiMapId)
        end
    end

    if #matches == 1 then
        return matches[1]
    end
    if #matches > 1 then
        return nil, "ambiguous"
    end
    return nil, "unknown"
end

function Map:ParseWayCommand(message)
    local tokens = Tokenize(message)
    if #tokens < 2 then
        return nil, "invalid"
    end

    local x = ParseCoordinateToken(tokens[1])
    local y = ParseCoordinateToken(tokens[2])
    if x and y then
        local uiMapId = self:GetWayCommandCurrentMapId()
        if not uiMapId then
            return nil, "currentMap"
        end

        return {
            uiMapId = uiMapId,
            x = x,
            y = y,
            title = ConcatTokens(tokens, 3),
        }
    end

    for index = #tokens - 1, 2, -1 do
        x = ParseCoordinateToken(tokens[index])
        y = ParseCoordinateToken(tokens[index + 1])
        if x and y then
            local mapName = ConcatTokens(tokens, 1, index - 1)
            local uiMapId, reason = self:FindWayCommandMapId(mapName)
            if not uiMapId then
                return nil, reason, {
                    map = mapName or "",
                }
            end

            return {
                uiMapId = uiMapId,
                x = x,
                y = y,
                title = ConcatTokens(tokens, index + 2),
            }
        end
    end

    return nil, "coordinates"
end

function Map:HandleWayCommand(message)
    if self:IsTomTomInstalled() then
        self:UnregisterTomTomCommands()
        VanillaEnhanced:PrintMessage(T("map.tomtom.error.tomTomDetected"))
        if VanillaEnhanced.RefreshOptions then
            VanillaEnhanced:RefreshOptions()
        end
        return
    end

    local settings = self:GetSettings()
    if not self:IsEnabled() or settings.enableTomTomCommands ~= true then
        VanillaEnhanced:PrintMessage(T("map.tomtom.error.disabled"))
        return
    end

    local parsed, errorKey, errorVars = self:ParseWayCommand(message)
    if not parsed then
        VanillaEnhanced:PrintMessage(T("map.tomtom.error." .. (errorKey or "invalid"), errorVars))
        return
    end

    self:AddMarker(parsed.uiMapId, parsed.x, parsed.y, {
        title = parsed.title,
    })
end
