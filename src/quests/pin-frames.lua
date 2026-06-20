local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

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
    if frame.SetPropagateMouseClicks then
        frame:SetPropagateMouseClicks(false)
    end
end

local function ReleasePinFrame(self, frame)
    ResetPinFrame(frame)
    frame:Hide()
    self.pool[frame.poolKind][#self.pool[frame.poolKind] + 1] = frame
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
