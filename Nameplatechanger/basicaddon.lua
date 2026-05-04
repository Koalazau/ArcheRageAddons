-- Nameplate Resizer - Customize nameplate appearance and behavior

-- Create the main window (hidden by default)
local mainWindow = CreateEmptyWindow("basicAddonWindow", "UIParent")
mainWindow:SetExtent(760, 660)
mainWindow:AddAnchor("CENTER", "UIParent", 0, 0)
mainWindow:EnableDrag(true)
mainWindow:SetCloseOnEscape(true)
mainWindow:Show(false)

-- Make window draggable
function mainWindow:OnDragStart()
    self:StartMoving()
    return true
end
mainWindow:SetHandler("OnDragStart", mainWindow.OnDragStart)

function mainWindow:OnDragStop()
    self:StopMovingOrSizing()
end
mainWindow:SetHandler("OnDragStop", mainWindow.OnDragStop)

-- Add a background color so we can see the window
local background = mainWindow:CreateColorDrawable(0.2, 0.2, 0.2, 0.9, "background")
background:SetExtent(760, 660)
background:AddAnchor("TOPLEFT", mainWindow, 0, 0)
background:Show(true)

-- Create title bar
local titleBar = mainWindow:CreateColorDrawable(0.15, 0.15, 0.15, 1.0, "overlay")
titleBar:SetExtent(760, 35)
titleBar:AddAnchor("TOPLEFT", mainWindow, 0, 0)
titleBar:Show(true)

-- Create title label
local titleLabel = mainWindow:CreateChildWidget("label", "titleLabel", 0, true)
titleLabel.style:SetFontSize(16)
titleLabel.style:SetColor(1, 1, 1, 1.0)
titleLabel.style:SetAlign(ALIGN_CENTER)
titleLabel:SetExtent(760, 35)
titleLabel:AddAnchor("TOP", mainWindow, 0, 8)
titleLabel:SetText("Nameplate Resizer")
titleLabel:Show(true)

-- Vertical divider between left and right columns
local divider = mainWindow:CreateColorDrawable(0.35, 0.35, 0.35, 1.0, "overlay")
divider:SetExtent(2, 600)
divider:AddAnchor("TOPLEFT", mainWindow, 375, 40)
divider:Show(true)

-- Settings file path
local settingsFile = "..\\Documents\\Addon\\Nameplatechanger\\settings.txt"

-- Color file path (stores RGBA values for future nameplate color use)
local colorFile = "..\\Documents\\Addon\\Nameplatechanger\\color.txt"

-- Nametag color file path
local nameplateColorFile = "..\\Documents\\Addon\\ui\\setting\\nametag_color.g"

-- Currently selected nameplate entry key
local selectedEntry = nil

-- Predefined nameplate entries the user can edit
local nameplateEntries = {
    { key = "self_normal",         label = "Self" },
    { key = "party_normal",        label = "Party" },
    { key = "raid_normal",         label = "Raid" },
    { key = "raid_joint_normal",   label = "Joint Raid" },
    { key = "friendly_pc_normal",  label = "Friendly Player" },
    { key = "neutral_pc_normal",   label = "Neutral Player" },
    { key = "hostile_pc_1_normal", label = "Hostile Player 1" },
    { key = "hostile_pc_2_normal", label = "Hostile Player 2" },
    { key = "bad_pc_normal",       label = "Criminal" },
    { key = "dead_normal",         label = "Dead" },
}

-- Read the current RGBA color for a given entry key from nametag_color.g
local function ReadEntryColor(entryKey)
    local file = io.open(nameplateColorFile, "r")
    if not file then return 255, 255, 255, 255 end
    local content = file:read("*all")
    file:close()
    local pattern = entryKey .. "%s+color%s*%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)"
    local r, g, b, a = content:match(pattern)
    return tonumber(r) or 255, tonumber(g) or 255, tonumber(b) or 255, tonumber(a) or 255
end

-- Write a new RGBA color for a given entry key into nametag_color.g
local function WriteEntryColor(entryKey, r, g, b, a)
    local file = io.open(nameplateColorFile, "r")
    if not file then return false end
    local content = file:read("*all")
    file:close()
    local pattern = entryKey .. "%s+color%s*%(%s*%d+%s*,%s*%d+%s*,%s*%d+%s*,%s*%d+%s*%)"
    local replacement = entryKey .. "\n    color (" .. r .. ", " .. g .. ", " .. b .. ", " .. a .. ")"
    local newContent, count = content:gsub(pattern, replacement, 1)
    if count == 0 then return false end
    local writeFile = io.open(nameplateColorFile, "w")
    if not writeFile then return false end
    writeFile:write(newContent)
    writeFile:close()
    return true
end

-- Load settings from file
local function LoadSettings()
    local file = io.open(settingsFile, "r")
    if not file then
        -- File doesn't exist, use defaults
        return "170", "40", "1", "1", "200", "255", "255", "255", "100"
    end

    local content = file:read("*all")
    file:close()

    -- Parse content (format: width,height,markSize,textOffset,fadeDistance,r,g,b,uiScale)
    local width, height, markSize, textOffset, fadeDistance, r, g, b, uiScale = content:match("([%d]+),([%d]+),([%d]+),([%d%.]+),([%d]+),([%d]+),([%d]+),([%d]+),([%d]+)")
    if width and height and markSize and textOffset and fadeDistance and r and g and b and uiScale then
        return width, height, markSize, textOffset, fadeDistance, r, g, b, uiScale
    end

    -- Try old 8-value format (no uiScale) for backwards compatibility
    local w, h, ms, to, fd, rv, gv, bv = content:match("([%d]+),([%d]+),([%d]+),([%d%.]+),([%d]+),([%d]+),([%d]+),([%d]+)")
    if w then
        return w, h, ms, to, fd, rv, gv, bv, "100"
    end

    -- If parsing fails, use defaults
    return "170", "40", "1", "1", "200", "255", "255", "255", "100"
end

-- Save settings to file
local function SaveSettings(width, height, markSize, textOffset, fadeDistance, r, g, b, uiScale)
    local file = io.open(settingsFile, "w")
    if file then
        file:write(string.format("%s,%s,%s,%s,%s,%s,%s,%s,%s", width, height, markSize, textOffset, fadeDistance, r, g, b, uiScale))
        file:close()
    end
end

-- Create Width label
local widthLabel = mainWindow:CreateChildWidget("label", "widthLabel", 0, true)
widthLabel.style:SetFontSize(15)
widthLabel.style:SetColor(1, 1, 1, 1.0)
widthLabel.style:SetAlign(ALIGN_LEFT)
widthLabel:SetExtent(80, 20)
widthLabel:AddAnchor("TOPLEFT", mainWindow, 20, 50)
widthLabel:SetText("Width:")
widthLabel:Show(true)

-- Create Width editbox background
local widthBg = mainWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")
widthBg:SetExtent(110, 25)
widthBg:AddAnchor("LEFT", widthLabel, "RIGHT", 10, 0)
widthBg:Show(true)

-- Create Width editbox
local widthEditbox = mainWindow:CreateChildWidget("editboxmultiline", "widthEditbox", 0, true)
widthEditbox:SetExtent(100, 20)
widthEditbox.style:SetFontSize(14)
widthEditbox:AddAnchor("LEFT", widthLabel, "RIGHT", 10, 0)
widthEditbox.style:SetColorByKey("brown")
widthEditbox:SetMaxTextLength(5)
widthEditbox:SetCursorColorByColorKey("brown")
widthEditbox:SetCursorHeight(-2)
widthEditbox:SetCursorOffset(-3)
widthEditbox:Show(true)

