ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)
ADDON:ImportAPI(API_TYPE.PLAYER.id)
ADDON:ImportAPI(API_TYPE.EQUIPMENT.id)
ADDON:ImportAPI(API_TYPE.BAG.id)
ADDON:ImportAPI(API_TYPE.TIME.id)
ADDON:ImportAPI(API_TYPE.MAP.id)

local buttonsTable = {}
local savedPositions = {}
local filePathPos = "RaidSchedulesPos.txt"

local buttonSizeDarkMode = 50
local buttonSizeLightMode = 45

local addonImages = {archeagelogo = "addon/Raidschedules/images/archeagelogo.dds"}

local iconConfigs = {{ name = "archeagelogo", anchor = "TOPLEFT", x = 20, y = 20, width = 45, height = 45 }}

function CreateAddonIcon(parent, imageName, anchorPoint, targetObject, offsetX, offsetY, width, height)
    local icon = parent:CreateIconDrawable("artwork")
    if icon then
        icon:AddAnchor(anchorPoint or "TOPRIGHT", targetObject or parent, offsetX or 0, offsetY or 0)
        icon:SetExtent(width or 45, height or 45)
        icon:ClearAllTextures()
        icon:AddTexture(addonImages[imageName])
        icon:SetVisible(true)
        icon:Show(true)
        return icon
    end
    return nil
end

function CreateAllIcons(parent)
    local createdIcons = {}
    for i, config in ipairs(iconConfigs) do
        createdIcons[config.name] = CreateAddonIcon(
            parent,
            config.name,
            config.anchor,
            parent,
            config.x,
            config.y,
            config.width,
            config.height
        )
    end
    return createdIcons
end

local function calculateDayOfWeek(year, month, day)
    if month < 3 then
        month = month + 12
        year = year - 1
    end
    local k = year % 100
    local j = math.floor(year / 100)
    local dayOfWeek = (day + math.floor((13 * (month + 1)) / 5) + k + math.floor(k / 4) + math.floor(j / 4) + 5 * j) % 7
    return (dayOfWeek + 6) % 7 + 1
end

local function ApplyMouseHandlers(widget, handlers)
    for event, fn in pairs(handlers) do
        widget:SetHandler(event, fn)
    end
end

function GetButtonSkin()
    local color = {
        normal = UIParent:GetFontColor("btn_df"),
        highlight = UIParent:GetFontColor("btn_ov"),
        pushed = UIParent:GetFontColor("btn_on"),
        disabled = UIParent:GetFontColor("btn_dis"),
        active = UIParent:GetFontColor("lime")
    }

    return {
        drawableType = "ninePart",
        path = "ui/common/default.dds",
        coordsKey = "btn",
        autoResize = true,
        fontColor = color,
        fontInset = {
            left = 11,
            right = 11,
            top = 0,
            bottom = 0
        }
    }
end

function table.contains(table, element)
    for _, value in ipairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function AttachIconToLabel(parent, label, iconName, size)
    size = size or 45


    if label.attachedIcon then

        if iconName and eventIcons[iconName] then
            label.attachedIcon:ClearAllTextures()
            label.attachedIcon:AddTexture(eventIcons[iconName])
            label.attachedIcon:SetVisible(true)
        else
            label.attachedIcon:SetVisible(false)
        end
    else
        if iconName and eventIcons[iconName] then
            local icon = parent:CreateIconDrawable("artwork")
            if icon then
                icon:SetExtent(size, size)
                if iconName == "Reset" then
                    icon:AddAnchor("RIGHT", label, "LEFT", -size - 15, 0)
                else
                    icon:AddAnchor("LEFT", label, "LEFT", -size - 10, 0)
                end
                icon:ClearAllTextures()
                icon:AddTexture(eventIcons[iconName])
                icon:SetVisible(true)
                icon:Show(true)
                label.attachedIcon = icon
            end
        end
    end
end

local window = nil
local tdListWindow = nil

local ButtonNames = {
    "Guild Quest", "Login Tracker", "Daily Contracts", "Manastorm Shop", "Castles", "Specimen Dailys",
    "Akasch Eggs", "Akasch Merchants", "Nui Dailys", "Guild Missions", "Family Quest", "Tree+Mamm Dailys",
    "CR", "SGCR", "GR", "Hiram Rift", "JMG", "Whalesong", "Aegis", "Abyss Attack", "Hasla Rift", "Lusca", "Halcy",
    "Red Dragon", "House Quest", "Garden Quest", "Stolen Ayanad Anima", "Wizard's Token", "Mysterious Ore",
    "BSB", "Wonderland Quest", "Reed Daily Quest", "Hereafter Rebellion", "Dungeons", "Festival Stuff"
}

local tdListButtonTable = {}
local selectedButtons = {}
local filePathTDL = "SavedTDListButtons.txt"
local savedDateKey = "savedDate" 

