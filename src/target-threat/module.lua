local VanillaEnhanced = _G.VanillaEnhanced
local TargetThreat = VanillaEnhanced:CreateModule("target-threat", "Target Threat")

local DISPLAY_HOLD = 2.0
local TICK_RATE = 0.15

TargetThreat.lastText = nil
TargetThreat.lastStatus = nil
TargetThreat.lastTime = 0

function TargetThreat:GetSettings()
    return VanillaEnhanced:GetModuleSettings("target-threat", {
        enabled = true,
        alwaysShow = true,
    })
end

local function TargetValid()
    return UnitExists("target")
        and not UnitIsDead("target")
        and not UnitIsFriend("player", "target")
end

local function ThreatColor(status)
    if status == 3 then
        return 0.72, 0.05, 0.03
    end
    if status == 2 then
        return 0.95, 0.45, 0.08
    end
    if status == 1 then
        return 0.9, 0.75, 0.12
    end
    if type(GetThreatStatusColor) == "function" and status then
        local r, g, b = GetThreatStatusColor(status)
        if r then
            return r, g, b
        end
    end
    return 0.35, 0.35, 0.35
end

local function CreateFallbackBorderLine(parent, point, relativePoint, width, height)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(0, 0, 0, 1)
    line:SetPoint(point, parent, relativePoint, 0, 0)
    line:SetSize(width, height)
    return line
end

local function ApplyNativeBorder(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = {
                left = 3,
                right = 3,
                top = 3,
                bottom = 3,
            },
        })
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(0.75, 0.75, 0.75, 1)
        end
        return
    end

    CreateFallbackBorderLine(frame, "TOPLEFT", "TOPLEFT", 58, 2)
    CreateFallbackBorderLine(frame, "BOTTOMLEFT", "BOTTOMLEFT", 58, 2)
    CreateFallbackBorderLine(frame, "TOPLEFT", "TOPLEFT", 2, 22)
    CreateFallbackBorderLine(frame, "TOPRIGHT", "TOPRIGHT", 2, 22)
end

function TargetThreat:EnsureUI()
    if self.ui then
        return true
    end
    if not TargetFrame then
        return false
    end

    local parent = TargetFrame
    local anchor = TargetFrameManaBar or TargetFrameHealthBar or parent
    local ui = CreateFrame("Frame", "VanillaEnhancedTargetThreatFrame", parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    ui:SetSize(58, 22)
    ui:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -2, -5)
    ui:SetFrameStrata(parent:GetFrameStrata() or "LOW")
    ui:SetFrameLevel((parent:GetFrameLevel() or 0) + 50)
    ui:Hide()

    local bg = ui:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetPoint("TOPLEFT", ui, "TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -4, 4)

    ApplyNativeBorder(ui)

    local text = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", ui, "CENTER", 0, 0)
    text:SetText("")

    ui.bg = bg
    ui.text = text
    self.ui = ui
    return true
end

function TargetThreat:ResetCache()
    self.lastText = nil
    self.lastStatus = nil
    self.lastTime = 0
end

local function ReadThreatNow()
    if type(UnitDetailedThreatSituation) == "function" then
        local isTanking, status, scaledPct = UnitDetailedThreatSituation("player", "target")
        if scaledPct ~= nil then
            return string.format("%.0f%%", scaledPct), status
        end
        if isTanking and status ~= nil then
            return "100%", status
        end
    end
    return nil
end

function TargetThreat:Hide()
    if self.ui then
        self.ui:Hide()
    end
end

function TargetThreat:Update()
    local settings = self:GetSettings()
    if not settings.enabled then
        self:Hide()
        return
    end
    if not self:EnsureUI() then
        return
    end

    local ui = self.ui
    if not TargetValid() then
        ui:Hide()
        return
    end

    local now = GetTime()
    local text, status = ReadThreatNow()

    if text then
        self.lastText = text
        self.lastStatus = status
        self.lastTime = now
    else
        if settings.alwaysShow then
            text = "0%"
            status = nil
        elseif not self.lastText or (now - self.lastTime) > DISPLAY_HOLD then
            ui:Hide()
            return
        else
            text = self.lastText
            status = self.lastStatus
        end
    end

    ui.text:SetText(text)
    ui.text:SetTextColor(1, 1, 1)
    local r, g, b = ThreatColor(status)
    ui.bg:SetVertexColor(r, g, b, 0.9)
    ui:Show()
end

function TargetThreat:StartTicker()
    if self.ticker then
        return
    end
    if not self:GetSettings().enabled then
        return
    end
    if C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(TICK_RATE, function()
            TargetThreat:Update()
        end)
    else
        self.eventFrame:SetScript("OnUpdate", function(frame, elapsed)
            frame._acc = (frame._acc or 0) + elapsed
            if frame._acc >= TICK_RATE then
                frame._acc = 0
                TargetThreat:Update()
            end
        end)
    end
end

function TargetThreat:StopTicker()
    if self.ticker and self.ticker.Cancel then
        self.ticker:Cancel()
    end
    self.ticker = nil

    if self.eventFrame then
        self.eventFrame:SetScript("OnUpdate", nil)
    end
end

function TargetThreat:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("target-threat", enabled)

    if enabled then
        self:StartTicker()
        self:Update()
        return
    end

    self:StopTicker()
    self:ResetCache()
    self:Hide()
end

local eventFrame = CreateFrame("Frame")
TargetThreat.eventFrame = eventFrame

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if TargetThreat:GetSettings().enabled then
            TargetThreat:EnsureUI()
            TargetThreat:StartTicker()
            TargetThreat:Update()
        else
            TargetThreat:Hide()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        TargetThreat:ResetCache()
        TargetThreat:Update()
    else
        TargetThreat:Update()
    end
end)

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