-- Width mousewheel support
function widthEditbox:OnWheelUp(delta)
    local current = tonumber(self:GetText()) or 170
    local newValue = math.min(200, current + 5)
    self:SetText(tostring(newValue))
end
widthEditbox:SetHandler("OnWheelUp", widthEditbox.OnWheelUp)

function widthEditbox:OnWheelDown(delta)
    local current = tonumber(self:GetText()) or 170
    local newValue = math.max(0, current - 5)
    self:SetText(tostring(newValue))
end
widthEditbox:SetHandler("OnWheelDown", widthEditbox.OnWheelDown)

-- Create Height label
local heightLabel = mainWindow:CreateChildWidget("label", "heightLabel", 0, true)
heightLabel.style:SetFontSize(15)
heightLabel.style:SetColor(1, 1, 1, 1.0)
heightLabel.style:SetAlign(ALIGN_LEFT)
heightLabel:SetExtent(80, 20)
heightLabel:AddAnchor("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, 80)
heightLabel:SetText("Height:")
heightLabel:Show(true)

-- Create Height editbox background
local heightBg = mainWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")
heightBg:SetExtent(110, 25)
heightBg:AddAnchor("LEFT", heightLabel, "RIGHT", 10, 0)
heightBg:Show(true)

-- Create Height editbox
local heightEditbox = mainWindow:CreateChildWidget("editboxmultiline", "heightEditbox", 0, true)
heightEditbox:SetExtent(100, 20)
heightEditbox.style:SetFontSize(14)
heightEditbox:AddAnchor("LEFT", heightLabel, "RIGHT", 10, 0)
heightEditbox.style:SetColorByKey("brown")
heightEditbox:SetMaxTextLength(5)
heightEditbox:SetCursorColorByColorKey("brown")
heightEditbox:SetCursorHeight(-2)
heightEditbox:SetCursorOffset(-3)
heightEditbox:Show(true)

-- Height mousewheel support
function heightEditbox:OnWheelUp(delta)
    local current = tonumber(self:GetText()) or 40
    local newValue = math.min(200, current + 5)
    self:SetText(tostring(newValue))
end
heightEditbox:SetHandler("OnWheelUp", heightEditbox.OnWheelUp)

function heightEditbox:OnWheelDown(delta)
    local current = tonumber(self:GetText()) or 40
    local newValue = math.max(0, current - 5)
    self:SetText(tostring(newValue))
end
heightEditbox:SetHandler("OnWheelDown", heightEditbox.OnWheelDown)

-- Create Width slider background bar
local widthSliderBg = mainWindow:CreateColorDrawable(0.1, 0.1, 0.1, 0.8, "background")
widthSliderBg:SetExtent(200, 6)
widthSliderBg:AddAnchor("LEFT", widthLabel, "RIGHT", 10, 0)
widthSliderBg:AddAnchor("TOP", widthEditbox, "BOTTOM", 0, 15)
widthSliderBg:Show(true)

-- Create Width slider
local widthSlider = mainWindow:CreateChildWidget("slider", "widthSlider", 0, true)
widthSlider:SetExtent(200, 20)
widthSlider:AddAnchor("CENTER", widthSliderBg, 0, 0)
widthSlider:SetMinMaxValues(0, 200)
widthSlider:SetOrientation(1)

-- Create thumb button for width slider
local widthThumb = widthSlider:CreateChildWidget("button", "widthThumb", 0, true)
widthThumb:SetExtent(16, 20)
widthThumb:EnableDrag(true)
widthThumb:Show(true)

-- Create a rounded thumb visual
local thumbBg = widthThumb:CreateColorDrawable(0.8, 0.8, 0.8, 1.0, "background")
thumbBg:AddAnchor("TOPLEFT", widthThumb, 2, 0)
thumbBg:AddAnchor("BOTTOMRIGHT", widthThumb, -2, 0)

local thumbHighlight = widthThumb:CreateColorDrawable(0.9, 0.9, 0.9, 1.0, "overlay")
thumbHighlight:AddAnchor("TOPLEFT", widthThumb, 2, 0)
thumbHighlight:SetExtent(12, 2)

-- Attach thumb to slider
widthSlider:SetThumbButtonWidget(widthThumb)
widthSlider:SetFixedThumb(true)
widthSlider:SetMinThumbLength(16)
widthSlider:SetValue(170, false)
widthSlider:Show(true)

-- Width slider value changed handler
function widthSlider:OnSliderChanged(value)
    widthEditbox:SetText(tostring(math.floor(value)))
end
widthSlider:SetHandler("OnSliderChanged", widthSlider.OnSliderChanged)

-- Create Height slider background bar
local heightSliderBg = mainWindow:CreateColorDrawable(0.1, 0.1, 0.1, 0.8, "background")
heightSliderBg:SetExtent(200, 6)
heightSliderBg:AddAnchor("LEFT", heightLabel, "RIGHT", 10, 0)
heightSliderBg:AddAnchor("TOP", heightEditbox, "BOTTOM", 0, 15)
heightSliderBg:Show(true)

-- Create Height slider
local heightSlider = mainWindow:CreateChildWidget("slider", "heightSlider", 0, true)
heightSlider:SetExtent(200, 20)
heightSlider:AddAnchor("CENTER", heightSliderBg, 0, 0)
heightSlider:SetMinMaxValues(0, 200)
heightSlider:SetOrientation(1)

-- Create thumb button for height slider
local heightThumb = heightSlider:CreateChildWidget("button", "heightThumb", 0, true)
heightThumb:SetExtent(16, 20)
heightThumb:EnableDrag(true)
heightThumb:Show(true)

-- Create a rounded thumb visual
local heightThumbBg = heightThumb:CreateColorDrawable(0.8, 0.8, 0.8, 1.0, "background")
heightThumbBg:AddAnchor("TOPLEFT", heightThumb, 2, 0)
heightThumbBg:AddAnchor("BOTTOMRIGHT", heightThumb, -2, 0)

local heightThumbHighlight = heightThumb:CreateColorDrawable(0.9, 0.9, 0.9, 1.0, "overlay")
heightThumbHighlight:AddAnchor("TOPLEFT", heightThumb, 2, 0)
heightThumbHighlight:SetExtent(12, 2)

-- Attach thumb to slider
heightSlider:SetThumbButtonWidget(heightThumb)
heightSlider:SetFixedThumb(true)
heightSlider:SetMinThumbLength(16)
heightSlider:SetValue(40, false)
heightSlider:Show(true)

-- Height slider value changed handler
function heightSlider:OnSliderChanged(value)
    heightEditbox:SetText(tostring(math.floor(value)))
end
heightSlider:SetHandler("OnSliderChanged", heightSlider.OnSliderChanged)

-- Create Mark Size label
local markSizeLabel = mainWindow:CreateChildWidget("label", "markSizeLabel", 0, true)
markSizeLabel.style:SetFontSize(15)
markSizeLabel.style:SetColor(1, 1, 1, 1.0)
markSizeLabel.style:SetAlign(ALIGN_LEFT)
markSizeLabel:SetExtent(80, 20)
markSizeLabel:AddAnchor("TOPLEFT", heightLabel, "BOTTOMLEFT", 0, 80)
markSizeLabel:SetText("Mark Size:")
markSizeLabel:Show(true)

-- Create Mark Size editbox background
local markSizeBg = mainWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")
markSizeBg:SetExtent(110, 25)
markSizeBg:AddAnchor("LEFT", markSizeLabel, "RIGHT", 10, 0)
markSizeBg:Show(true)

-- Create Mark Size editbox
local markSizeEditbox = mainWindow:CreateChildWidget("editboxmultiline", "markSizeEditbox", 0, true)
markSizeEditbox:SetExtent(100, 20)
markSizeEditbox.style:SetFontSize(14)
markSizeEditbox:AddAnchor("LEFT", markSizeLabel, "RIGHT", 10, 0)
markSizeEditbox.style:SetColorByKey("brown")
markSizeEditbox:SetMaxTextLength(1)
markSizeEditbox:SetCursorColorByColorKey("brown")
markSizeEditbox:SetCursorHeight(-2)
markSizeEditbox:SetCursorOffset(-3)
markSizeEditbox:Show(true)

-- Mark Size mousewheel support
function markSizeEditbox:OnWheelUp(delta)
    local current = tonumber(self:GetText()) or 1
    local newValue = math.min(4, current + 1)
    self:SetText(tostring(newValue))
end
markSizeEditbox:SetHandler("OnWheelUp", markSizeEditbox.OnWheelUp)

function markSizeEditbox:OnWheelDown(delta)
    local current = tonumber(self:GetText()) or 1
    local newValue = math.max(0, current - 1)
    self:SetText(tostring(newValue))
end
markSizeEditbox:SetHandler("OnWheelDown", markSizeEditbox.OnWheelDown)

-- Create Mark Size slider background bar
local markSizeSliderBg = mainWindow:CreateColorDrawable(0.1, 0.1, 0.1, 0.8, "background")
markSizeSliderBg:SetExtent(200, 6)
markSizeSliderBg:AddAnchor("LEFT", markSizeLabel, "RIGHT", 10, 0)
markSizeSliderBg:AddAnchor("TOP", markSizeEditbox, "BOTTOM", 0, 15)
markSizeSliderBg:Show(true)

-- Create Mark Size slider
local markSizeSlider = mainWindow:CreateChildWidget("slider", "markSizeSlider", 0, true)
markSizeSlider:SetExtent(200, 20)
markSizeSlider:AddAnchor("CENTER", markSizeSliderBg, 0, 0)
markSizeSlider:SetMinMaxValues(0, 4)
markSizeSlider:SetValueStep(1)
markSizeSlider:SetOrientation(1)

-- Create thumb button for mark size slider
local markSizeThumb = markSizeSlider:CreateChildWidget("button", "markSizeThumb", 0, true)
markSizeThumb:SetExtent(16, 20)
markSizeThumb:EnableDrag(true)
markSizeThumb:Show(true)

local markSizeThumbBg = markSizeThumb:CreateColorDrawable(0.8, 0.8, 0.8, 1.0, "background")
markSizeThumbBg:AddAnchor("TOPLEFT", markSizeThumb, 2, 0)
markSizeThumbBg:AddAnchor("BOTTOMRIGHT", markSizeThumb, -2, 0)

local markSizeThumbHighlight = markSizeThumb:CreateColorDrawable(0.9, 0.9, 0.9, 1.0, "overlay")
markSizeThumbHighlight:AddAnchor("TOPLEFT", markSizeThumb, 2, 0)
markSizeThumbHighlight:SetExtent(12, 2)

markSizeSlider:SetThumbButtonWidget(markSizeThumb)
markSizeSlider:SetFixedThumb(true)
markSizeSlider:SetMinThumbLength(16)
markSizeSlider:SetValue(1, false)
markSizeSlider:Show(true)

function markSizeSlider:OnSliderChanged(value)
    markSizeEditbox:SetText(tostring(math.floor(value)))
end
markSizeSlider:SetHandler("OnSliderChanged", markSizeSlider.OnSliderChanged)

-- Create Text Offset label
local textOffsetLabel = mainWindow:CreateChildWidget("label", "textOffsetLabel", 0, true)
textOffsetLabel.style:SetFontSize(15)
textOffsetLabel.style:SetColor(1, 1, 1, 1.0)
textOffsetLabel.style:SetAlign(ALIGN_LEFT)
textOffsetLabel:SetExtent(80, 20)
textOffsetLabel:AddAnchor("TOPLEFT", markSizeLabel, "BOTTOMLEFT", 0, 80)
textOffsetLabel:SetText("Text Offset:")
textOffsetLabel:Show(true)

-- Create Text Offset editbox background
local textOffsetBg = mainWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")
textOffsetBg:SetExtent(110, 25)
textOffsetBg:AddAnchor("LEFT", textOffsetLabel, "RIGHT", 10, 0)
textOffsetBg:Show(true)

-- Create Text Offset editbox
local textOffsetEditbox = mainWindow:CreateChildWidget("editboxmultiline", "textOffsetEditbox", 0, true)
textOffsetEditbox:SetExtent(100, 20)
textOffsetEditbox.style:SetFontSize(14)
textOffsetEditbox:AddAnchor("LEFT", textOffsetLabel, "RIGHT", 10, 0)
textOffsetEditbox.style:SetColorByKey("brown")
textOffsetEditbox:SetMaxTextLength(5)
textOffsetEditbox:SetCursorColorByColorKey("brown")
textOffsetEditbox:SetCursorHeight(-2)
textOffsetEditbox:SetCursorOffset(-3)
textOffsetEditbox:Show(true)

-- Text Offset mousewheel support
function textOffsetEditbox:OnWheelUp(delta)
    local current = tonumber(self:GetText()) or 1
    local newValue = math.min(2, current + 0.5)
    self:SetText(string.format("%.1f", newValue))
end
textOffsetEditbox:SetHandler("OnWheelUp", textOffsetEditbox.OnWheelUp)

function textOffsetEditbox:OnWheelDown(delta)
    local current = tonumber(self:GetText()) or 1
    local newValue = math.max(0, current - 0.5)
    self:SetText(string.format("%.1f", newValue))
end
textOffsetEditbox:SetHandler("OnWheelDown", textOffsetEditbox.OnWheelDown)

-- Create Text Offset slider background bar
local textOffsetSliderBg = mainWindow:CreateColorDrawable(0.1, 0.1, 0.1, 0.8, "background")
textOffsetSliderBg:SetExtent(200, 6)
textOffsetSliderBg:AddAnchor("LEFT", textOffsetLabel, "RIGHT", 10, 0)
textOffsetSliderBg:AddAnchor("TOP", textOffsetEditbox, "BOTTOM", 0, 15)
textOffsetSliderBg:Show(true)

-- Create Text Offset slider
local textOffsetSlider = mainWindow:CreateChildWidget("slider", "textOffsetSlider", 0, true)
textOffsetSlider:SetExtent(200, 20)
textOffsetSlider:AddAnchor("CENTER", textOffsetSliderBg, 0, 0)
textOffsetSlider:SetMinMaxValues(0, 4)
textOffsetSlider:SetValueStep(1)
textOffsetSlider:SetOrientation(1)

local textOffsetThumb = textOffsetSlider:CreateChildWidget("button", "textOffsetThumb", 0, true)
textOffsetThumb:SetExtent(16, 20)
textOffsetThumb:EnableDrag(true)
textOffsetThumb:Show(true)

local textOffsetThumbBg = textOffsetThumb:CreateColorDrawable(0.8, 0.8, 0.8, 1.0, "background")
textOffsetThumbBg:AddAnchor("TOPLEFT", textOffsetThumb, 2, 0)
textOffsetThumbBg:AddAnchor("BOTTOMRIGHT", textOffsetThumb, -2, 0)

local textOffsetThumbHighlight = textOffsetThumb:CreateColorDrawable(0.9, 0.9, 0.9, 1.0, "overlay")
textOffsetThumbHighlight:AddAnchor("TOPLEFT", textOffsetThumb, 2, 0)
textOffsetThumbHighlight:SetExtent(12, 2)

textOffsetSlider:SetThumbButtonWidget(textOffsetThumb)
textOffsetSlider:SetFixedThumb(true)
textOffsetSlider:SetMinThumbLength(16)
textOffsetSlider:SetValue(2, false)
textOffsetSlider:Show(true)

function textOffsetSlider:OnSliderChanged(value)
    local actualValue = value * 0.5
    textOffsetEditbox:SetText(string.format("%.1f", actualValue))
end
textOffsetSlider:SetHandler("OnSliderChanged", textOffsetSlider.OnSliderChanged)

-- Create Fade Distance label
local fadeDistanceLabel = mainWindow:CreateChildWidget("label", "fadeDistanceLabel", 0, true)
fadeDistanceLabel.style:SetFontSize(15)
fadeDistanceLabel.style:SetColor(1, 1, 1, 1.0)
fadeDistanceLabel.style:SetAlign(ALIGN_LEFT)
fadeDistanceLabel:SetExtent(80, 20)
fadeDistanceLabel:AddAnchor("TOPLEFT", textOffsetLabel, "BOTTOMLEFT", 0, 80)
fadeDistanceLabel:SetText("Fade Dist:")
fadeDistanceLabel:Show(true)

-- Create Fade Distance editbox background
local fadeDistanceBg = mainWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")
fadeDistanceBg:SetExtent(110, 25)
fadeDistanceBg:AddAnchor("LEFT", fadeDistanceLabel, "RIGHT", 10, 0)
fadeDistanceBg:Show(true)

-- Create Fade Distance editbox
local fadeDistanceEditbox = mainWindow:CreateChildWidget("editboxmultiline", "fadeDistanceEditbox", 0, true)
fadeDistanceEditbox:SetExtent(100, 20)
fadeDistanceEditbox.style:SetFontSize(14)
fadeDistanceEditbox:AddAnchor("LEFT", fadeDistanceLabel, "RIGHT", 10, 0)
fadeDistanceEditbox.style:SetColorByKey("brown")
fadeDistanceEditbox:SetMaxTextLength(5)
fadeDistanceEditbox:SetCursorColorByColorKey("brown")
fadeDistanceEditbox:SetCursorHeight(-2)
fadeDistanceEditbox:SetCursorOffset(-3)
fadeDistanceEditbox:Show(true)

-- Fade Distance mousewheel support
function fadeDistanceEditbox:OnWheelUp(delta)
    local current = tonumber(self:GetText()) or 200
    local newValue = math.min(500, current + 10)
    self:SetText(tostring(newValue))
end
fadeDistanceEditbox:SetHandler("OnWheelUp", fadeDistanceEditbox.OnWheelUp)

function fadeDistanceEditbox:OnWheelDown(delta)
    local current = tonumber(self:GetText()) or 200
    local newValue = math.max(100, current - 10)
    self:SetText(tostring(newValue))
end
fadeDistanceEditbox:SetHandler("OnWheelDown", fadeDistanceEditbox.OnWheelDown)

-- Create Fade Distance slider background bar
local fadeDistanceSliderBg = mainWindow:CreateColorDrawable(0.1, 0.1, 0.1, 0.8, "background")
fadeDistanceSliderBg:SetExtent(200, 6)
fadeDistanceSliderBg:AddAnchor("LEFT", fadeDistanceLabel, "RIGHT", 10, 0)
fadeDistanceSliderBg:AddAnchor("TOP", fadeDistanceEditbox, "BOTTOM", 0, 15)
fadeDistanceSliderBg:Show(true)

-- Create Fade Distance slider
local fadeDistanceSlider = mainWindow:CreateChildWidget("slider", "fadeDistanceSlider", 0, true)
fadeDistanceSlider:SetExtent(200, 20)
fadeDistanceSlider:AddAnchor("CENTER", fadeDistanceSliderBg, 0, 0)
fadeDistanceSlider:SetMinMaxValues(100, 500)
fadeDistanceSlider:SetOrientation(1)

local fadeDistanceThumb = fadeDistanceSlider:CreateChildWidget("button", "fadeDistanceThumb", 0, true)
fadeDistanceThumb:SetExtent(16, 20)
fadeDistanceThumb:EnableDrag(true)
fadeDistanceThumb:Show(true)

local fadeDistanceThumbBg = fadeDistanceThumb:CreateColorDrawable(0.8, 0.8, 0.8, 1.0, "background")
fadeDistanceThumbBg:AddAnchor("TOPLEFT", fadeDistanceThumb, 2, 0)
fadeDistanceThumbBg:AddAnchor("BOTTOMRIGHT", fadeDistanceThumb, -2, 0)

local fadeDistanceThumbHighlight = fadeDistanceThumb:CreateColorDrawable(0.9, 0.9, 0.9, 1.0, "overlay")
fadeDistanceThumbHighlight:AddAnchor("TOPLEFT", fadeDistanceThumb, 2, 0)
fadeDistanceThumbHighlight:SetExtent(12, 2)

fadeDistanceSlider:SetThumbButtonWidget(fadeDistanceThumb)
fadeDistanceSlider:SetFixedThumb(true)
fadeDistanceSlider:SetMinThumbLength(16)
fadeDistanceSlider:SetValue(200, false)
fadeDistanceSlider:Show(true)

function fadeDistanceSlider:OnSliderChanged(value)
    fadeDistanceEditbox:SetText(tostring(math.floor(value)))
end
fadeDistanceSlider:SetHandler("OnSliderChanged", fadeDistanceSlider.OnSliderChanged)

-- Create UIScale label
local uiScaleLabel = mainWindow:CreateChildWidget("label", "uiScaleLabel", 0, true)
uiScaleLabel.style:SetFontSize(15)
uiScaleLabel.style:SetColor(1, 1, 1, 1.0)
uiScaleLabel.style:SetAlign(ALIGN_LEFT)
uiScaleLabel:SetExtent(80, 20)
uiScaleLabel:AddAnchor("TOPLEFT", fadeDistanceLabel, "BOTTOMLEFT", 0, 80)
uiScaleLabel:SetText("UIScale:")
uiScaleLabel:Show(true)

-- Create UIScale editbox background
local uiScaleBg = mainWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")
uiScaleBg:SetExtent(110, 25)
uiScaleBg:AddAnchor("LEFT", uiScaleLabel, "RIGHT", 10, 0)
uiScaleBg:Show(true)

-- Create UIScale editbox
local uiScaleEditbox = mainWindow:CreateChildWidget("editboxmultiline", "uiScaleEditbox", 0, true)
uiScaleEditbox:SetExtent(100, 20)
uiScaleEditbox.style:SetFontSize(14)
uiScaleEditbox:AddAnchor("LEFT", uiScaleLabel, "RIGHT", 10, 0)
uiScaleEditbox.style:SetColorByKey("brown")
uiScaleEditbox:SetMaxTextLength(5)
uiScaleEditbox:SetCursorColorByColorKey("brown")
uiScaleEditbox:SetCursorHeight(-2)
uiScaleEditbox:SetCursorOffset(-3)
uiScaleEditbox:SetText("100")
uiScaleEditbox:Show(true)

-- UIScale mousewheel support (5% steps, 70-240%)
function uiScaleEditbox:OnWheelUp(delta)
    local current = tonumber(self:GetText()) or 100
    local newValue = math.min(240, current + 5)
    self:SetText(tostring(newValue))
end
uiScaleEditbox:SetHandler("OnWheelUp", uiScaleEditbox.OnWheelUp)

function uiScaleEditbox:OnWheelDown(delta)
    local current = tonumber(self:GetText()) or 100
    local newValue = math.max(70, current - 5)
    self:SetText(tostring(newValue))
end
uiScaleEditbox:SetHandler("OnWheelDown", uiScaleEditbox.OnWheelDown)

-- Create UIScale slider background bar
local uiScaleSliderBg = mainWindow:CreateColorDrawable(0.1, 0.1, 0.1, 0.8, "background")
uiScaleSliderBg:SetExtent(200, 6)
uiScaleSliderBg:AddAnchor("LEFT", uiScaleLabel, "RIGHT", 10, 0)
uiScaleSliderBg:AddAnchor("TOP", uiScaleEditbox, "BOTTOM", 0, 15)
uiScaleSliderBg:Show(true)

-- Create UIScale slider
local uiScaleSlider = mainWindow:CreateChildWidget("slider", "uiScaleSlider", 0, true)
uiScaleSlider:SetExtent(200, 20)
uiScaleSlider:AddAnchor("CENTER", uiScaleSliderBg, 0, 0)
uiScaleSlider:SetMinMaxValues(70, 240)
uiScaleSlider:SetValueStep(5)
uiScaleSlider:SetOrientation(1)

local uiScaleThumb = uiScaleSlider:CreateChildWidget("button", "uiScaleThumb", 0, true)
uiScaleThumb:SetExtent(16, 20)
uiScaleThumb:EnableDrag(true)
uiScaleThumb:Show(true)

local uiScaleThumbBg = uiScaleThumb:CreateColorDrawable(0.8, 0.8, 0.8, 1.0, "background")
uiScaleThumbBg:AddAnchor("TOPLEFT", uiScaleThumb, 2, 0)
uiScaleThumbBg:AddAnchor("BOTTOMRIGHT", uiScaleThumb, -2, 0)

local uiScaleThumbHighlight = uiScaleThumb:CreateColorDrawable(0.9, 0.9, 0.9, 1.0, "overlay")
uiScaleThumbHighlight:AddAnchor("TOPLEFT", uiScaleThumb, 2, 0)
uiScaleThumbHighlight:SetExtent(12, 2)

uiScaleSlider:SetThumbButtonWidget(uiScaleThumb)
uiScaleSlider:SetFixedThumb(true)
uiScaleSlider:SetMinThumbLength(16)
uiScaleSlider:SetValue(100, false)
uiScaleSlider:Show(true)

function uiScaleSlider:OnSliderChanged(value)
    uiScaleEditbox:SetText(tostring(math.floor(value)))
end
uiScaleSlider:SetHandler("OnSliderChanged", uiScaleSlider.OnSliderChanged)

-- UIScale note label
local uiScaleNoteLabel = mainWindow:CreateChildWidget("label", "uiScaleNoteLabel", 0, true)
uiScaleNoteLabel.style:SetFontSize(11)
uiScaleNoteLabel.style:SetColor(1, 0.8, 0.2, 1.0)
uiScaleNoteLabel.style:SetAlign(ALIGN_LEFT)
uiScaleNoteLabel:SetExtent(300, 16)
uiScaleNoteLabel:AddAnchor("TOPLEFT", uiScaleSliderBg, "BOTTOMLEFT", 0, 8)
uiScaleNoteLabel:SetText("* Must click Apply in game settings window")
uiScaleNoteLabel:Show(true)

-- Select Entry label (top of right column)
local selectLabel = mainWindow:CreateChildWidget("label", "selectLabel", 0, true)
selectLabel.style:SetFontSize(13)
selectLabel.style:SetColor(1, 1, 1, 1.0)
selectLabel.style:SetAlign(ALIGN_LEFT)
selectLabel:SetExtent(220, 20)
selectLabel:AddAnchor("TOPLEFT", mainWindow, 395, 50)
selectLabel:SetText("Select Nameplate Entry:")
selectLabel:Show(true)

-- Create Color Preview Label (pushed down to make room for combobox)
local previewLabel = mainWindow:CreateChildWidget("label", "previewLabel", 0, true)
previewLabel.style:SetFontSize(15)
previewLabel.style:SetColor(1, 1, 1, 1.0)
previewLabel.style:SetAlign(ALIGN_LEFT)
previewLabel:SetExtent(80, 20)
previewLabel:AddAnchor("TOPLEFT", mainWindow, 395, 115)
previewLabel:SetText("Preview:")
previewLabel:Show(true)

-- Create preview box
local colorPreview = mainWindow:CreateColorDrawable(1, 1, 1, 1.0, "overlay")
colorPreview:SetExtent(200, 40)
colorPreview:AddAnchor("LEFT", previewLabel, "RIGHT", 10, 0)
colorPreview:Show(true)

-- Create preview border
local previewBorder = mainWindow:CreateColorDrawable(0, 0, 0, 1.0, "background")
previewBorder:SetExtent(204, 44)
previewBorder:AddAnchor("CENTER", colorPreview, 0, 0)
previewBorder:Show(true)

-- Create Red label
local redLabel = mainWindow:CreateChildWidget("label", "redLabel", 0, true)
redLabel.style:SetFontSize(15)
redLabel.style:SetColor(1, 1, 1, 1.0)
redLabel.style:SetAlign(ALIGN_LEFT)
redLabel:SetExtent(80, 20)
redLabel:AddAnchor("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, 60)
redLabel:SetText("Red (R):")
redLabel:Show(true)

-- Create Red editbox background
local redBg = mainWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")
redBg:SetExtent(110, 25)
redBg:AddAnchor("LEFT", redLabel, "RIGHT", 10, 0)
redBg:Show(true)

-- Create Red editbox
local redEditbox = mainWindow:CreateChildWidget("editboxmultiline", "redEditbox", 0, true)
redEditbox:SetExtent(100, 20)
redEditbox.style:SetFontSize(14)
redEditbox:AddAnchor("LEFT", redLabel, "RIGHT", 10, 0)
redEditbox.style:SetColorByKey("brown")
redEditbox:SetMaxTextLength(3)
redEditbox:SetCursorColorByColorKey("brown")
redEditbox:SetCursorHeight(-2)
redEditbox:SetCursorOffset(-3)
redEditbox:Show(true)

-- Red mousewheel support
function redEditbox:OnWheelUp(delta)
    local current = tonumber(self:GetText()) or 255
    local newValue = math.min(255, current + 5)
    self:SetText(tostring(newValue))
end
redEditbox:SetHandler("OnWheelUp", redEditbox.OnWheelUp)

function redEditbox:OnWheelDown(delta)
    local current = tonumber(self:GetText()) or 255
    local newValue = math.max(0, current - 5)
    self:SetText(tostring(newValue))
end
redEditbox:SetHandler("OnWheelDown", redEditbox.OnWheelDown)

-- Create Red slider background bar
local redSliderBg = mainWindow:CreateColorDrawable(0.1, 0.1, 0.1, 0.8, "background")
redSliderBg:SetExtent(200, 6)
redSliderBg:AddAnchor("LEFT", redLabel, "RIGHT", 10, 0)
redSliderBg:AddAnchor("TOP", redEditbox, "BOTTOM", 0, 15)
redSliderBg:Show(true)

-- Create Red slider
local redSlider = mainWindow:CreateChildWidget("slider", "redSlider", 0, true)
redSlider:SetExtent(200, 20)
redSlider:AddAnchor("CENTER", redSliderBg, 0, 0)
redSlider:SetMinMaxValues(0, 255)
redSlider:SetOrientation(1)

local redThumb = redSlider:CreateChildWidget("button", "redThumb", 0, true)
redThumb:SetExtent(16, 20)
redThumb:EnableDrag(true)
redThumb:Show(true)

local redThumbBg = redThumb:CreateColorDrawable(0.8, 0.8, 0.8, 1.0, "background")
redThumbBg:AddAnchor("TOPLEFT", redThumb, 2, 0)
redThumbBg:AddAnchor("BOTTOMRIGHT", redThumb, -2, 0)

local redThumbHighlight = redThumb:CreateColorDrawable(0.9, 0.9, 0.9, 1.0, "overlay")
redThumbHighlight:AddAnchor("TOPLEFT", redThumb, 2, 0)
redThumbHighlight:SetExtent(12, 2)

redSlider:SetThumbButtonWidget(redThumb)
redSlider:SetFixedThumb(true)
redSlider:SetMinThumbLength(16)
redSlider:SetValue(255, false)
redSlider:Show(true)

function redSlider:OnSliderChanged(value)
    redEditbox:SetText(tostring(math.floor(value)))
end
redSlider:SetHandler("OnSliderChanged", redSlider.OnSliderChanged)

-- Create Green label
local greenLabel = mainWindow:CreateChildWidget("label", "greenLabel", 0, true)
greenLabel.style:SetFontSize(15)
greenLabel.style:SetColor(1, 1, 1, 1.0)
greenLabel.style:SetAlign(ALIGN_LEFT)
greenLabel:SetExtent(80, 20)
greenLabel:AddAnchor("TOPLEFT", redLabel, "BOTTOMLEFT", 0, 50)
greenLabel:SetText("Green (G):")
greenLabel:Show(true)

-- Create Green editbox background
local greenBg = mainWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")
greenBg:SetExtent(110, 25)
greenBg:AddAnchor("LEFT", greenLabel, "RIGHT", 10, 0)
greenBg:Show(true)

-- Create Green editbox
local greenEditbox = mainWindow:CreateChildWidget("editboxmultiline", "greenEditbox", 0, true)
greenEditbox:SetExtent(100, 20)
greenEditbox.style:SetFontSize(14)
greenEditbox:AddAnchor("LEFT", greenLabel, "RIGHT", 10, 0)
greenEditbox.style:SetColorByKey("brown")
greenEditbox:SetMaxTextLength(3)
greenEditbox:SetCursorColorByColorKey("brown")
greenEditbox:SetCursorHeight(-2)
greenEditbox:SetCursorOffset(-3)
greenEditbox:Show(true)

-- Green mousewheel support
function greenEditbox:OnWheelUp(delta)
    local current = tonumber(self:GetText()) or 255
    local newValue = math.min(255, current + 5)
    self:SetText(tostring(newValue))
end
greenEditbox:SetHandler("OnWheelUp", greenEditbox.OnWheelUp)

function greenEditbox:OnWheelDown(delta)
    local current = tonumber(self:GetText()) or 255
    local newValue = math.max(0, current - 5)
    self:SetText(tostring(newValue))
end
greenEditbox:SetHandler("OnWheelDown", greenEditbox.OnWheelDown)

-- Create Green slider background bar
local greenSliderBg = mainWindow:CreateColorDrawable(0.1, 0.1, 0.1, 0.8, "background")
greenSliderBg:SetExtent(200, 6)
greenSliderBg:AddAnchor("LEFT", greenLabel, "RIGHT", 10, 0)
greenSliderBg:AddAnchor("TOP", greenEditbox, "BOTTOM", 0, 15)
greenSliderBg:Show(true)

-- Create Green slider
local greenSlider = mainWindow:CreateChildWidget("slider", "greenSlider", 0, true)
greenSlider:SetExtent(200, 20)
greenSlider:AddAnchor("CENTER", greenSliderBg, 0, 0)
greenSlider:SetMinMaxValues(0, 255)
greenSlider:SetOrientation(1)

local greenThumb = greenSlider:CreateChildWidget("button", "greenThumb", 0, true)
greenThumb:SetExtent(16, 20)
greenThumb:EnableDrag(true)
greenThumb:Show(true)

local greenThumbBg = greenThumb:CreateColorDrawable(0.8, 0.8, 0.8, 1.0, "background")
greenThumbBg:AddAnchor("TOPLEFT", greenThumb, 2, 0)
greenThumbBg:AddAnchor("BOTTOMRIGHT", greenThumb, -2, 0)

local greenThumbHighlight = greenThumb:CreateColorDrawable(0.9, 0.9, 0.9, 1.0, "overlay")
greenThumbHighlight:AddAnchor("TOPLEFT", greenThumb, 2, 0)
greenThumbHighlight:SetExtent(12, 2)

greenSlider:SetThumbButtonWidget(greenThumb)
greenSlider:SetFixedThumb(true)
greenSlider:SetMinThumbLength(16)
greenSlider:SetValue(255, false)
greenSlider:Show(true)

function greenSlider:OnSliderChanged(value)
    greenEditbox:SetText(tostring(math.floor(value)))
end
greenSlider:SetHandler("OnSliderChanged", greenSlider.OnSliderChanged)

-- Create Blue label
local blueLabel = mainWindow:CreateChildWidget("label", "blueLabel", 0, true)
blueLabel.style:SetFontSize(15)
blueLabel.style:SetColor(1, 1, 1, 1.0)
blueLabel.style:SetAlign(ALIGN_LEFT)
blueLabel:SetExtent(80, 20)
blueLabel:AddAnchor("TOPLEFT", greenLabel, "BOTTOMLEFT", 0, 50)
blueLabel:SetText("Blue (B):")
blueLabel:Show(true)

-- Create Blue editbox background
local blueBg = mainWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")
blueBg:SetExtent(110, 25)
blueBg:AddAnchor("LEFT", blueLabel, "RIGHT", 10, 0)
blueBg:Show(true)

-- Create Blue editbox
local blueEditbox = mainWindow:CreateChildWidget("editboxmultiline", "blueEditbox", 0, true)
blueEditbox:SetExtent(100, 20)
blueEditbox.style:SetFontSize(14)
blueEditbox:AddAnchor("LEFT", blueLabel, "RIGHT", 10, 0)
blueEditbox.style:SetColorByKey("brown")
blueEditbox:SetMaxTextLength(3)
blueEditbox:SetCursorColorByColorKey("brown")
blueEditbox:SetCursorHeight(-2)
blueEditbox:SetCursorOffset(-3)
blueEditbox:Show(true)

-- Blue mousewheel support
function blueEditbox:OnWheelUp(delta)
    local current = tonumber(self:GetText()) or 255
    local newValue = math.min(255, current + 5)
    self:SetText(tostring(newValue))
end
blueEditbox:SetHandler("OnWheelUp", blueEditbox.OnWheelUp)

function blueEditbox:OnWheelDown(delta)
    local current = tonumber(self:GetText()) or 255
    local newValue = math.max(0, current - 5)
    self:SetText(tostring(newValue))
end
blueEditbox:SetHandler("OnWheelDown", blueEditbox.OnWheelDown)

-- Create Blue slider background bar
local blueSliderBg = mainWindow:CreateColorDrawable(0.1, 0.1, 0.1, 0.8, "background")
blueSliderBg:SetExtent(200, 6)
blueSliderBg:AddAnchor("LEFT", blueLabel, "RIGHT", 10, 0)
blueSliderBg:AddAnchor("TOP", blueEditbox, "BOTTOM", 0, 15)
blueSliderBg:Show(true)

-- Create Blue slider
local blueSlider = mainWindow:CreateChildWidget("slider", "blueSlider", 0, true)
blueSlider:SetExtent(200, 20)
blueSlider:AddAnchor("CENTER", blueSliderBg, 0, 0)
blueSlider:SetMinMaxValues(0, 255)
blueSlider:SetOrientation(1)

local blueThumb = blueSlider:CreateChildWidget("button", "blueThumb", 0, true)
blueThumb:SetExtent(16, 20)
blueThumb:EnableDrag(true)
blueThumb:Show(true)

local blueThumbBg = blueThumb:CreateColorDrawable(0.8, 0.8, 0.8, 1.0, "background")
blueThumbBg:AddAnchor("TOPLEFT", blueThumb, 2, 0)
blueThumbBg:AddAnchor("BOTTOMRIGHT", blueThumb, -2, 0)

local blueThumbHighlight = blueThumb:CreateColorDrawable(0.9, 0.9, 0.9, 1.0, "overlay")
blueThumbHighlight:AddAnchor("TOPLEFT", blueThumb, 2, 0)
blueThumbHighlight:SetExtent(12, 2)

blueSlider:SetThumbButtonWidget(blueThumb)
blueSlider:SetFixedThumb(true)
blueSlider:SetMinThumbLength(16)
blueSlider:SetValue(255, false)
blueSlider:Show(true)

function blueSlider:OnSliderChanged(value)
    blueEditbox:SetText(tostring(math.floor(value)))
end
blueSlider:SetHandler("OnSliderChanged", blueSlider.OnSliderChanged)

-- RGB note label
local rgbNoteLabel = mainWindow:CreateChildWidget("label", "rgbNoteLabel", 0, true)
rgbNoteLabel.style:SetFontSize(11)
rgbNoteLabel.style:SetColor(1, 0.8, 0.2, 1.0)
rgbNoteLabel.style:SetAlign(ALIGN_LEFT)
rgbNoteLabel:SetExtent(250, 16)
rgbNoteLabel:AddAnchor("TOPLEFT", blueSliderBg, "BOTTOMLEFT", 0, 8)
rgbNoteLabel:SetText("* Alpha (A) is locked at 255 by default")
rgbNoteLabel:Show(true)

-- Save RGBA color values to file (Alpha locked at 255 for future use)
local function SaveColorToFile()
    local r = tonumber(redEditbox:GetText()) or 255
    local g = tonumber(greenEditbox:GetText()) or 255
    local b = tonumber(blueEditbox:GetText()) or 255
    local a = 255

    -- Clamp values to valid range
    r = math.max(0, math.min(255, r))
    g = math.max(0, math.min(255, g))
    b = math.max(0, math.min(255, b))

    local file = io.open(colorFile, "w")
    if file then
        file:write(string.format("%d,%d,%d,%d", r, g, b, a))
        file:close()
        X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("|cFF00FF00[Nameplate Resizer]|r Color saved: R=%d G=%d B=%d A=%d", r, g, b, a))
    else
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFFF0000[Nameplate Resizer]|r Failed to save color file.")
    end
end

-- Apply Color button
local applyColorBtn = mainWindow:CreateChildWidget("button", "applyColorBtn", 0, true)
applyColorBtn:SetText("Apply Color")
applyColorBtn:SetStyle("text_default")
applyColorBtn:SetExtent(120, 28)
applyColorBtn:AddAnchor("TOPLEFT", rgbNoteLabel, "BOTTOMLEFT", 0, 10)
applyColorBtn:Show(true)

function applyColorBtn:OnClick()
    if selectedEntry == nil then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFFF0000[Nameplate Resizer]|r Please select a nameplate entry first.")
        return
    end
    local r = math.max(0, math.min(255, tonumber(redEditbox:GetText()) or 255))
    local g = math.max(0, math.min(255, tonumber(greenEditbox:GetText()) or 255))
    local b = math.max(0, math.min(255, tonumber(blueEditbox:GetText()) or 255))
    local a = 255
    local success = WriteEntryColor(selectedEntry, r, g, b, a)
    if success then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF00FF00[Nameplate Resizer]|r Color saved! Reload UI to see changes.")
    else
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFFF0000[Nameplate Resizer]|r Failed to write to nametag_color.g.")
    end
end
applyColorBtn:SetHandler("OnClick", applyColorBtn.OnClick)

-- Vsync toggle button - forces a UI reload so color changes appear without restarting
local vsyncState = 1
local vsyncBtn = mainWindow:CreateChildWidget("button", "vsyncBtn", 0, true)
vsyncBtn:SetText("Vsync")
vsyncBtn:SetStyle("text_default")
vsyncBtn:SetExtent(80, 28)
vsyncBtn:AddAnchor("TOPLEFT", applyColorBtn, "TOPRIGHT", 8, 0)
vsyncBtn:Show(true)

function vsyncBtn:OnClick()
    if vsyncState == 1 then
        X2Option:SetConsoleVariable("r_VSync", "1")
    else
        X2Option:SetConsoleVariable("r_VSync", "0")
    end
    vsyncState = (vsyncState % 2) + 1
end
vsyncBtn:SetHandler("OnClick", vsyncBtn.OnClick)

-- Function to update color preview
local function UpdateColorPreview()
    local r = tonumber(redEditbox:GetText()) or 255
    local g = tonumber(greenEditbox:GetText()) or 255
    local b = tonumber(blueEditbox:GetText()) or 255

    -- Convert 0-255 to 0-1 range
    colorPreview:SetColor(r / 255, g / 255, b / 255, 1.0)
end

-- Show or hide all RGB controls (hidden until user selects a dropdown entry)
local function ShowColorControls(show)
    redLabel:Show(show)
    redBg:Show(show)
    redEditbox:Show(show)
    redSliderBg:Show(show)
    redSlider:Show(show)
    greenLabel:Show(show)
    greenBg:Show(show)
    greenEditbox:Show(show)
    greenSliderBg:Show(show)
    greenSlider:Show(show)
    blueLabel:Show(show)
    blueBg:Show(show)
    blueEditbox:Show(show)
    blueSliderBg:Show(show)
    blueSlider:Show(show)
    rgbNoteLabel:Show(show)
    applyColorBtn:Show(show)
    vsyncBtn:Show(show)
end

-- Build combobox options - each handler reads current color from file and populates sliders
local colorOptions = {}
for _, entry in ipairs(nameplateEntries) do
    local entryKey = entry.key
    table.insert(colorOptions, {
        text = entry.label,
        handler = function()
            selectedEntry = entryKey
            local r, g, b, a = ReadEntryColor(entryKey)
            redEditbox:SetText(tostring(r))
            greenEditbox:SetText(tostring(g))
            blueEditbox:SetText(tostring(b))
            redSlider:SetValue(r, false)
            greenSlider:SetValue(g, false)
            blueSlider:SetValue(b, false)
            ShowColorControls(true)
            UpdateColorPreview()
        end
    })
end

CreateComboBox(
    mainWindow,   -- parent
    220,          -- triggerWidth
    22,           -- triggerHeight
    8,            -- maxVisibleOptions
    colorOptions, -- optionsData
    22,           -- optionHeight
    "TOPLEFT",    -- triggerAnchor
    selectLabel,  -- triggerAnchorParent
    0,            -- triggerOffsetX
    25            -- triggerOffsetY (places trigger just below the selectLabel)
)

-- Function to apply settings
local function ApplySettings()
    local width = widthEditbox:GetText() or "170"
    local height = heightEditbox:GetText() or "40"
    local markSize = markSizeEditbox:GetText() or "1"
    local textOffset = textOffsetEditbox:GetText() or "1"
    local fadeDistance = fadeDistanceEditbox:GetText() or "200"
    local r = redEditbox:GetText() or "255"
    local g = greenEditbox:GetText() or "255"
    local b = blueEditbox:GetText() or "255"
    local uiScale = uiScaleEditbox:GetText() or "100"

    -- Trim whitespace
    width = width:match("^%s*(.-)%s*$") or "170"
    height = height:match("^%s*(.-)%s*$") or "40"
    markSize = markSize:match("^%s*(.-)%s*$") or "1"
    textOffset = textOffset:match("^%s*(.-)%s*$") or "1"
    fadeDistance = fadeDistance:match("^%s*(.-)%s*$") or "200"
    r = r:match("^%s*(.-)%s*$") or "255"
    g = g:match("^%s*(.-)%s*$") or "255"
    b = b:match("^%s*(.-)%s*$") or "255"
    uiScale = uiScale:match("^%s*(.-)%s*$") or "100"

    -- Ensure values are not empty
    if width == "" then width = "170" end
    if height == "" then height = "40" end
    if markSize == "" then markSize = "1" end
    if textOffset == "" then textOffset = "1" end
    if fadeDistance == "" then fadeDistance = "200" end
    if r == "" then r = "255" end
    if g == "" then g = "255" end
    if b == "" then b = "255" end
    if uiScale == "" then uiScale = "100" end

    -- Save settings to file
    SaveSettings(width, height, markSize, textOffset, fadeDistance, r, g, b, uiScale)

    -- Apply console variables
    X2Option:SetConsoleVariable("name_tag_hp_width_on_bgmode", width)
    X2Option:SetConsoleVariable("name_tag_hp_height_on_bgmode", height)
    X2Option:SetConsoleVariable("name_tag_mark_size_ratio", markSize)
    X2Option:SetConsoleVariable("name_tag_text_line_offset", textOffset)
    X2Option:SetConsoleVariable("name_tag_fade_out_distance", fadeDistance)

    -- Apply UI Scale (percentage 70-240 converted to float 0.70-2.40)
    X2Option:SetItemFloatValue(OIT_UI_SCALE, (tonumber(uiScale) or 100) / 100)
    X2Option:Save()

    -- Update color preview
    UpdateColorPreview()
end

-- Width editbox text changed handler - auto-save and apply
function widthEditbox:OnTextChanged()
    ApplySettings()
end
widthEditbox:SetHandler("OnTextChanged", widthEditbox.OnTextChanged)

-- Height editbox text changed handler - auto-save and apply
function heightEditbox:OnTextChanged()
    ApplySettings()
end
heightEditbox:SetHandler("OnTextChanged", heightEditbox.OnTextChanged)

-- Mark Size editbox text changed handler - auto-save and apply
function markSizeEditbox:OnTextChanged()
    ApplySettings()
end
markSizeEditbox:SetHandler("OnTextChanged", markSizeEditbox.OnTextChanged)

-- Text Offset editbox text changed handler - auto-save and apply
function textOffsetEditbox:OnTextChanged()
    ApplySettings()
end
textOffsetEditbox:SetHandler("OnTextChanged", textOffsetEditbox.OnTextChanged)

-- Fade Distance editbox text changed handler - auto-save and apply
function fadeDistanceEditbox:OnTextChanged()
    ApplySettings()
end
fadeDistanceEditbox:SetHandler("OnTextChanged", fadeDistanceEditbox.OnTextChanged)

-- Red editbox text changed handler - auto-save and apply
function redEditbox:OnTextChanged()
    ApplySettings()
end
redEditbox:SetHandler("OnTextChanged", redEditbox.OnTextChanged)

-- Green editbox text changed handler - auto-save and apply
function greenEditbox:OnTextChanged()
    ApplySettings()
end
greenEditbox:SetHandler("OnTextChanged", greenEditbox.OnTextChanged)

-- Blue editbox text changed handler - auto-save and apply
function blueEditbox:OnTextChanged()
    ApplySettings()
end
blueEditbox:SetHandler("OnTextChanged", blueEditbox.OnTextChanged)

-- UIScale editbox text changed handler - auto-save and apply
function uiScaleEditbox:OnTextChanged()
    ApplySettings()
end
uiScaleEditbox:SetHandler("OnTextChanged", uiScaleEditbox.OnTextChanged)

-- Load saved settings and apply them
local savedWidth, savedHeight, savedMarkSize, savedTextOffset, savedFadeDistance, savedR, savedG, savedB, savedUiScale = LoadSettings()

widthEditbox:SetText(savedWidth)
heightEditbox:SetText(savedHeight)
markSizeEditbox:SetText(savedMarkSize)
textOffsetEditbox:SetText(savedTextOffset)
fadeDistanceEditbox:SetText(savedFadeDistance)
redEditbox:SetText(savedR)
greenEditbox:SetText(savedG)
blueEditbox:SetText(savedB)
uiScaleEditbox:SetText(savedUiScale)

widthSlider:SetValue(tonumber(savedWidth) or 170, false)
heightSlider:SetValue(tonumber(savedHeight) or 40, false)
markSizeSlider:SetValue(tonumber(savedMarkSize) or 1, false)
textOffsetSlider:SetValue((tonumber(savedTextOffset) or 1) * 2, false)
fadeDistanceSlider:SetValue(tonumber(savedFadeDistance) or 200, false)
redSlider:SetValue(tonumber(savedR) or 255, false)
greenSlider:SetValue(tonumber(savedG) or 255, false)
blueSlider:SetValue(tonumber(savedB) or 255, false)
uiScaleSlider:SetValue(tonumber(savedUiScale) or 100, false)

-- Initial color preview update
UpdateColorPreview()

-- Hide RGB controls until user selects a nameplate entry from the dropdown
ShowColorControls(false)

-- ESC menu toggle function
local function EscMenuToggle()
    mainWindow:Show(not mainWindow:IsVisible())
end

-- Register ESC menu button
X2:AddEscMenuButton(5, 1002, "tgos", "Name Plate Resizer")
ADDON:RegisterContentTriggerFunc(1002, EscMenuToggle)

-- Startup message
X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF00FF00[Nameplate Resizer] Loaded! Check ESC menu.")