local function UpdateButtonColors(activeButtons, buttonsTable)
    for name, entry in pairs(buttonsTable) do
        local color = (activeButtons[name] == true) and UIParent:GetFontColor("green") or UIParent:GetFontColor("btn_df")
        entry.button:SetTextColor(color[1], color[2], color[3], color[4])
    end
end

local function LoadSavedButtons()
    local savedData = {}
    local file = io.open(filePathTDL, "r")
    if file then
        for line in file:lines() do
            local name, value = line:match("([^=]+)=([^,]+)")
            if name and value then
                if name == savedDateKey then
                    savedData[name] = value
                else
                    savedData[name] = (value == "true")
                end
            end
        end
        file:close()
    end
    return savedData
end

local function SaveSelectedButtons(data)
    local file = io.open(filePathTDL, "w")
    if file then
        for name, value in pairs(data) do
            if name ~= savedDateKey then
                file:write(string.format("%s=%s,\n", name, tostring(value)))
            end
        end
        local serverTimeTable = UIParent:GetServerTimeTable()
        if serverTimeTable then
            local year, month, day = serverTimeTable.year, serverTimeTable.month, serverTimeTable.day
            local currentDate = string.format("%04d-%02d-%02d", year, month, day)
            file:write(string.format("%s=%s,\n", savedDateKey, currentDate)) 
        end
        file:close()
    end
end

local function OpenTDListWindow()
    if tdListWindow and tdListWindow:IsVisible() then
        tdListWindow:Show(false)
    elseif not tdListWindow then
        local windowWidth = window:GetWidth()
        local windowHeight = window:GetHeight()
        local tdListWindowWidth = windowWidth / 2.5
        local tdListWindowHeight = windowHeight / 2 - 2.5

        tdListWindow = CreateEmptyWindow("TDListWindow", "UIParent")
        tdListWindow:SetExtent(tdListWindowWidth, tdListWindowHeight)
        tdListWindow:AddAnchor("TOPLEFT", window, "TOPRIGHT", 5, 0)
        tdListWindow:SetCloseOnEscape(true)

        local background = tdListWindow:CreateColorDrawable(0, 0, 0, 0, "background")
        background:AddAnchor("TOPLEFT", tdListWindow, 0, 0)
        background:AddAnchor("BOTTOMRIGHT", tdListWindow, 0, 0)

        local imageTDLBackground = tdListWindow:CreateImageDrawable(eventIcons["TDLBackground"], "background")
        imageTDLBackground:AddAnchor("TOPLEFT", tdListWindow, 0, 0)
        imageTDLBackground:AddAnchor("BOTTOMRIGHT", tdListWindow, 0, 0)

        tdListWindow:EnableDrag(true)
        tdListWindow:Show(true)

        local buttonWidth = tdListWindowWidth / 3 - 10
        local buttonHeight = 20
        local buttonSpacing = 8
        local startX = 20
        local startY = 40
        local buttonsPerColumn = 12
        local columnSpacing = -15

        local loadedData = LoadSavedButtons()
        local savedDate = loadedData[savedDateKey]
        local serverTimeTable = UIParent:GetServerTimeTable()
        local year, month, day = serverTimeTable.year, serverTimeTable.month, serverTimeTable.day
        local currentDate = string.format("%04d-%02d-%02d", year, month, day)

        if savedDate and savedDate ~= currentDate then
            selectedButtons = {}
            SaveSelectedButtons({})
            loadedData = {}
        end

        selectedButtons = loadedData

        for i, name in ipairs(ButtonNames) do
            local columnIndex = math.ceil(i / buttonsPerColumn)
            local rowIndex = (i - 1) % buttonsPerColumn + 1
            local x = startX + (columnIndex - 1) * (buttonWidth + columnSpacing)
            local y = startY + (rowIndex - 1) * (buttonHeight + buttonSpacing)
            local button = tdListWindow:CreateChildWidget("button", "tdListButton_" .. name, 0, true)
            button:SetExtent(buttonWidth, buttonHeight)
            button:SetText(name)
            button:AddAnchor("TOPLEFT", tdListWindow, x, y)
            button:Show(true)

            if loadedData[name] then
                selectedButtons[name] = true
            end

            button:SetHandler("OnClick", function()
                if selectedButtons[name] then
                    selectedButtons[name] = nil
                else
                    selectedButtons[name] = true
                end
                UpdateButtonColors(selectedButtons, tdListButtonTable)
                SaveSelectedButtons(selectedButtons)
            end)

            tdListButtonTable[name] = { button = button }
        end

        local closeTDListButton = tdListWindow:CreateChildWidget("button", "closeTDListButton", 0, true)
        closeTDListButton:SetText("Close")
        closeTDListButton:SetStyle("text_default")
        closeTDListButton:AddAnchor("BOTTOMLEFT", tdListWindow, 50, -10)
        closeTDListButton:Show(true)
        closeTDListButton:SetHandler("OnClick", function()
            tdListWindow:Show(false)
        end)

        local resetButton = tdListWindow:CreateChildWidget("button", "resetButton", 0, true)
        resetButton:SetText("Reset")
        resetButton:SetStyle("text_default")
        resetButton:AddAnchor("BOTTOMRIGHT", tdListWindow, -50, -10)
        resetButton:Show(true)
        resetButton:SetHandler("OnClick", function()
            selectedButtons = {}
            SaveSelectedButtons({}) 
            UpdateButtonColors(selectedButtons, tdListButtonTable)
        end)

        UpdateButtonColors(selectedButtons, tdListButtonTable)

    elseif tdListWindow then
        tdListWindow:Show(true)
    end
    UpdateButtonColors(selectedButtons, tdListButtonTable)
