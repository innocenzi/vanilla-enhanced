local VanillaEnhanced = _G.VanillaEnhanced

local function SendChat(message, chatType)
    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        C_ChatInfo.SendChatMessage(message, chatType)
        return true
    end
    if type(SendChatMessage) ~= "function" then return false end
    SendChatMessage(message, chatType)
    return true
end

function VanillaEnhanced:NormalizeOutgoingMessageLocale(locale)
    if locale == "auto" or not locale then
        locale = self.GetLocaleKey and self:GetLocaleKey() or "enUS"
    end
    return locale == "frFR" and "frFR" or "enUS"
end

function VanillaEnhanced:RenderOutgoingMessageTemplate(template, allowedValues, values)
    if type(template) ~= "string" or not string.find(template, "%S") then
        return nil
    end

    local invalid = false
    local message = string.gsub(template, "{([%w_]+)}", function(name)
        if not (allowedValues and allowedValues[name]) then
            invalid = true
            return ""
        end
        return values and values[name] or ""
    end)

    if invalid or string.find(message, "{.-}") or not string.find(message, "%S") then
        return nil
    end
    return message
end

local function IsInGroupCategory(category)
    if type(IsInGroup) ~= "function" then return false end
    if category ~= nil then
        local ok, inGroup = pcall(IsInGroup, category)
        return ok and inGroup == true
    end
    local ok, inGroup = pcall(IsInGroup)
    return ok and inGroup == true
end

function VanillaEnhanced:IsInHomeParty()
    if type(IsInRaid) == "function" and IsInRaid() then return false end

    local instanceCategory = _G.LE_PARTY_CATEGORY_INSTANCE
    if instanceCategory ~= nil and IsInGroupCategory(instanceCategory) then return false end

    local homeCategory = _G.LE_PARTY_CATEGORY_HOME
    if homeCategory ~= nil and IsInGroupCategory(homeCategory) then return true end
    if IsInGroupCategory(nil) then return true end

    if type(GetNumSubgroupMembers) == "function" then
        local count = GetNumSubgroupMembers()
        if type(count) == "number" and count > 0 then return true end
    end
    if type(GetNumPartyMembers) == "function" then
        local count = GetNumPartyMembers()
        if type(count) == "number" and count > 0 then return true end
    end
    return type(UnitExists) == "function" and UnitExists("party1") == true
end

function VanillaEnhanced:SendPartyMessage(message)
    if type(message) ~= "string" or message == "" or not self:IsInHomeParty() then
        return false
    end
    return SendChat(message, "PARTY")
end

function VanillaEnhanced:SendOutgoingMessage(message, destination)
    if type(message) ~= "string" or message == "" then return false end
    if destination == "nearby" then return SendChat(message, "EMOTE") end
    if destination == "party" then return self:SendPartyMessage(message) end
    if type(IsInRaid) ~= "function" or not IsInRaid() then return false end
    return SendChat(message, "RAID")
end

function VanillaEnhanced:SendRaidMessage(message)
    if type(message) ~= "string" or message == "" then return false end
    if type(IsInRaid) ~= "function" or not IsInRaid() then
        return false
    end
    return SendChat(message, "RAID")
end
