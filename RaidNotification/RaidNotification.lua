ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.STATUS_BAR)

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

local RaidNotificationWindow
local timeUpdater = CreateEmptyWindow("timeUpdater", "UIParent")
timeUpdater:Show(true)
local counter = 0
local windowTimers = {}
local eventCooldowns = {}
local currentEvent = nil
local buttonsTable = {}
local windowCount = 1
local notifiedEvents = {}

local function showRaidNotificationWindow(eventName)
    if not notifiedEvents[eventName] then
        local window = CreateEmptyWindow("RaidNotificationWindow" .. windowCount, "UIParent")
        if window then

            window:SetExtent(450, 150)
            window:AddAnchor("BOTTOMRIGHT", "UIParent", 0, -130)
            window:SetCloseOnEscape(true)

            local background = window:CreateColorDrawable(0, 0, 0, 0.7, "background")
            background:AddAnchor("TOPLEFT", window, 0, 0)
            background:AddAnchor("BOTTOMRIGHT", window, 0, 0)

            local function OnShow()
                if window.ShowProc ~= nil then
                    window:ShowProc()
                end
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
            local text1 = window:CreateChildWidget("label", "text1_" .. windowCount, 0, false)
            text1:SetHeight(20)
            text1.style:SetFontSize(30)
            text1:AddAnchor("CENTER", window, 0, -50)
            text1.style:SetAlign(ALIGN_CENTER)
            text1.style:SetColor(255, 0, 0, 255)
            text1:SetText(eventName)

            local text2 = window:CreateChildWidget("label", "text2_" .. windowCount, 0, false)
            text2:SetHeight(20)
            text2.style:SetFontSize(18)
            text2:AddAnchor("CENTER", window, 0, -15)
            text2.style:SetAlign(ALIGN_CENTER)
            text2.style:SetColorByKey("black")
            text2:SetText(eventName .. " will start Soon.")

            local containerBar = window:CreateChildWidget("statusbar", "containerBar_" .. windowCount, 0, false)
            containerBar:SetBarTexture("ui/common/hud.dds", "background")
            containerBar:SetBarTextureByKey("default_guage_small")
            containerBar:SetOrientation("HORIZONTAL")
            containerBar:SetExtent(430, 15)
            containerBar:SetBarColor(0.5, 0.5, 0.5, 0.5) 
            containerBar:Show(true)
            containerBar:SetMinMaxValues(0, 1)
            containerBar:SetValue(1)
            containerBar:AddAnchor("CENTER", window, 0, 15)

            local statusBar = window:CreateChildWidget("statusbar", "statusBar_" .. windowCount, 0, false)
            statusBar:SetBarTexture("ui/common/hud.dds", "background")
            statusBar:SetBarTextureByKey("default_guage_small")
            statusBar:SetOrientation("HORIZONTAL")
            statusBar:SetExtent(430, 15)
            statusBar:SetBarColor(1, 0.8, 0, 1)
            statusBar:Show(true)
            statusBar:SetMinMaxValues(0, 60000)
            statusBar:SetValue(60000)
            statusBar:AddAnchor("CENTER", window, 0, 15)

            local timerLabel = window:CreateChildWidget("label", "timerLabel_" .. windowCount, 0, false)
            timerLabel:SetHeight(20)
            timerLabel.style:SetFontSize(14)
            timerLabel:AddAnchor("CENTER", window, 0, 16) 
            timerLabel.style:SetAlign(ALIGN_CENTER)
            timerLabel.style:SetColor(0.6, 0.6, 1, 1) 
            timerLabel:SetText("60s") 
            timerLabel:Show(true)
            window.timerLabel = timerLabel  

            local closeButton = window:CreateChildWidget("button", "closeButton_" .. windowCount, 0, true)
            closeButton:SetText(X2Locale:LocalizeUiText(COMMON_TEXT, "ok"))
            local color = {
                normal = UIParent:GetFontColor("btn_df"),
                highlight = UIParent:GetFontColor("btn_ov"),
                pushed = UIParent:GetFontColor("btn_on"),
                disabled = UIParent:GetFontColor("btn_dis"),
            }

            local buttonskin = {
                drawableType = "ninePart",
                path = "ui/common/default.dds",
                coordsKey = "btn",
                autoResize = true,
                fontColor = color,
                fontInset = {
                    left = 11,
                    right = 11,
                    top = 0,
                    bottom = 0,
                },
            }

            closeButton:SetStyle("text_default")
            closeButton:AddAnchor("CENTER", window, 0, 50)
            closeButton:Show(true)

            function closeButton:OnClick()
                window:Show(false)
                eventCooldowns[eventName] = 660000
                currentEvent = nil
                notifiedEvents[window.eventName] = nil
            end

            closeButton:SetHandler("OnClick", closeButton.OnClick)
            
            window.eventName = eventName
            window.statusBar = statusBar
            window.containerBar = containerBar
            _G["RaidNotificationWindow" .. windowCount] = window
            windowTimers[windowCount] = 60000
            windowCount = windowCount + 1
            window:Show(true)
            notifiedEvents[eventName] = true
        end
        currentEvent = eventName
    end