end


function CreateEventWindow()
    if window then
        return window
    end

    window = CreateEmptyWindow("EventTimerWindow", "UIParent")
    if window then
        window:SetExtent(1200, 850)
        window:AddAnchor("LEFT", "UIParent", 0, 0)
        window:SetCloseOnEscape(true)

        local background = window:CreateColorDrawable(0, 0, 0, 0, "background")
        background:AddAnchor("TOPLEFT", window, 0, 0)
        background:AddAnchor("BOTTOMRIGHT", window, 0, 0)

        local imageBackground = window:CreateImageDrawable(eventIcons["Background"], "background")
        imageBackground:AddAnchor("TOPLEFT", window, 0, 0)
        imageBackground:AddAnchor("BOTTOMRIGHT", window, 0, 0)

        local function OnShow()
            window:SetStartAnimation(true, true)
        end
        window:SetHandler("OnShow", OnShow)
        window:EnableDrag(true)
        function window:OnDragStart()
            self:StartMoving()
            self.moving = true
        end
        window:SetHandler("OnDragStart", window.OnDragStart)
        function window:OnDragStop()
            self:StopMovingOrSizing()
            self.moving = false
        end
        window:SetHandler("OnDragStop", window.OnDragStop)

        local icons = CreateAllIcons(window)

        local titleLabel = window:CreateChildWidget("label", "titleLabel", 0, false)
        titleLabel:SetHeight(30)
        titleLabel.style:SetFontSize(26)
        titleLabel:AddAnchor("TOP", window, -20, 7)
        titleLabel.style:SetAlign(ALIGN_CENTER)
        titleLabel.style:SetColor(128, 0, 0, 255)
        titleLabel:SetText("ArcheRage Events!")
        titleLabel.style:SetOutline(true)

        local resetLabel = window:CreateChildWidget("label", "resetLabel", 0, false)
        resetLabel:SetHeight(30)
        resetLabel.style:SetFontSize(20)
        resetLabel:AddAnchor("TOPRIGHT", window, -160, 17)
        resetLabel.style:SetAlign(ALIGN_RIGHT)
        resetLabel.style:SetColorByKey("green")
        resetLabel:SetText("Reset:")
        resetLabel.style:SetOutline(true)

        local resetTimerText = window:CreateChildWidget("label", "resetTimerText", 0, false)
        resetTimerText:SetHeight(30)
        resetTimerText.style:SetFontSize(20)
        resetTimerText:AddAnchor("LEFT", resetLabel, "RIGHT", 20, 0)
        resetTimerText.style:SetAlign(ALIGN_LEFT)
        resetTimerText.style:SetColorByKey("black")
        resetTimerText.style:SetOutline(true)

        AttachIconToLabel(window, resetLabel, "Reset", 45)

        local gameEventsLabel = window:CreateChildWidget("label", "gameEventsLabel", 0, false)
        gameEventsLabel:SetHeight(30)
        gameEventsLabel.style:SetFontSize(22)
        gameEventsLabel:AddAnchor("TOP", window, -15, 55)
        gameEventsLabel.style:SetAlign(ALIGN_CENTER)
        gameEventsLabel.style:SetColor(0, 0, 255, 255)
        gameEventsLabel:SetText("Game Events:")
        gameEventsLabel.style:SetOutline(true)

        local gameEventsTexts = {}
        for i = 1, 4 do
            gameEventsTexts[i] = window:CreateChildWidget("label", "gameEventsText_" .. i, 0, false)
            gameEventsTexts[i]:SetHeight(30)
            gameEventsTexts[i].style:SetFontSize(16)
            gameEventsTexts[i]:AddAnchor("TOPLEFT", window, 70 + (i - 1) * 305, 105)
            gameEventsTexts[i].style:SetAlign(ALIGN_LEFT)
            gameEventsTexts[i].style:SetColor(255, 255, 0, 255)
            gameEventsTexts[i].style:SetOutline(true)
        end

        local serverEventsLabel = window:CreateChildWidget("label", "serverEventsLabel", 0, false)
        serverEventsLabel:SetHeight(20)
        serverEventsLabel.style:SetFontSize(20)
        serverEventsLabel:AddAnchor("TOP", window, -20, 165)
        serverEventsLabel.style:SetAlign(ALIGN_CENTER)
        serverEventsLabel.style:SetColor(0, 0, 255, 255)
        serverEventsLabel.style:SetOutline(true)
        serverEventsLabel:SetText("Server Events:")
        serverEventsLabel.style:SetOutline(true)

        local serverEventsTexts = {}
        for i = 1, 8 do
            serverEventsTexts[i] = window:CreateChildWidget("label", "serverEventsText_" .. i, 0, false)
            serverEventsTexts[i]:SetHeight(30)
            serverEventsTexts[i].style:SetFontSize(16)
            serverEventsTexts[i]:AddAnchor("TOPLEFT", window, 70, 225 + (i - 1) * 45)
            serverEventsTexts[i].style:SetAlign(ALIGN_LEFT)
            serverEventsTexts[i].style:SetColor(255, 255, 0, 255)
            serverEventsTexts[i].style:SetOutline(true)
        end

        for i = 9, 16 do
            serverEventsTexts[i] = window:CreateChildWidget("label", "serverEventsText_" .. i, 0, false)
            serverEventsTexts[i]:SetHeight(30)
            serverEventsTexts[i].style:SetFontSize(16)
            serverEventsTexts[i]:AddAnchor("TOPLEFT", window, 670, 225 + (i - 9) * 45)
            serverEventsTexts[i].style:SetAlign(ALIGN_LEFT)
            serverEventsTexts[i].style:SetColor(255, 255, 0, 255)
            serverEventsTexts[i].style:SetOutline(true)
        end

        local zoneEventsLabel = window:CreateChildWidget("label", "zoneEventsLabel", 0, false)
        zoneEventsLabel:SetHeight(30)
        zoneEventsLabel.style:SetFontSize(20)
        zoneEventsLabel:AddAnchor("TOP", window, -15, 620)
        zoneEventsLabel.style:SetAlign(ALIGN_CENTER)
        zoneEventsLabel.style:SetColor(0, 0, 255, 255)
        zoneEventsLabel:SetText("Zone Events:")
        zoneEventsLabel.style:SetOutline(true)

        local zoneEventsTexts = {}
        for i = 1, 3 do
            zoneEventsTexts[i] = window:CreateChildWidget("label", "zoneEventsText_" .. i, 0, false)
            zoneEventsTexts[i]:SetHeight(30)
            zoneEventsTexts[i].style:SetFontSize(16)
            zoneEventsTexts[i]:AddAnchor("TOPLEFT", window, 70, 680 + (i - 1) * 35)
            zoneEventsTexts[i].style:SetAlign(ALIGN_LEFT)
            zoneEventsTexts[i].style:SetColor(255, 255, 0, 255)
            zoneEventsTexts[i].style:SetOutline(true)
        end

        for i = 4, 5 do
            zoneEventsTexts[i] = window:CreateChildWidget("label", "zoneEventsText_" .. i, 0, false)
            zoneEventsTexts[i]:SetHeight(30)
            zoneEventsTexts[i].style:SetFontSize(16)
            zoneEventsTexts[i]:AddAnchor("TOPLEFT", window, 670, 680 + (i - 4) * 35)
            zoneEventsTexts[i].style:SetAlign(ALIGN_LEFT)
            zoneEventsTexts[i].style:SetColor(255, 255, 0, 255)
            zoneEventsTexts[i].style:SetOutline(true)
        end

        function formatTime(seconds)
            local hours = math.floor(seconds / 3600)
            local minutes = math.floor((seconds % 3600) / 60)
            local secondsRemaining = seconds % 60

            if hours > 0 then
                return string.format("[%02d:%02d:%02d]", hours, minutes, secondsRemaining)
            elseif minutes > 0 then
                return string.format("[%02d:%02d]", minutes, secondsRemaining)
            else
                return string.format("[%02d s]", secondsRemaining)
            end
        end

        function formatResetTime(seconds)
            local hours = math.floor(seconds / 3600)
            local minutes = math.floor((seconds % 3600) / 60)
            local secondsRemaining = seconds % 60
        
            if hours > 0 then
                return string.format("[%02d:%02d]", hours, minutes)
            elseif minutes > 0 then
                return string.format("[%02d:%02d]", minutes, secondsRemaining)
            else
                return string.format("[%02d s]", secondsRemaining)
            end
        end

        function getZoneState(zoneStateInfo)
            local conflictState = zoneStateInfo.conflictState
            if conflictState >= 0 and conflictState <= 4 then
                return "<Crisis> " .. (conflictState + 1), nil
            elseif conflictState == 5 then
                return "<Conflict>", zoneStateInfo.remainTime
            elseif conflictState == 6 then
                return "<War>", zoneStateInfo.remainTime
            elseif conflictState == 7 then
                return "<Peace>", zoneStateInfo.remainTime
            else
                return "<Unknown>", nil
            end
        end

        function window:UpdateResetTimer()
            local serverTimeTable = UIParent:GetServerTimeTable()
            if serverTimeTable then
                local year, month, day, hour, minute, second = serverTimeTable.year, serverTimeTable.month, serverTimeTable.day, serverTimeTable.hour, serverTimeTable.minute, serverTimeTable.second
                local currentServerTime = hour * 3600 + minute * 60 + second
                local timeUntilReset = (24 * 3600) - currentServerTime

                resetTimerText:SetText(formatResetTime(timeUntilReset))
                resetTimerText.style:SetColorByKey("black")
            end
        end

        function window:UpdateZoneEvents()
            local zoneEventsGrouped = {}
            local zoneEventOrder = {}

            for _, zoneId in ipairs(zoneIds) do
                local zoneStateInfo = X2Map:GetZoneStateInfoByZoneId(zoneId)
                if zoneStateInfo and zoneStateInfo.zoneName then
                    local zoneName = zoneStateInfo.zoneName:match("^%S+")
                    local state, remainTime = getZoneState(zoneStateInfo)
                    local message = zoneName .. ": " .. state
                    if remainTime and remainTime > 0 then
                        message = message .. " " .. formatTime(remainTime)
                    end

                    if zoneEventsGrouped[zoneStateInfo.conflictState] then
                        table.insert(zoneEventsGrouped[zoneStateInfo.conflictState], message)
                    else
                        zoneEventsGrouped[zoneStateInfo.conflictState] = {message}
                        table.insert(zoneEventOrder, zoneStateInfo.conflictState)
                    end
                else
                    local message = "Zone " .. zoneId .. " not found."
                    if zoneEventsGrouped["notFound"] then
                        table.insert(zoneEventsGrouped["notFound"], message)
                    else
                        zoneEventsGrouped["notFound"] = {message}
                        table.insert(zoneEventOrder, "notFound")
                    end
                end
            end

            table.sort(zoneEventOrder, function(a, b)
if a == "notFound" then return false
                elseif b == "notFound" then return true
                else return a > b end
            end)

            local zoneLineIndex = 1
            local priorityOrder = {6, 5, 4, 3, 2, 1, 0, 7}

            for _, priority in ipairs(priorityOrder) do
                local messages = zoneEventsGrouped[priority]
                if messages then
                    for _, message in ipairs(messages) do
                        if priority == 6 then
                            zoneEventsTexts[zoneLineIndex].style:SetColor(255, 0, 0, 255)
                        elseif priority == 7 then
                            zoneEventsTexts[zoneLineIndex].style:SetColor(0, 255, 0, 255)
                        elseif priority == 5 then
                            zoneEventsTexts[zoneLineIndex].style:SetColor(255, 0, 255, 255)
                        elseif priority >= 0 and priority <= 4 then
                            zoneEventsTexts[zoneLineIndex].style:SetColor(255, 255, 0, 255)
                        elseif priority == "notFound" then
                            zoneEventsTexts[zoneLineIndex].style:SetColor(255, 255, 255, 255)
                        end
                        zoneEventsTexts[zoneLineIndex]:SetText(message)

                        local zoneName = message:match("^([^:]+)")
                        if zoneName then
                            AttachIconToLabel(window, zoneEventsTexts[zoneLineIndex], zoneName, 45)
                        end

                        zoneLineIndex = zoneLineIndex + 1
                        if zoneLineIndex > 5 then
                            break
                        end
                    end
                end
                if zoneLineIndex > 5 then
                    break
                end
            end
        end

        function window:UpdateEventTimes()
            self:UpdateResetTimer()
            local eventList = {}

            local isAM, currentHour, currentMinute = X2Time:GetGameTime()
            currentMinute = math.floor(currentMinute)
            local currentGameMinutes = (currentHour * 60) + currentMinute
            if not isAM then
                currentGameMinutes = currentGameMinutes + 720
            end

            for eventName, eventData in pairs(gameEvents) do
                local EventTime = (eventData.startHour * 60) + eventData.Minute + (eventData.isAM and 0 or 720)
                local timeUntilEvent = EventTime - currentGameMinutes
                timeUntilEvent = timeUntilEvent / 6

                if timeUntilEvent >= 0 then
                    local hoursUntilEnd = math.floor(timeUntilEvent / 60)
                    local minutesUntilEnd = timeUntilEvent % 60
                    table.insert(eventList, {
                        name = eventName,
                        time = string.format("[%02d:%02d]", hoursUntilEnd, minutesUntilEnd),
                        remaining = timeUntilEvent,
                        isServerEvent = false,
                        Time = EventTime
                    })
                else
                    local hoursRemaining = math.floor(timeUntilEvent / 60)
                    local minutesRemaining = timeUntilEvent % 60
                    hoursRemaining = hoursRemaining + 4
                    if hoursRemaining < 0 then
                        hoursRemaining = 0
                    end
                    table.insert(eventList, {
                        name = eventName,
                        time = string.format("[%02d:%02d]", hoursRemaining, minutesRemaining),
                        remaining = hoursRemaining * 60 + minutesRemaining,
                        isServerEvent = false,
                        Time = EventTime
                    })

                    if currentGameMinutes <= EventTime + 180 then
                        table.insert(eventList, {
                            name = eventName,
                            time = "<Ongoing>",
                            remaining = 0,
                            isServerEvent = false,
                            Time = EventTime
                        })
                    end
                end
            end

            local serverTimeTable = UIParent:GetServerTimeTable()
            if serverTimeTable then
                local year, month, day, hour, minute, second = serverTimeTable.year, serverTimeTable.month, serverTimeTable.day, serverTimeTable.hour, serverTimeTable.minute, serverTimeTable.second
                local dayOfWeek = calculateDayOfWeek(year, month, day)
                local currentServerTime = hour * 3600 + minute * 60 + second

                local serverEventsGrouped = {}
                local eventOrder = {}
                local eventFirstOccurrence = {}

                for eventName, eventData in pairs(serverEvents) do
                    local eventTimes = {}
                    local ongoingEventFound = false
                    local firstOccurrenceProcessed = false
                    local firstOccurrenceTimeUntil = nil

                    for _, event in ipairs(eventData) do
                        if table.contains(event.days, dayOfWeek) then
                            for _, timeData in ipairs(event.times) do
                                local EventTime = timeData.hour * 3600 + (timeData.Minute or 0) * 60 + (timeData.Seconde or 0)
                                local timeUntilEvent = EventTime - currentServerTime
                                local EventDuration = timeData.Duration * 60

                                if currentServerTime >= EventTime and currentServerTime <= EventTime + EventDuration then
                                    ongoingEventFound = true
                                    local remainingTime = EventTime + EventDuration - currentServerTime
                                    local hoursRemaining = math.floor(remainingTime / 3600)
                                    local minutesRemaining = math.floor((remainingTime % 3600) / 60)
                                    local secondsRemaining = remainingTime % 60

                                    if hoursRemaining > 0 then
                                        table.insert(eventTimes, string.format("<Ongoing> [>%02d:%02d:%02d<]", hoursRemaining, minutesRemaining, secondsRemaining))
                                    elseif minutesRemaining > 0 then
                                        table.insert(eventTimes, string.format("<Ongoing> [>%02d:%02d<]", minutesRemaining, secondsRemaining))
                                    else
                                        table.insert(eventTimes, string.format("<Ongoing> [>%02d s<]", secondsRemaining))
                                    end
                                    break
                                elseif timeUntilEvent >= 0 and not ongoingEventFound then
                                    if not firstOccurrenceProcessed then
                                        if firstOccurrenceTimeUntil == nil or timeUntilEvent < firstOccurrenceTimeUntil then
                                            firstOccurrenceTimeUntil = timeUntilEvent
                                        end
                                    end

                                    local hoursUntilEvent = math.floor(timeUntilEvent / 3600)
                                    local minutesUntilEvent = math.floor((timeUntilEvent % 3600) / 60)
                                    local secondsUntilEvent = timeUntilEvent % 60

                                    if not firstOccurrenceProcessed and not ongoingEventFound then
                                        if hoursUntilEvent > 0 then
                                            table.insert(eventTimes, string.format("[%02d:%02d:%02d]", hoursUntilEvent, minutesUntilEvent, secondsUntilEvent))
                                        elseif minutesUntilEvent > 0 then
                                            table.insert(eventTimes, string.format("[%02d:%02d]", minutesUntilEvent, secondsUntilEvent))
                                        else
                                            table.insert(eventTimes, string.format("[%02d s]", secondsUntilEvent))
                                        end
                                        firstOccurrenceProcessed = true
                                    else
                                        table.insert(eventTimes, string.format("[%02d:%02d]", hoursUntilEvent, minutesUntilEvent))
                                    end
                                end
                            end
                        end
                    end

                    if #eventTimes > 0 then
                        if serverEventsGrouped[eventName] then
                            serverEventsGrouped[eventName] = eventTimes
                        else
                            serverEventsGrouped[eventName] = eventTimes
                            table.insert(eventOrder, eventName)
                            eventFirstOccurrence[eventName] = firstOccurrenceTimeUntil or eventData[1].times[1].hour * 3600 + (eventData[1].times[1].Minute or 0) * 60 + (eventData[1].times[1].Seconde or 0) + dayOfWeek * 86400
                        end
                    end
                end

                local serverEventList = {}
                for _, eventName in ipairs(eventOrder) do
                    table.insert(serverEventList, {
                        name = eventName,
                        times = serverEventsGrouped[eventName],
                        firstOccurrence = eventFirstOccurrence[eventName],
                        ongoing = string.find(table.concat(serverEventsGrouped[eventName], ", "), "<Ongoing>")
                    })
                end

                table.sort(serverEventList, function(a, b)
                    if a.ongoing and not b.ongoing then
                        return true
                    elseif not a.ongoing and b.ongoing then
                        return false
                    else
                        return a.firstOccurrence < b.firstOccurrence
                    end
                end)

                local serverLineIndex = 1
                for _, event in ipairs(serverEventList) do
                    local timeString = ""
                    local displayedTimes = {}
                    local displayedCount = 0

                    for _, time in ipairs(event.times) do
                        if displayedCount < 3 then
                            table.insert(displayedTimes, time)
                            displayedCount = displayedCount + 1
                        end
                    end

                    timeString = table.concat(displayedTimes, ", ")

                    if string.find(timeString, "<Ongoing>") then
                        serverEventsTexts[serverLineIndex].style:SetColor(0, 255, 0, 255)
                    else
                        serverEventsTexts[serverLineIndex].style:SetColor(255, 255, 0, 255)
                    end

                    serverEventsTexts[serverLineIndex]:SetText(string.format("%s: %s", event.name, timeString))

                    AttachIconToLabel(window, serverEventsTexts[serverLineIndex], event.name, 45)

                    serverLineIndex = serverLineIndex + 1
                    if serverLineIndex > 16 then
                        break
                    end
                end
                for i = serverLineIndex, 16 do
                    serverEventsTexts[i]:SetText("")
                    AttachIconToLabel(window, serverEventsTexts[i], nil, 45)
                end
            end

            table.sort(eventList, function(a, b)
                if a.time == "<Ongoing>" and b.time ~= "<Ongoing>" then
                    return true
                elseif a.time ~= "<Ongoing>" and b.time == "<Ongoing>" then
                    return false
                else
                    return a.remaining < b.remaining
                end
            end)

            local gameEventsIndex = 1
            for _, event in ipairs(eventList) do
                if not event.isServerEvent then
                    if gameEventsIndex <= #gameEventsTexts then
                        if event.time == "<Ongoing>" then
                            gameEventsTexts[gameEventsIndex].style:SetColor(0, 255, 0, 255)
                        else
                            gameEventsTexts[gameEventsIndex].style:SetColor(255, 255, 0, 255)
                        end
                        gameEventsTexts[gameEventsIndex]:SetText(string.format("%s: %s", event.name, event.time))

                        AttachIconToLabel(window, gameEventsTexts[gameEventsIndex], event.name, 45)

                        gameEventsIndex = gameEventsIndex + 1
                    else
                        break
                    end
                end
            end
            window:UpdateZoneEvents()
        end

        window:SetHandler("OnUpdate", window.UpdateEventTimes)
        local closeButton = window:CreateChildWidget("button", "closeButton", 0, true)
        closeButton:SetText("Close")
        closeButton:SetStyle("text_default")
        closeButton:AddAnchor("BOTTOMLEFT", window, 200, -10)
        closeButton:Show(true)
        function closeButton:OnClick()
            window:Show(false)
        end
        closeButton:SetHandler("OnClick", closeButton.OnClick)

        local TDListButton = window:CreateChildWidget("button", "TDListButton", 0, true)
        TDListButton:SetText("TD List")
        TDListButton:SetStyle("text_default")
        TDListButton:AddAnchor("BOTTOMRIGHT", window, -200, -10)
        TDListButton:Show(true)
        TDListButton:SetHandler("OnClick", OpenTDListWindow)

        window:Show(true)
        window:UpdateEventTimes()
    end
    return window
