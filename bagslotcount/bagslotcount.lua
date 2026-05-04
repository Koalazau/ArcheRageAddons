-- Bag Slot Counter Addon
-- Displays empty bag slot count on screen
--[[ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.BAG.id)
ADDON:ImportAPI(API_TYPE.SOUND.id)--]]

-- Constants
local BAG_SIZE = 150
local BAG_ID = 0
local WarningSlots = 12

-- State variables
local emptySlots = 0
local displayX = 0
local displayY = 0
local displayEnabled = true
local hasPlayedWarning = false  -- Track if warning sound has been played

-- File path for saving settings
local settingsFilePath = "..\\Documents\\Addon\\bagslotcount\\settings.txt"

-- Load settings from file
local function LoadSettings()
    local file = io.open(settingsFilePath, "r")
    if not file then return end

    local content = file:read("*all")
    file:close()

    local x, y, enabled = content:match("([%d%-]+),([%d%-]+),(%d)")
    if x and y and enabled then
        displayX = tonumber(x) or 0
        displayY = tonumber(y) or 0
        displayEnabled = (tonumber(enabled) == 1)
    end
end

-- Function to save settings to file
local function SaveSettings()
    local file = io.open(settingsFilePath, "w")
    if file then
        local enabledValue = displayEnabled and 1 or 0
        file:write(string.format("%d,%d,%d", displayX, displayY, enabledValue))
        file:close()
    end
end

-- Load settings on startup
LoadSettings()

-- Create window for on-screen display
local displayAnchor = CreateEmptyWindow("bagSlotDisplayAnchor", "UIParent")
displayAnchor:Show(true)
displayAnchor:SetExtent(200, 50)

-- Create label for displaying bag slot count
local displayLabel = displayAnchor:CreateChildWidget("label", "bagSlotLabel", 0, true)
displayLabel:Show(true)
displayLabel.style:SetFontSize(40)
displayLabel.style:SetColor(0, 1, 0, 1.0)  -- Green by default
displayLabel.style:SetOutline(true)
displayLabel.style:SetAlign(ALIGN_CENTER)
displayLabel:SetExtent(200, 50)
displayLabel:AddAnchor("CENTER", displayAnchor, 0, 0)

-- Scan bag slots and count empty ones
local function ScanBagSlots()
    local count = 0
    for slot = 1, BAG_SIZE do
        if not X2Bag:GetBagItemInfo(BAG_ID, slot) then
            count = count + 1
        end
    end
    emptySlots = count
end


-- Update the on-screen display
local function UpdateDisplay()
    if not displayEnabled then
        displayLabel:Show(false)
        return
    end

    ScanBagSlots()

    displayAnchor:AddAnchor("CENTER", "UIParent", displayX, displayY)
    displayLabel:SetText(tostring(emptySlots))

    -- Red when <= 12, green otherwise
    if emptySlots <= WarningSlots then
        displayLabel.style:SetColor(1, 0, 0, 1.0) -- Red
        if not hasPlayedWarning then
            X2Sound:PlayUISound("event_nation_independence")
            hasPlayedWarning = true
        end
    else
        displayLabel.style:SetColor(0, 1, 0, 1.0) -- Green
        hasPlayedWarning = false  -- Reset when back to safe
    end

    displayLabel:Show(true)
end

-- OnUpdate handler with timer to reduce load
local timePassed = 0
function displayAnchor:OnUpdate(dt)
    timePassed = timePassed + dt
    if timePassed > 1000 then 
        UpdateDisplay()
        timePassed = 0
       -- X2Chat:DispatchChatMessage(CMF_SYSTEM, "Counter Test")
    end
end

displayAnchor:SetHandler("OnUpdate", displayAnchor.OnUpdate)

-- Chat event listener for movement commands
local chatBagSlotEventListenerEvents = {
    CHAT_MESSAGE = function(channel, relation, name, message, info)
        if name ~= X2Unit:UnitName("player") or string.sub(message, 1, 1) ~= "!" then
            return
        end

        local cmd = string.match(message, "!(%w+)")
        if cmd ~= "bagslots" and cmd ~= "bags" then
            return
        end

        local direction = string.match(message, "!%w+%s+(%w+)")
        local amount = tonumber(string.match(message, "!%w+%s+%w+%s+(%d+)")) or 50

        if direction == "up" then
            displayY = displayY - amount
        elseif direction == "down" then
            displayY = displayY + amount
        elseif direction == "left" then
            displayX = displayX - amount
        elseif direction == "right" then
            displayX = displayX + amount
        else
            return
        end

        SaveSettings()
        X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("|cFF35CAEEPosition: |cFFFFD700%d, %d", displayX, displayY))
    end
}

-- Register chat event listener
local chatEventListener = CreateEmptyWindow("chatEventListenerBagSlot", "UIParent")
chatEventListener:Show(false)
chatEventListener:SetHandler("OnEvent", function(this, event, ...)
    chatBagSlotEventListenerEvents[event](...)
end)

for event, _ in pairs(chatBagSlotEventListenerEvents) do
    chatEventListener:RegisterEvent(event)
end

-- Startup message on world entry
UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, function()
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF00FF00Bag Slot Counter |cFFFFFFFFaddon loaded!")
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFFFFFFFMove with: |cFFFFD700!bags up/down/left/right [amount]")
end)