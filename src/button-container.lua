local VanillaEnhanced = _G.VanillaEnhanced

local DEFAULT_BUTTON_WIDTH = 24
local DEFAULT_BUTTON_HEIGHT = 24
local DEFAULT_BUTTON_SPACING = 1
local DEFAULT_PADDING = 5
local CONTAINER_BACKGROUND = "Interface\\DialogFrame\\UI-DialogBox-Background"
local CONTAINER_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

local function GetOption(options, key, defaultValue)
    if options and options[key] ~= nil then
        return options[key]
    end
    return defaultValue
end

local function GetButtonCount(buttons)
    local count = 0
    for _, button in ipairs(buttons or {}) do
        if button then
            count = count + 1
        end
    end
    return count
end

local function CreateFallbackLine(container, key, red, green, blue)
    local line = container:CreateTexture(nil, "BORDER")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(red, green, blue, 1)
    container[key] = line
    return line
end

local function ConfigureFallbackBackdrop(container)
    if not container.VanillaEnhancedButtonContainerBackground then
        local background = container:CreateTexture(nil, "BACKGROUND")
        background:SetTexture(CONTAINER_BACKGROUND)
        background:SetTexCoord(0.12, 0.88, 0.12, 0.88)
        container.VanillaEnhancedButtonContainerBackground = background
    end

    container.VanillaEnhancedButtonContainerBackground:SetAllPoints(container)

    local top = container.VanillaEnhancedButtonContainerTop
        or CreateFallbackLine(container, "VanillaEnhancedButtonContainerTop", 0.58, 0.58, 0.58)
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", container, "TOPRIGHT", -1, -1)
    top:SetHeight(2)

    local bottom = container.VanillaEnhancedButtonContainerBottom
        or CreateFallbackLine(container, "VanillaEnhancedButtonContainerBottom", 0.18, 0.16, 0.14)
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 1, 1)
    bottom:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
    bottom:SetHeight(2)

    local left = container.VanillaEnhancedButtonContainerLeft
        or CreateFallbackLine(container, "VanillaEnhancedButtonContainerLeft", 0.58, 0.58, 0.58)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
    left:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 1, 1)
    left:SetWidth(2)

    local right = container.VanillaEnhancedButtonContainerRight
        or CreateFallbackLine(container, "VanillaEnhancedButtonContainerRight", 0.18, 0.16, 0.14)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", container, "TOPRIGHT", -1, -1)
    right:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
    right:SetWidth(2)
end

function VanillaEnhanced:ConfigureButtonContainer(container, options)
    if not container then
        return nil
    end

    local buttonCount = GetOption(options, "buttonCount", 1)
    local buttonWidth = GetOption(options, "buttonWidth", DEFAULT_BUTTON_WIDTH)
    local buttonHeight = GetOption(options, "buttonHeight", DEFAULT_BUTTON_HEIGHT)
    local buttonSpacing = GetOption(options, "buttonSpacing", DEFAULT_BUTTON_SPACING)
    local padding = GetOption(options, "padding", DEFAULT_PADDING)
    local width = GetOption(options, "width", (buttonWidth * buttonCount) + (buttonSpacing * math.max(0, buttonCount - 1)) + (padding * 2))
    local height = GetOption(options, "height", buttonHeight + (padding * 2))

    container:SetSize(width, height)
    if container.SetBackdrop then
        container:SetBackdrop({
            bgFile = CONTAINER_BACKGROUND,
            edgeFile = CONTAINER_BORDER,
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {
                left = 5,
                right = 5,
                top = 5,
                bottom = 5,
            },
        })
        if container.SetBackdropColor then
            container:SetBackdropColor(0.20, 0.20, 0.20, 0.95)
        end
        if container.SetBackdropBorderColor then
            container:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
        end
    else
        ConfigureFallbackBackdrop(container)
    end

    return container
end

function VanillaEnhanced:CreateButtonContainer(name, options)
    local parent = GetOption(options, "parent", UIParent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local container

    if template then
        local ok, frame = pcall(CreateFrame, "Frame", name, parent, template)
        if ok and frame then
            container = frame
        end
    end

    if not container then
        container = CreateFrame("Frame", name, parent)
    end

    return self:ConfigureButtonContainer(container, options)
end

function VanillaEnhanced:LayoutButtonContainer(container, buttons, options)
    if not container then
        return nil
    end

    options = options or {}
    options.buttonCount = GetOption(options, "buttonCount", GetButtonCount(buttons))
    self:ConfigureButtonContainer(container, options)

    local padding = GetOption(options, "padding", DEFAULT_PADDING)
    local buttonSpacing = GetOption(options, "buttonSpacing", DEFAULT_BUTTON_SPACING)
    local previousButton

    for _, button in ipairs(buttons or {}) do
        if button then
            button:SetParent(container)
            if button.SetFrameStrata and container.GetFrameStrata then
                button:SetFrameStrata(container:GetFrameStrata() or "HIGH")
            end
            if button.SetFrameLevel and container.GetFrameLevel then
                button:SetFrameLevel((container:GetFrameLevel() or 0) + 1)
            end

            button:ClearAllPoints()
            if previousButton then
                button:SetPoint("LEFT", previousButton, "RIGHT", buttonSpacing, 0)
            else
                button:SetPoint("LEFT", container, "LEFT", padding, 0)
            end
            previousButton = button
        end
    end

    return container
end