end

local function ToggleEventWindow()
    if not window then
        CreateEventWindow()
    else
        if window:IsVisible() then
            window:Show(false)
        else
            window:Show(true)
            if window.UpdateEventTimes then
                window:UpdateEventTimes()
            end
        end
    end
end

local function LoadSavedPositions()
    local file = io.open(filePathPos, "r")
    if file then
        for line in file:lines() do
            local name, x, y = line:match("([^,]+),(%d+),(%d+)")
            if name and x and y then
                savedPositions[name] = { x = tonumber(x), y = tonumber(y) }
            end
        end
        file:close()
    end
end

local function SaveButtonPosition(name, x, y)
    savedPositions[name] = { x = x, y = y }
    local file = io.open(filePathPos, "w")
    if file then
        for buttonName, pos in pairs(savedPositions) do
            file:write(string.format("%s,%d,%d\n", buttonName, pos.x, pos.y))
        end
        file:close()
    end
end

local function GetUIScaleFactor()
    return UIParent:GetUIScale() or 1.0
end

function isUserDarkMode() 
    local isDarkMode = false
    local commonFilePath = "../Documents/Addon/ui/common/default.g"
    local commonFile = io.open(commonFilePath, "r")
    if not commonFile then
        return isDarkMode
    end

    local line
    for i = 1, 6 do
        line = commonFile:read("*l")
        if not line then break end
    end
    commonFile:close()

    if line then
        if line:find("bg_01%s*%(%s*15,%s*22,%s*29,%s*255%s*%)") then
            isDarkMode = true
        end
    end
    return isDarkMode