end
local function checkGameEvents()
    if X2Time then
        local isAM, hours, minutes = X2Time:GetGameTime()
        if hours and type(hours) == "number" and minutes and type(minutes) == "number" then
            for eventName, eventData in pairs(gameEvents) do
                if hours == eventData.startHour and minutes >= eventData.startMinute and minutes <= eventData.endMinute and isAM == eventData.isAM and currentEvent ~= eventName and (not eventCooldowns[eventName] or eventCooldowns[eventName] <= 0) then
                    showRaidNotificationWindow(eventName)
                    currentEvent = eventName
                    break
                end
            end
        end
    end
end
local function checkZoneEvents()
    for i, zoneId in ipairs(zoneIds) do
        local zoneStateInfo = X2Map:GetZoneStateInfoByZoneId(zoneId)
        if zoneStateInfo and zoneStateInfo.zoneName then
            local eventName = zoneNames[i]
            local conflictState = zoneStateInfo.conflictState
            local remainTime = zoneStateInfo.remainTime
            if zoneId == 102 or zoneId == 103 then
                if conflictState == 5 and remainTime and remainTime <= 300 then
                    if currentEvent ~= eventName and (not eventCooldowns[eventName] or eventCooldowns[eventName] <= 0) then
                        showRaidNotificationWindow(eventName)
                        currentEvent = eventName
                    end
                elseif conflictState == 6 and remainTime and remainTime >= 5100 then
                    if currentEvent ~= eventName and (not eventCooldowns[eventName] or eventCooldowns[eventName] <= 0) then
                        showRaidNotificationWindow(eventName)
                        currentEvent = eventName
                    end
                end
            elseif zoneId == 17 or zoneId == 20 then
                if conflictState == 5 then
                    if currentEvent ~= eventName and (not eventCooldowns[eventName] or eventCooldowns[eventName] <= 0) then
                        showRaidNotificationWindow(eventName)
                        currentEvent = eventName
                    end
                elseif conflictState == 6 and remainTime and remainTime >= 1500 then
                    if currentEvent ~= eventName and (not eventCooldowns[eventName] or eventCooldowns[eventName] <= 0) then
                        showRaidNotificationWindow(eventName)
                        currentEvent = eventName
                    end
                end
            end
        end
    end
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
local function checkServerEvents()
    local serverTimeTable = UIParent:GetServerTimeTable()
    if serverTimeTable then
        local year = serverTimeTable.year
        local month = serverTimeTable.month
        local day = serverTimeTable.day
        local hour = serverTimeTable.hour
        local minute = serverTimeTable.minute
        local dayOfWeek = calculateDayOfWeek(year, month, day)
        for eventName, eventData in pairs(serverEvents) do
            for _, event in ipairs(eventData) do
                if event.days and table.contains(event.days, dayOfWeek) then
                    for _, timeData in ipairs(event.times) do
                        local endHour = timeData.hour
                        local endMinute = timeData.minute or 0
                        local startHour, startMinute = endHour, endMinute - 10
                        if startMinute < 0 then
                            startMinute = startMinute + 60
                            startHour = startHour - 1
                            if startHour < 0 then
                                startHour = startHour + 24
                            end
                        end
                        local startTime = startHour * 60 + startMinute
                        local endTime = endHour * 60 + endMinute
                        local currentTime = hour * 60 + minute
                        if currentTime >= startTime and currentTime <= endTime and currentEvent ~= eventName and (not eventCooldowns[eventName] or eventCooldowns[eventName] <= 0) then
                            showRaidNotificationWindow(eventName)
                            currentEvent = eventName
                            break
                        end
                    end
                end
            end
        end
    end
end
function timeUpdater:OnUpdate(dt)
    counter = counter + dt
    for eventName, cooldown in pairs(eventCooldowns) do
        eventCooldowns[eventName] = math.max(0, cooldown - dt)
    end
    for i = 1, windowCount - 1 do
        local window = _G["RaidNotificationWindow" .. i]
        if window and window:IsVisible() then
            if windowTimers[i] then
                windowTimers[i] = windowTimers[i] - dt

                if window.statusBar then
                    window.statusBar:SetValue(windowTimers[i])
                end

                if window.timerLabel then
                    local remainingTime = math.max(0, math.ceil(windowTimers[i] / 1000)) 
                    window.timerLabel:SetText(string.format("%ds", remainingTime)) 
                end
                if windowTimers[i] <= 0 then
                    window:Show(false)
                    eventCooldowns[window.eventName] = 660000
                    currentEvent = nil
                    windowTimers[i] = nil
                    if notifiedEvents[window.eventName] then
                        notifiedEvents[window.eventName] = nil
                    end
                end
            end
        end
    end
    if counter >= 1000 then
        checkGameEvents()
        checkServerEvents()
        checkZoneEvents()
        counter = 0
    end
end
timeUpdater:SetHandler("OnUpdate", timeUpdater.OnUpdate)
local function EnteredWorld()
    checkGameEvents()
    checkServerEvents()
    checkZoneEvents()
    timeUpdater:SetHandler("OnUpdate", timeUpdater.OnUpdate)
end
UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)
function table.contains(table, element)
    for _, value in ipairs(table) do
        if value == element then
            return true
        end
    end
    return false
end