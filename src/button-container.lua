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

local function GetPadding(options, side)
    local padding = GetOption(options, "padding", DEFAULT_PADDING)
    if side then
        return GetOption(options, "padding" .. side, padding)
    end
    return padding
end

local function GetControlSize(control, widthFallback, heightFallback)
    if not control then
        return 0, 0
    end

    local width = widthFallback
    local height = heightFallback
    if control.GetWidth then
        width = control:GetWidth() or width
    end
    if control.GetHeight then
        height = control:GetHeight() or height
    end
    return width or 0, height or 0
end

local function GetButtonsSize(buttons, options)
    local buttonWidth = GetOption(options, "buttonWidth", DEFAULT_BUTTON_WIDTH)
    local buttonHeight = GetOption(options, "buttonHeight", DEFAULT_BUTTON_HEIGHT)
    local buttonSpacing = GetOption(options, "buttonSpacing", DEFAULT_BUTTON_SPACING)
    local width = 0
    local height = 0
    local count = 0

    for _, button in ipairs(buttons or {}) do
        if button then
            local controlWidth, controlHeight = GetControlSize(button, buttonWidth, buttonHeight)
            if count > 0 then
                width = width + buttonSpacing
            end
            width = width + controlWidth
            height = math.max(height, controlHeight)
            count = count + 1
        end
    end

    if count == 0 then
        count = GetOption(options, "buttonCount", 1)
        width = (buttonWidth * count) + (buttonSpacing * math.max(0, count - 1))
        height = buttonHeight
    end

    return width, height, count
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
    local paddingLeft = GetPadding(options, "Left")
    local paddingRight = GetPadding(options, "Right")
    local paddingTop = GetPadding(options, "Top")
    local paddingBottom = GetPadding(options, "Bottom")
    local width = GetOption(
        options,
        "width",
        (buttonWidth * buttonCount) + (buttonSpacing * math.max(0, buttonCount - 1)) + paddingLeft + paddingRight
    )
    local height = GetOption(options, "height", buttonHeight + paddingTop + paddingBottom)

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

    local layoutOptions = {}
    for key, value in pairs(options or {}) do
        layoutOptions[key] = value
    end

    layoutOptions.buttonCount = GetOption(layoutOptions, "buttonCount", GetButtonCount(buttons))
    if layoutOptions.width == nil or layoutOptions.height == nil then
        local contentWidth, contentHeight = GetButtonsSize(buttons, layoutOptions)
        if layoutOptions.width == nil then
            layoutOptions.width = contentWidth + GetPadding(layoutOptions, "Left") + GetPadding(layoutOptions, "Right")
        end
        if layoutOptions.height == nil then
            layoutOptions.height = contentHeight + GetPadding(layoutOptions, "Top") + GetPadding(layoutOptions, "Bottom")
        end
    end
    self:ConfigureButtonContainer(container, layoutOptions)

    local paddingLeft = GetPadding(layoutOptions, "Left")
    local buttonSpacing = GetOption(layoutOptions, "buttonSpacing", DEFAULT_BUTTON_SPACING)
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
                button:SetPoint("LEFT", container, "LEFT", paddingLeft, 0)
            end
            previousButton = button
        end
    end

    return container
end