end

function CreateToggleButton()
    if ToggleButton then return end

    local ToggleButton = UIParent:CreateWidget("button", "RaidSchedulesToggle", "UIParent")
    
    local isDarkMode = isUserDarkMode()
    local currentButtonSize = isDarkMode and buttonSizeDarkMode or buttonSizeLightMode
    local iconPrefix = isDarkMode and "Main" or "icon-original"

    ToggleButton:SetExtent(currentButtonSize, currentButtonSize)
    ToggleButton:SetText("")
    ToggleButton:Show(true)
    ToggleButton:EnableDrag(true)
    
    if savedPositions["ToggleButton"] then
        local uiScale = GetUIScaleFactor()
        local scaledX = savedPositions["ToggleButton"].x / uiScale
        local scaledY = savedPositions["ToggleButton"].y / uiScale
        ToggleButton:AddAnchor("TOPLEFT", "UIParent", scaledX, scaledY)
    else
        ToggleButton:AddAnchor("CENTER", "UIParent", 0, 0)
    end

    local iconOverlay = ToggleButton:CreateIconDrawable("artwork")
    iconOverlay:SetExtent(currentButtonSize, currentButtonSize)
    iconOverlay:AddAnchor("CENTER", ToggleButton, 0, 0)
    iconOverlay:SetVisible(true)
    iconOverlay:AddTexture("Addon/RaidSchedules/images/" .. iconPrefix .. ".dds")
    ToggleButton.iconOverlay = iconOverlay    

    local hoverOverlay = ToggleButton:CreateIconDrawable("artwork")
    hoverOverlay:AddTexture("Addon/RaidSchedules/images/" .. iconPrefix .. "_hover.dds")
    hoverOverlay:SetExtent(currentButtonSize, currentButtonSize)
    hoverOverlay:AddAnchor("CENTER", ToggleButton, 0, 0) 
    hoverOverlay:SetVisible(false) 
    ToggleButton.hoverOverlay = hoverOverlay

    local OnClicOverlay = ToggleButton:CreateIconDrawable("artwork")
    OnClicOverlay:AddTexture("Addon/RaidSchedules/images/" .. iconPrefix .. "_click.dds")
    OnClicOverlay:SetExtent(currentButtonSize, currentButtonSize)
    OnClicOverlay:AddAnchor("CENTER", ToggleButton, 0, 0) 
    OnClicOverlay:SetVisible(false) 
    ToggleButton.OnClicOverlay = OnClicOverlay

    local Tooltip = ToggleButton:CreateChildWidget("label", "Tooltip", 0, true)
    Tooltip:SetHeight(30)
    Tooltip:SetAutoResize(true)
    local Tooltipbackground = Tooltip:CreateNinePartDrawable("ui/common/hud.dds", "background")
    Tooltipbackground:SetCoords(733, 169, 14, 15) 
    Tooltipbackground:SetInset(7, 7, 6, 7)
    Tooltipbackground:AddAnchor("TOPLEFT", Tooltip, -10, 0)
    Tooltipbackground:AddAnchor("BOTTOMRIGHT", Tooltip, 10, 0)
    Tooltip:SetText("Event Times")
    Tooltip.style:SetAlign(ALIGN_CENTER)
    Tooltip.style:SetColorByKey("brown")
    Tooltip.style:SetFontSize(12) 
    Tooltip:AddAnchor("TOPLEFT", ToggleButton, -20, -30)
    Tooltip:Show(false)
    ToggleButton.Tooltip = Tooltip    

    local mouseHandlers = {
        OnEnter = function(self)
            if self.hoverOverlay then
                self.hoverOverlay:SetVisible(true)
                self.iconOverlay:SetVisible(false) 
            end    
            if self.Tooltip then 
                self.Tooltip:Show(true)
            end                     
        end,
        OnLeave = function(self)
            if self.hoverOverlay then
                self.hoverOverlay:SetVisible(false)
                self.OnClicOverlay:SetVisible(false) 
                self.iconOverlay:SetVisible(true)  
            end    
            if self.Tooltip then 
                self.Tooltip:Show(false)
            end                            
        end,
    }

    ApplyMouseHandlers(ToggleButton, mouseHandlers) 

    function ToggleButton:OnMouseDown()
        if self.OnClicOverlay then
            self.OnClicOverlay:SetVisible(true)
            self.hoverOverlay:SetVisible(false) 
        end    
    end
    ToggleButton:SetHandler("OnMouseDown", ToggleButton.OnMouseDown)

    function ToggleButton:OnMouseUp()
        if self.OnClicOverlay then
            self.OnClicOverlay:SetVisible(false) 
            self.hoverOverlay:SetVisible(true) 
        end    
    end
    ToggleButton:SetHandler("OnMouseUp", ToggleButton.OnMouseUp)      

    function ToggleButton:OnClick()
        ToggleEventWindow()
    end
    ToggleButton:SetHandler("OnClick", ToggleButton.OnClick)

    function ToggleButton:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    ToggleButton:SetHandler("OnDragStart", ToggleButton.OnDragStart)

    function ToggleButton:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
        local correctedX, correctedY = self:CorrectOffsetByScreen()
        SaveButtonPosition("ToggleButton", correctedX, correctedY)
    end
    ToggleButton:SetHandler("OnDragStop", ToggleButton.OnDragStop)
end

local function EnteredWorld()
    LoadSavedPositions()
    CreateToggleButton()
end
UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)