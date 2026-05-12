ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.TEXTBOX)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.MAP.id)

local log_folder = "../Documents/Addon/RaidSnapshot/RaidsSnaps/"

local eventSelectionWindow = nil
local eventComboBox = nil
local currentSession = nil
local sessionFilePath = nil
local frameCounter = 0

local sessionFrames = {}
local playerJoinEvents = {}
local playerLeaveEvents = {}
local zoneChangeEvents = {}
local zoneStartEvents = {}
local maxPlayersFrameData = nil
local lastFrameData = nil

local playerTrackingTable = {}

function InitializePlayerTracking(playerName, frameNumber, timeString, zoneName)
    if not playerTrackingTable[playerName] then
        playerTrackingTable[playerName] = {
            events = {},
            currentlyPresent = false
        }
    end

    table.insert(playerTrackingTable[playerName].events, {
        action = "initial",
        frame = frameNumber,
        time = timeString,
        zone = zoneName,
        timestamp = currentSession and currentSession.startTime or GetServerTimestamp()
    })
    playerTrackingTable[playerName].currentlyPresent = true
end

function RecordPlayerJoin(playerName, frameNumber, timeString, zoneName)
    if not playerTrackingTable[playerName] then
        playerTrackingTable[playerName] = {
            events = {},
            currentlyPresent = false
        }
    end

    table.insert(playerTrackingTable[playerName].events, {
        action = "join",
        frame = frameNumber,
        time = timeString,
        zone = zoneName,
        timestamp = GetServerTimestamp()
    })
    playerTrackingTable[playerName].currentlyPresent = true
end

function RecordPlayerLeave(playerName, frameNumber, timeString, zoneName)
    if playerTrackingTable[playerName] then
        table.insert(playerTrackingTable[playerName].events, {
            action = "leave",
            frame = frameNumber,
            time = timeString,
            zone = zoneName,
            timestamp = GetServerTimestamp()
        })
        playerTrackingTable[playerName].currentlyPresent = false
    end
end

function FinalizePlayerTracking(sessionEndTime, sessionEndTimeString)
    for playerName, playerData in pairs(playerTrackingTable) do
        if playerData.currentlyPresent then

            table.insert(playerData.events, {
                action = "session_end",
                frame = "Final",
                time = sessionEndTimeString,
                zone = "Session End",
                timestamp = sessionEndTime
            })
        end
    end
end

function CalculateRaidAttendanceFromTracking()
    if not currentSession then return {} end

    local sessionStart = currentSession.startTime
    local sessionEnd = GetServerTimestamp()
    local sessionDurationSeconds = sessionEnd - sessionStart

    local attendance = {}

    for playerName, playerData in pairs(playerTrackingTable) do
        local totalPresenceTime = 0
        local presencePeriods = {}

        local currentPeriodStart = nil

        for _, event in ipairs(playerData.events) do
            if event.action == "initial" or event.action == "join" then
                if not currentPeriodStart then
                    currentPeriodStart = event.timestamp
                end
            elseif event.action == "leave" then
                if currentPeriodStart then
                    local periodDuration = event.timestamp - currentPeriodStart
                    totalPresenceTime = totalPresenceTime + periodDuration

                    local startFrame = "Initial frame"
                    for _, e in ipairs(playerData.events) do
                        if e.timestamp == currentPeriodStart then
                            startFrame = e.action == "initial" and "Initial frame" or ("frame " .. e.frame)
                            break
                        end
                    end
                    table.insert(presencePeriods, startFrame .. " > frame " .. event.frame)
                    currentPeriodStart = nil
                end
            elseif event.action == "session_end" then
                if currentPeriodStart then
                    local periodDuration = event.timestamp - currentPeriodStart
                    totalPresenceTime = totalPresenceTime + periodDuration

                    local startFrame = "Initial frame"
                    for _, e in ipairs(playerData.events) do
                        if e.timestamp == currentPeriodStart then
                            startFrame = e.action == "initial" and "Initial frame" or ("frame " .. e.frame)
                            break
                        end
                    end
                    table.insert(presencePeriods, startFrame .. " > Final frame")
                end
            end
        end

        local percentage = sessionDurationSeconds > 0 and math.floor((totalPresenceTime / sessionDurationSeconds) * 10000) / 100 or 0
        local minutes = math.floor(totalPresenceTime / 60)
        local seconds = math.floor(totalPresenceTime % 60)
        local timeFormatted = string.format("%d:%02d", minutes, seconds)

        table.insert(attendance, {
            player = playerName,
            total_minutes = timeFormatted,
            total_seconds = totalPresenceTime,
            percentage = percentage,
            presence_periods = presencePeriods
        })
    end

    table.sort(attendance, function(a, b) return a.total_seconds > b.total_seconds end)

    return attendance
end

function CalculateZoneFragmentationFromTracking()
    if not currentSession then return {} end

    local zoneTimeline = {}
    local sessionEnd = GetServerTimestamp()

    local zoneEvents = {}

    do
        local initialZone = currentSession.initialZoneName
            or (sessionFrames[1] and sessionFrames[1].zone and string.match(sessionFrames[1].zone, "Reporter Current Zone: (.+)"))
        if initialZone then
            table.insert(zoneEvents, {
                zone = initialZone,
                timestamp = currentSession.startTime,
                frame = "Initial frame"
            })
        end
    end

    for _, zstart in ipairs(zoneStartEvents) do
        local ts = ParseTimestamp(zstart.time)
        if ts == 0 then ts = GetServerTimestamp() end
        table.insert(zoneEvents, {
            zone = zstart.zone,
            timestamp = ts,
            frame = "frame " .. zstart.frame
        })
    end

    table.sort(zoneEvents, function(a, b) return a.timestamp < b.timestamp end)

    for i = 1, #zoneEvents do
        local currentEvent = zoneEvents[i]
        local nextEvent = zoneEvents[i + 1]

        local endTime = nextEvent and nextEvent.timestamp or sessionEnd
        local endFrame = nextEvent and nextEvent.frame or "Final frame"

        if endTime > currentEvent.timestamp then
            table.insert(zoneTimeline, {
                zone = currentEvent.zone,
                start_time = currentEvent.timestamp,
                end_time = endTime,
                start_frame = currentEvent.frame,
                end_frame = endFrame
            })
        end
    end

    local fragmentation = {}

    local zonePeriodsByName = {}
    for _, zp in ipairs(zoneTimeline) do
        local zn = zp.zone
        local dur = (zp.end_time or 0) - (zp.start_time or 0)
        if zn ~= "Unknown" and zn ~= "unavailable" and dur > 0 then
            if not zonePeriodsByName[zn] then
                zonePeriodsByName[zn] = { periods = {}, total = 0 }
            end
            table.insert(zonePeriodsByName[zn].periods, { s = zp.start_time, e = zp.end_time })
            zonePeriodsByName[zn].total = zonePeriodsByName[zn].total + dur
        end
    end

    local presencePeriodsByPlayer = {}
    for playerName, playerData in pairs(playerTrackingTable) do
        local periods = {}
        local curStart = nil
        for _, event in ipairs(playerData.events) do
            if event.action == "initial" or event.action == "join" then
                if not curStart then curStart = event.timestamp end
            elseif event.action == "leave" or event.action == "session_end" then
                if curStart then
                    table.insert(periods, { s = curStart, e = event.timestamp })
                    curStart = nil
                end
            end
        end
        presencePeriodsByPlayer[playerName] = periods
    end

    for zoneName, info in pairs(zonePeriodsByName) do
        local totalZoneTime = info.total
        local zoneData = {
            zone = zoneName,
            total_zone_time_minutes = string.format("%d:%02d", math.floor(totalZoneTime / 60), math.floor(totalZoneTime % 60)),
            total_zone_time_seconds = totalZoneTime,
            players = {}
        }

        for playerName, pperiods in pairs(presencePeriodsByPlayer) do
            local playerZoneTime = 0
            for _, zperiod in ipairs(info.periods) do
                for _, p in ipairs(pperiods) do
                    local os = math.max(p.s, zperiod.s)
                    local oe = math.min(p.e, zperiod.e)
                    if os < oe then
                        playerZoneTime = playerZoneTime + (oe - os)
                    end
                end
            end
            if playerZoneTime > 0 then
                table.insert(zoneData.players, {
                    player = playerName,
                    time_minutes = string.format("%d:%02d", math.floor(playerZoneTime / 60), math.floor(playerZoneTime % 60)),
                    time_seconds = playerZoneTime,
                    percentage = totalZoneTime > 0 and math.floor((playerZoneTime / totalZoneTime) * 10000) / 100 or 0
                })
            end
        end

        table.sort(zoneData.players, function(a, b) return a.time_seconds > b.time_seconds end)
        table.insert(fragmentation, zoneData)
    end

    table.sort(fragmentation, function(a, b) return a.total_zone_time_seconds > b.total_zone_time_seconds end)
    return fragmentation
end

local monitoringFrame = nil
local monitorPrevPlayers = {}
local monitorPrevZone = nil

local serverEvents = {
    "J.MG",
    "GR",
    "CR",
    "Aegis",
    "WhaleSong",
    "Hiram Rift",
    "Garden of Gods",
    "Black Dragon",
    "Kraken",
    "Nehlya",
    "Risopoda",
    "Thunder Wing Titan",
    "Leviathan",
    "Charybdis",
    "Anthalon",
    "Halcy",
    "Hasla",
    "Luscas"
}

function CreateButton(text, parent, handler)
    local button = parent:CreateChildWidget("button", text, 0, true)
    button:SetText(text)
    button:SetStyle('text_default')
    button:Show(true)
    if handler then
        button:SetHandler("OnClick", handler)
    end
    return button
end

function CreateEventSelectionWindow()
    if eventSelectionWindow then return end

    eventSelectionWindow = CreateEmptyWindow("eventSelectionWindow", "UIParent")
    eventSelectionWindow:SetExtent(250, 120)
    eventSelectionWindow:AddAnchor("CENTER", "UIParent", 0, 0)
    eventSelectionWindow:SetCloseOnEscape(true)

    local function OnShow()
        if eventSelectionWindow.ShowProc ~= nil then
            eventSelectionWindow:ShowProc()
        end
        SettingWindowSkin(eventSelectionWindow)
        eventSelectionWindow:SetStartAnimation(true, true)

        if eventComboBox and eventComboBox.ResetDisplay then
            eventComboBox:ResetDisplay()
        end

        local eventOptions = {}
        for _, eventName in ipairs(serverEvents) do
            table.insert(eventOptions, {
                text = eventName,
                handler = function()
                    StartRaidSession(eventName)
                    HideEventSelectionWindow()
                end
            })
        end

        eventComboBox = CreateComboBox(
            eventSelectionWindow,
            200,
            25,
            5,
            eventOptions,
            20,
            "TOP",
            eventSelectionWindow,
            0,
            35
        )
    end
    eventSelectionWindow:SetHandler("OnShow", OnShow)

    local label = eventSelectionWindow:CreateChildWidget("label", "eventLabel", 0, false)
    label:SetText("Raid detected! Select activity:")
    label:AddAnchor("TOP", eventSelectionWindow, 0, 15)
    label.style:SetAlign(ALIGN_CENTER)

    local cancelButton = CreateButton("Cancel", eventSelectionWindow, function()
        HideEventSelectionWindow()
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFFF6B6BRaid session cancelled")
    end)
    cancelButton:AddAnchor("BOTTOM", eventSelectionWindow, 0, -15)

    eventSelectionWindow:Show(false)
end

function ShowEventSelectionWindow()
    if not eventSelectionWindow then
        CreateEventSelectionWindow()
    end
    eventSelectionWindow:Show(true)
end

function HideEventSelectionWindow()
    if eventSelectionWindow then
        eventSelectionWindow:Show(false)
        if eventComboBox and eventComboBox.ResetDisplay then
            eventComboBox:ResetDisplay()
        end
    end
end

function StartRaidSession(eventName)
    if currentSession then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFFF6B6BSession already active for: " .. currentSession.eventName)
        return
    end

    currentSession = {
        eventName = eventName,
        startTime = GetServerTimestamp()
    }

    frameCounter = 0
    sessionFilePath = CreateSessionFileName(eventName)

    sessionFrames = {}
    playerJoinEvents = {}
    playerLeaveEvents = {}
    zoneChangeEvents = {}
    zoneStartEvents = {}
    maxPlayersFrameData = nil
    lastFrameData = nil
    monitorPrevPlayers = {}
    monitorPrevZone = nil

    CreateInitialRaidFrame(eventName)

    do
        local z, rd, players = CollectRaidSnapshot()
        monitorPrevZone = z
        monitorPrevPlayers = players or {}
    end
    StartMonitoring()

    X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("|cFF35CAEERaid Session Started: |cFFFFD700%s", eventName))
end

function EndRaidSession(reason)
    if not currentSession then
        return
    end

    StopMonitoring()

    AddRaidFrame("Final Raid Frame")

    AddSessionSynthesis()

    local sessionDuration = GetServerTimestamp() - currentSession.startTime
    X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("|cFF35CAEERaid Session Ended: |cFFFFD700%s |cFFFFFFFF(Duration: %d minutes, Frames: %d)",
        currentSession.eventName, math.floor(sessionDuration / 60), frameCounter))

    currentSession = nil
    sessionFilePath = nil
    frameCounter = 0
end

function AddRaidFrame(frameLabel)
    if not currentSession or not sessionFilePath then
        return
    end

    frameCounter = frameCounter + 1
    local frameTitle = frameLabel or ("Take " .. frameCounter)

    ProcessRaidSnapshot(currentSession.eventName, frameTitle, true)
end

function AddSessionSynthesis()
    if not sessionFilePath then
        return
    end

    local file = io.open(sessionFilePath, "a")
    if not file then
        return
    end

    local serverTimeTable = UIParent:GetServerTimeTable()
    local endTime = "End time unavailable"
    if serverTimeTable then
        local year, month, day = serverTimeTable.year, serverTimeTable.month, serverTimeTable.day
        local hour = serverTimeTable.hour or 0
        local minute = serverTimeTable.minute or 0
        local second = serverTimeTable.second or 0
        endTime = string.format("End Date: %04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
    end

    local sessionDuration = GetServerTimestamp() - currentSession.startTime
    local durationMinutes = math.floor(sessionDuration / 60)
    local durationSeconds = math.floor(sessionDuration % 60)
    local durationText = string.format("Session Duration: %d:%02d minutes", durationMinutes, durationSeconds)

    FinalizePlayerTracking(GetServerTimestamp(), endTime)

    file:write("\n")
    file:write("=== SESSION SYNTHESIS ===\n")
    file:write(EscapeCSV(endTime) .. "\n")
    file:write(EscapeCSV(durationText) .. "\n")
    file:write("\n")

    if #playerJoinEvents > 0 then
        file:write("Players Joined:\n")
        file:write("Player Name,Action,Time\n")
        for _, event in ipairs(playerJoinEvents) do
            file:write(string.format("%s,joined frame %d,%s\n",
                EscapeCSV(event.player),
                event.frame,
                EscapeCSV(event.time)))
        end
        file:write("\n")
    end

    if #playerLeaveEvents > 0 then
        file:write("Players Left:\n")
        file:write("Player Name,Action,Time\n")
        for _, event in ipairs(playerLeaveEvents) do
            file:write(string.format("%s,left frame %d,%s\n",
                EscapeCSV(event.player),
                event.frame,
                EscapeCSV(event.time)))
        end
        file:write("\n")
    end

    if lastFrameData and lastFrameData.zone then
        local lastZoneName = string.match(lastFrameData.zone, "Reporter Current Zone: (.+)")
        if lastZoneName and lastZoneName ~= "unavailable" then
            local alreadyHas = false
            for _, e in ipairs(zoneChangeEvents) do
                if e.zone == lastZoneName and e.frame == lastFrameData.frameNumber then
                    alreadyHas = true
                    break
                end
            end
            if not alreadyHas then
                table.insert(zoneChangeEvents, {
                    zone = lastZoneName,
                    frame = lastFrameData.frameNumber,
                    time = lastFrameData.time,
                    players = lastFrameData.players,
                    frameData = lastFrameData,
                    zone_end = true
                })
            end
        end
    end

    do
        local initialZoneName = currentSession and currentSession.initialZoneName
        if initialZoneName and initialZoneName ~= "unavailable" and initialZoneName ~= "Unknown" then
            local hasInitial = false
            for _, e in ipairs(zoneChangeEvents) do
                if e.zone == initialZoneName then
                    hasInitial = true
                    break
                end
            end
            if not hasInitial and #zoneChangeEvents > 0 then

                local firstEvent = nil
                for _, e in ipairs(zoneChangeEvents) do
                    if not firstEvent or e.frame < firstEvent.frame then
                        firstEvent = e
                    end
                end
                if firstEvent then
                    local candidateFrame = math.max(0, (firstEvent.frame or 1) - 1)
                    table.insert(zoneChangeEvents, {
                        zone = initialZoneName,
                        frame = candidateFrame,
                        time = firstEvent.time,
                        players = firstEvent.players,
                        frameData = firstEvent.frameData,
                        zone_end = true
                    })
                end
            end
        end
    end

    if #zoneChangeEvents > 0 then
        table.sort(zoneChangeEvents, function(a, b) return a.frame < b.frame end)
        file:write("Zone Changes (Last frame in each zone):\n")
        for _, event in ipairs(zoneChangeEvents) do
            file:write(string.format("Last frame in %s: frame %d (%d players)\n",
                EscapeCSV(event.zone), event.frame, #event.players))
            file:write("Player Name,Gear Score,Class\n")
            if event.frameData then
                local enrichedPlayers = EnrichPlayersData(event.players, event.frameData)
                for _, player in ipairs(enrichedPlayers) do
                    file:write(string.format("%s,%s,%s\n",
                        EscapeCSV(player.name),
                        EscapeCSV(player.gear_score),
                        EscapeCSV(player.class)))
                end
            end
            file:write("\n")
        end
    end

    local raidAttendance = CalculateRaidAttendanceFromTracking()
    if #raidAttendance > 0 then
        file:write("Raid Attendance:\n")
        file:write("Player Name,Total Minutes,Percentage,Presence Periods\n")
        for _, attendance in ipairs(raidAttendance) do
            local periods = table.concat(attendance.presence_periods, " | ")
            file:write(string.format("%s,%s,%s%%,%s\n",
                EscapeCSV(attendance.player),
                EscapeCSV(attendance.total_minutes),
                EscapeCSV(tostring(attendance.percentage)),
                EscapeCSV(periods)))
        end
        file:write("\n")
    end

    local zoneFragmentation = CalculateZoneFragmentationFromTracking()
    if #zoneFragmentation > 0 then
        file:write("Zone Fragmentation:\n")
        for _, zoneData in ipairs(zoneFragmentation) do
            file:write(string.format("Zone: %s (Total Time: %s minutes)\n",
                zoneData.zone, zoneData.total_zone_time_minutes))
            file:write("Player Name,Time Minutes,Percentage\n")
            for _, playerData in ipairs(zoneData.players) do
                file:write(string.format("%s,%s,%s%%\n",
                    EscapeCSV(playerData.player),
                    EscapeCSV(playerData.time_minutes),
                    EscapeCSV(tostring(playerData.percentage))))
            end
            file:write("\n")
        end
    end

    local maxPlayersFrame = GetFrameWithMostPlayers()
    if maxPlayersFrame then
        file:write(string.format("Frame with most players: %s (%d players) - Zone: %s\n",
            maxPlayersFrame.frameTitle, #maxPlayersFrame.players, maxPlayersFrame.zone))
        file:write("Player Name,Gear Score,Class\n")
        local enrichedPlayers = EnrichPlayersData(maxPlayersFrame.players, maxPlayersFrame)
        for _, player in ipairs(enrichedPlayers) do
            file:write(string.format("%s,%s,%s\n",
                EscapeCSV(player.name),
                EscapeCSV(player.gear_score),
                EscapeCSV(player.class)))
        end
        file:write("\n")
    end

    local lastFrame = GetLastFrameBeforeFinal()
    if lastFrame then
        file:write(string.format("Last frame before final: %s (%d players) - Zone: %s\n",
            lastFrame.frameTitle, #lastFrame.players, lastFrame.zone))
        file:write("Player Name,Gear Score,Class\n")
        local enrichedPlayers = EnrichPlayersData(lastFrame.players, lastFrame)
        for _, player in ipairs(enrichedPlayers) do
            file:write(string.format("%s,%s,%s\n",
                EscapeCSV(player.name),
                EscapeCSV(player.gear_score),
                EscapeCSV(player.class)))
        end
        file:write("\n")
    end

    file:close()

    AddJSONSynthesis()
    CreateRaidAttendanceCSV()
end

function UpdateMaxPlayersFrame(currentFrame)
    if not maxPlayersFrameData or #currentFrame.players > #maxPlayersFrameData.players then
        maxPlayersFrameData = {
            frameNumber = currentFrame.frameNumber,
            frameTitle = currentFrame.frameTitle,
            players = {},
            zone = currentFrame.zone,
            time = currentFrame.time,
            raidData = currentFrame.raidData
        }
        for _, player in ipairs(currentFrame.players) do
            table.insert(maxPlayersFrameData.players, player)
        end
    end
end

function GetFrameWithMostPlayers()
    return maxPlayersFrameData
end

function GetLastFrameBeforeFinal()
    return lastFrameData
end

function EnrichPlayersData(playerNames, frameData)
    local enrichedPlayers = {}
    for _, playerName in ipairs(playerNames) do
        local playerInfo = {
            name = playerName,
            gear_score = "Unknown",
            class = "Unknown"
        }

        for team = 1, 2 do
            if frameData.raidData and frameData.raidData[team] then
                for _, player in ipairs(frameData.raidData[team]) do
                    if player.name == playerName then
                        playerInfo.gear_score = player.gearScore
                        playerInfo.class = player.class
                        break
                    end
                end
            end
        end

        table.insert(enrichedPlayers, playerInfo)
    end
    return enrichedPlayers
end

function ParseTimestamp(timeString)

    local year, month, day, hour, min, sec = string.match(timeString, "Date: (%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    if year then
        return os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec)
        })
    end
    return 0
end

function AddJSONSynthesis()
    if not sessionFilePath then
        return
    end

    local jsonFilePath = CreateJSONFileName(currentSession.eventName)

    local startTimeText = currentSession.startTime and os.date("Date: %Y-%m-%d %H:%M:%S", currentSession.startTime) or "Unknown"
    local startZoneText = currentSession.initialZoneName and ("Reporter Current Zone: " .. currentSession.initialZoneName) or "Unknown"
    local serverTimeTable = UIParent:GetServerTimeTable()
    local endTime = "End time unavailable"
    if serverTimeTable then
        local year, month, day = serverTimeTable.year, serverTimeTable.month, serverTimeTable.day
        local hour = serverTimeTable.hour or 0
        local minute = serverTimeTable.minute or 0
        local second = serverTimeTable.second or 0
        endTime = string.format("End Date: %04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
    end

    local sessionDuration = GetServerTimestamp() - currentSession.startTime

    local maxPlayersFrame = GetFrameWithMostPlayers()
    local lastFrame = GetLastFrameBeforeFinal()

    if maxPlayersFrame then
        maxPlayersFrame.zone = maxPlayersFrame.zone
        for raidNum, participants in pairs(maxPlayersFrame.raidData or {}) do
            maxPlayersFrame["Raid" .. raidNum] = {}
            for _, player in ipairs(participants) do
                table.insert(maxPlayersFrame["Raid" .. raidNum], {
                    name = player.name,
                    gear_score = player.gearScore,
                    class = player.class
                })
            end
        end
        maxPlayersFrame.players = nil
        maxPlayersFrame.raidData = nil
    end

    if lastFrame then
        lastFrame.zone = lastFrame.zone
        for raidNum, participants in pairs(lastFrame.raidData or {}) do
            lastFrame["Raid" .. raidNum] = {}
            for _, player in ipairs(participants) do
                table.insert(lastFrame["Raid" .. raidNum], {
                    name = player.name,
                    gear_score = player.gearScore,
                    class = player.class
                })
            end
        end
        lastFrame.players = nil
        lastFrame.raidData = nil
    end

    local enrichedZoneChanges = {}
    for _, zoneEvent in ipairs(zoneChangeEvents) do
        if zoneEvent.frameData then
            table.insert(enrichedZoneChanges, {
                zone = zoneEvent.zone,
                frame = zoneEvent.frame,
                players = EnrichPlayersData(zoneEvent.players, zoneEvent.frameData)
            })
        end
    end

    local jsonData = {
        __order = {
            "event_info",
            "end_time",
            "duration_minutes",
            "total_frames",
            "frame_with_most_players",
            "last_frame_before_final",
            "zone_changes",
            "players_joined",
            "players_left",
            "raid_attendance",
            "zone_fragmentation"
        },
        event_info = {
          start_time = startTimeText,
          activity = currentSession.eventName,
          start_zone = startZoneText
        },
        end_time = endTime,
        duration_minutes = string.format("%d:%02d", math.floor(sessionDuration / 60), math.floor(sessionDuration % 60)),
        total_frames = frameCounter,
        frame_with_most_players = maxPlayersFrame,
        last_frame_before_final = lastFrame,
        zone_changes = enrichedZoneChanges or {},
        players_joined = playerJoinEvents or {},
        players_left = playerLeaveEvents or {},
        raid_attendance = CalculateRaidAttendanceFromTracking(),
        zone_fragmentation = CalculateZoneFragmentationFromTracking()
    }

    local file = io.open(jsonFilePath, "w")
    if file then
        file:write(SerializeToJSON(jsonData))
        file:close()
    end
end

function CreateRaidAttendanceCSV()
    if not sessionFilePath then
        return
    end

    local baseFileName = sessionFilePath
    local attendanceFileName = baseFileName:gsub("%.csv$", "_RaidAttendance.csv")
    
    local attendanceData = CalculateRaidAttendanceFromTracking()
    
    local csvContent = {}
    table.insert(csvContent, "Player Name,Total Minutes,Percentage,Presence Periods")
    
    for _, playerData in ipairs(attendanceData) do
        local periodsStr = table.concat(playerData.presence_periods, " | ")
        
        local line = string.format("%s,%s,%s%%,%s", 
            EscapeCSV(playerData.player), 
            EscapeCSV(playerData.total_minutes), 
            EscapeCSV(tostring(playerData.percentage)), 
            EscapeCSV(periodsStr))
        table.insert(csvContent, line)
    end
    
    local file = io.open(attendanceFileName, "w")
    if file then
        for _, line in ipairs(csvContent) do
            file:write(line .. "\n")
        end
        file:close()
    end
end

function FormatGearScore(gearScore)
    if gearScore == 0 then
        return "Not In Range"
    end

    local str = tostring(gearScore)
    local formatted = ""
    local len = string.len(str)

    for i = 1, len do
        local char = string.sub(str, i, i)
        formatted = formatted .. char

        local remaining = len - i
        if remaining > 0 and remaining % 3 == 0 then
            formatted = formatted .. " "
        end
    end

    return formatted
end

function GetPlayerInfo(unitId)
    local gearScore = X2Unit:UnitGearScore(unitId, true)
    gearScore = tonumber(gearScore) or 0

    local gearScoreDisplay = FormatGearScore(gearScore)

    local templates = X2Unit:GetTargetAbilityTemplates(unitId)
    local classInfo = ""

    if templates and #templates >= 3 then
        local indices = {
            templates[1].index,
            templates[2].index,
            templates[3].index
        }
        table.sort(indices)

        local classKey = table.concat(indices, "-")
        local className = classMappings[classKey]

        if className then
            classInfo = className
        else
            classInfo = classKey
        end
    else
        classInfo = "Unknown"
    end

    return gearScoreDisplay, classInfo
end

function GetCurrentZoneInfo()
    local zoneInfo = "Reporter Current Zone: unavailable"
    local currentZoneId = X2Unit:GetCurrentZoneGroup()
    if currentZoneId then
        local stateInfo = {X2Map:GetZoneStateInfoByZoneId(currentZoneId)}
        if type(stateInfo[1]) == "table" and stateInfo[1].zoneName then
            zoneInfo = "Reporter Current Zone: " .. tostring(stateInfo[1].zoneName)
        end
    end
    return zoneInfo
end

function GetServerTimestamp()
    local serverTimeTable = UIParent:GetServerTimeTable()
    return os.time({
        year = serverTimeTable.year,
        month = serverTimeTable.month,
        day = serverTimeTable.day,
        hour = serverTimeTable.hour or 0,
        min = serverTimeTable.minute or 0,
        sec = serverTimeTable.second or 0
    })
end

function DetectPlayerChanges(previousPlayers, currentPlayers, frameNumber, frameTime, currentZoneInfo)
    local prevSet = {}
    local currSet = {}

    for _, player in ipairs(previousPlayers) do
        prevSet[player] = true
    end

    for _, player in ipairs(currentPlayers) do
        currSet[player] = true
    end

    if #previousPlayers == #currentPlayers then
        local identical = true
        for _, player in ipairs(previousPlayers) do
            if not currSet[player] then
                identical = false
                break
            end
        end
        if identical then
            return
        end
    end

    local currentZone = string.match(currentZoneInfo or "", "Reporter Current Zone: (.+)") or "Unknown"

    for _, player in ipairs(currentPlayers) do
        if not prevSet[player] then
            table.insert(playerJoinEvents, {player = player, frame = frameNumber, time = frameTime})

            RecordPlayerJoin(player, frameNumber, frameTime, currentZone)
        end
    end
    for _, player in ipairs(previousPlayers) do
        if not currSet[player] then
            table.insert(playerLeaveEvents, {player = player, frame = frameNumber, time = frameTime})

            RecordPlayerLeave(player, frameNumber, frameTime, currentZone)
        end
    end
end

function DetectZoneChanges(previousZone, currentZone, frameNumber, frameData, previousFrameData)
    if previousZone ~= currentZone then
        local previousZoneName = string.match(previousZone, "Reporter Current Zone: (.+)")
        local currentZoneName = string.match(currentZone, "Reporter Current Zone: (.+)")

        if previousZoneName and previousZoneName ~= "unavailable" and previousFrameData then
            table.insert(zoneChangeEvents, {
                zone = previousZoneName,
                frame = previousFrameData.frameNumber,
                time = previousFrameData.time,
                players = previousFrameData.players,
                frameData = previousFrameData,
                zone_end = true
            })
        end

        if currentZoneName then
            table.insert(zoneStartEvents, {
                zone = currentZoneName,
                frame = frameNumber,
                time = frameData.time,
                frameData = frameData
            })
        end

        if currentZoneName and currentZoneName ~= "unavailable" then
            local zoneChangeTimestamp = ParseTimestamp(frameData.time)
            if zoneChangeTimestamp == 0 then
                zoneChangeTimestamp = GetServerTimestamp()
            end
            for _, playerName in ipairs(frameData.players) do
                if playerTrackingTable[playerName] and playerTrackingTable[playerName].currentlyPresent then
                    table.insert(playerTrackingTable[playerName].events, {
                        action = "zone_change",
                        frame = frameNumber,
                        time = frameData.time,
                        zone = currentZoneName,
                        timestamp = zoneChangeTimestamp
                    })
                end
            end
        end
    end
end

function CollectRaidSnapshot()
    local zoneInfo = GetCurrentZoneInfo()

    local raidData = {}
    local players = {}

    local availableRaids = {}

    for team = 1, 2 do
        local hasPlayersInTeam = false
        for member = 1, 50 do
            local teamId = string.format("team_%02d_%02d", team, member)
            if X2Unit:UnitName(teamId) ~= nil then
                hasPlayersInTeam = true
                break
            end
        end
        if hasPlayersInTeam then
            availableRaids[team] = "co-raid"
        end
    end

    if next(availableRaids) == nil then

        for i = 1, 50 do
            local teamId = string.format("team%02d", i)
            if X2Unit:UnitName(teamId) ~= nil then
                availableRaids[1] = "simple"
                break
            end
        end
        if next(availableRaids) == nil then
            for i = 1, 50 do
                local teamId = "team" .. i
                if X2Unit:UnitName(teamId) ~= nil then
                    availableRaids[1] = "simple"
                    break
                end
            end
        end
    end

    for raidNum, raidType in pairs(availableRaids) do
        raidData[raidNum] = {}

        if raidType == "co-raid" then

            for member = 1, 50 do
                local teamId = string.format("team_%02d_%02d", raidNum, member)
                local playerName = X2Unit:UnitName(teamId)
                if playerName then
                    local gearScore, classInfo = GetPlayerInfo(teamId)
                    table.insert(raidData[raidNum], {
                        name = playerName,
                        gearScore = gearScore,
                        class = classInfo
                    })
                    table.insert(players, playerName)
                end
            end
        elseif raidType == "simple" then
            for member = 1, 50 do
                local teamId = string.format("team%02d", member)
                local playerName = X2Unit:UnitName(teamId)
                if playerName then
                    local gearScore, classInfo = GetPlayerInfo(teamId)
                    table.insert(raidData[raidNum], {
                    name = playerName,
                    gearScore = gearScore,
                    class = classInfo
                })
                table.insert(players, playerName)
            end
        end
            if #raidData[raidNum] == 0 then
                for member = 1, 50 do
                    local teamId = "team" .. member
                    local playerName = X2Unit:UnitName(teamId)
                    if playerName then
                        local gearScore, classInfo = GetPlayerInfo(teamId)
                        table.insert(raidData[raidNum], {
                            name = playerName,
                            gearScore = gearScore,
                            class = classInfo
                        })
                        table.insert(players, playerName)
                    end
                end
            end
        end
    end

    if #raidData == 0 then
        raidData[1] = {}
    end

    return zoneInfo, raidData, players
end

function StartMonitoring()
    if monitoringFrame then return end
    monitoringFrame = CreateEmptyWindow("RaidSnapshotMonitorFrame", "UIParent")
    monitoringFrame:SetExtent(1, 1)
    monitoringFrame:Show(true)

    function monitoringFrame:OnUpdate(dt)
        if not currentSession then return end

        local zoneInfo, raidData, players = CollectRaidSnapshot()
        players = players or {}

        if monitorPrevZone and zoneInfo ~= monitorPrevZone then
            AddRaidFrame("Zone changed: " .. (zoneInfo or "unknown"))
        end

        local prevSet, currSet = {}, {}
        for _, n in ipairs(monitorPrevPlayers or {}) do prevSet[n] = true end
        for _, n in ipairs(players) do currSet[n] = true end

        for _, n in ipairs(players) do
            if not prevSet[n] then
                AddRaidFrame("Player joined: " .. n)
            end
        end
        for _, n in ipairs(monitorPrevPlayers or {}) do
            if not currSet[n] then
                AddRaidFrame("Player left: " .. n)
            end
        end

        monitorPrevZone = zoneInfo
        monitorPrevPlayers = players
    end

    monitoringFrame:SetHandler("OnUpdate", monitoringFrame.OnUpdate)
end

function StopMonitoring()
    if monitoringFrame then
        monitoringFrame:SetHandler("OnUpdate", nil)
        monitoringFrame:Show(false)
        monitoringFrame = nil
    end
end

function ProcessRaidSnapshot(eventName, frameTitle, appendToFile)
    local serverTimeTable = UIParent:GetServerTimeTable()
    local timeInfo = "Server time unavailable"
    if serverTimeTable then
        local year, month, day = serverTimeTable.year, serverTimeTable.month, serverTimeTable.day
        local hour = serverTimeTable.hour or 0
        local minute = serverTimeTable.minute or 0
        local second = serverTimeTable.second or 0
        timeInfo = string.format("Date: %04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
    end

    local activityInfo = "Activity: " .. eventName

    local zoneInfo, raidData, _ = CollectRaidSnapshot()

    local currentFrame = {
        frameNumber = frameCounter,
        frameTitle = frameTitle,
        players = {},
        zone = zoneInfo,
        time = timeInfo,
        raidData = raidData
    }

    for team = 1, #raidData do
        for _, player in ipairs(raidData[team]) do
            table.insert(currentFrame.players, player.name)
        end
    end

    if #sessionFrames > 0 and frameCounter > 0 then
        local previousFrame = sessionFrames[#sessionFrames]
        if frameTitle ~= "Final Raid Frame" then
            DetectPlayerChanges(previousFrame.players, currentFrame.players, frameCounter, timeInfo, currentFrame.zone)
            DetectZoneChanges(previousFrame.zone, currentFrame.zone, frameCounter, currentFrame, previousFrame)
        end

        lastFrameData = {
            frameNumber = previousFrame.frameNumber,
            frameTitle = previousFrame.frameTitle,
            players = {},
            zone = previousFrame.zone,
            time = previousFrame.time,
            raidData = previousFrame.raidData
        }
        for _, player in ipairs(previousFrame.players) do
            table.insert(lastFrameData.players, player)
        end
    end

    UpdateMaxPlayersFrame(currentFrame)

    table.insert(sessionFrames, currentFrame)

    if #sessionFrames > 3 then
        table.remove(sessionFrames, 1)
    end

    SaveRaidSnapshot(timeInfo, activityInfo, zoneInfo, raidData, eventName, frameTitle, appendToFile)

end

function CreateSessionFileName(eventName)
    local serverTimeTable = UIParent:GetServerTimeTable()
    if serverTimeTable then
        local year = serverTimeTable.year
        local month = serverTimeTable.month
        local day = serverTimeTable.day
        local hour = serverTimeTable.hour or 0
        local minute = serverTimeTable.minute or 0

        local fileName = string.format("%04d-%02d-%02d_%02d-%02d_%s.csv",
            year, month, day, hour, minute, eventName:gsub("%s+", "_"))
        return log_folder .. fileName
    else
        local fileName = string.format("RaidSnapshot_%s_%d.csv",
            eventName:gsub("%s+", "_"), GetServerTimestamp())
        return log_folder .. fileName
    end
end

function CreateJSONFileName(eventName)
    if currentSession and currentSession.startTime then
        local startTime = currentSession.startTime
        local year = os.date("%Y", startTime)
        local month = os.date("%m", startTime)
        local day = os.date("%d", startTime)
        local hour = os.date("%H", startTime)
        local minute = os.date("%M", startTime)
        
        local fileName = string.format("%04d-%02d-%02d_%02d-%02d_%s.json",
            year, month, day, hour, minute, eventName:gsub("%s+", "_"))
        return log_folder .. fileName
    else
        local csvPath = CreateSessionFileName(eventName)
        return string.gsub(csvPath, "%.csv$", ".json")
    end
end

function CreateInitialRaidFrame(eventName)
    frameCounter = 0

    playerTrackingTable = {}

    ProcessRaidSnapshot(eventName, "Initial Raid Frame", false)

    if currentSession then
        local zoneInfo, raidData, players = CollectRaidSnapshot()
        local zoneName = string.match(zoneInfo, "Reporter Current Zone: (.+)") or "Unknown"

        currentSession.initialZoneName = zoneName
        local timeInfo = "Date: " .. os.date("%Y-%m-%d %H:%M:%S")

        for _, playerName in ipairs(players) do
            InitializePlayerTracking(playerName, frameCounter, timeInfo, zoneName)
        end
    end
end

function EscapeCSV(value)
    if value == nil then
        return ""
    end
    local str = tostring(value)
    if string.find(str, '[",\n\r]') then
        str = '"' .. string.gsub(str, '"', '""') .. '"'
    end
    return str
end

function EscapeJSON(value)
    if value == nil then
        return "null"
    end
    local str = tostring(value)
    str = string.gsub(str, '\\', '\\\\')
    str = string.gsub(str, '"', '\\"')
    str = string.gsub(str, '\n', '\\n')
    str = string.gsub(str, '\r', '\\r')
    str = string.gsub(str, '\t', '\\t')
    return '"' .. str .. '"'
end

function SerializeToJSON(data, indent)
    indent = indent or 0
    local indentStr = string.rep("  ", indent)
    local nextIndentStr = string.rep("  ", indent + 1)

    if type(data) == "table" then
        local isArray = true
        local count = 0
        for k, v in pairs(data) do
            count = count + 1
            if type(k) ~= "number" or k ~= count then
                isArray = false
                break
            end
        end

        if isArray then
            if count == 0 then
                return "[]"
            end
            local result = "[\n"
            for i, v in ipairs(data) do
                if i > 1 then result = result .. ",\n" end
                result = result .. nextIndentStr .. SerializeToJSON(v, indent + 1)
            end
            return result .. "\n" .. indentStr .. "]"
        else
            if count == 0 then
                return "{}"
            end
            local result = "{\n"
            local first = true
            local order = rawget(data, "__order")
            if type(order) == "table" then
                for i = 1, #order do
                    local k = order[i]
                    local v = rawget(data, k)
                    if v ~= nil then
                        if not first then result = result .. ",\n" end
                        first = false
                        result = result .. nextIndentStr .. EscapeJSON(k) .. ": " .. SerializeToJSON(v, indent + 1)
                    end
                end
            else
                for k, v in pairs(data) do
                    if k ~= "__order" then
                        if not first then result = result .. ",\n" end
                        first = false
                        result = result .. nextIndentStr .. EscapeJSON(k) .. ": " .. SerializeToJSON(v, indent + 1)
                    end
                end
            end
            return result .. "\n" .. indentStr .. "}"
        end
    else
        return EscapeJSON(data)
    end
end

function SaveRaidSnapshot(timeInfo, activityInfo, zoneInfo, raidData, eventName, frameTitle, appendToFile)
    local filePath = sessionFilePath or CreateSessionFileName(eventName)
    local mode = appendToFile and "a" or "w"
    local file = io.open(filePath, mode)

    if file then
        if not appendToFile then
            file:write("Event Information\n")
            file:write("Start Time: " .. EscapeCSV(timeInfo) .. "\n")
            file:write(EscapeCSV(activityInfo) .. "\n")
            file:write("Start Zone: " .. EscapeCSV(zoneInfo) .. "\n")
            file:write("\n")
        end

        file:write("Raid Frame " .. frameCounter .. ": " .. (frameTitle or "Unknown") .. "\n")
        file:write(EscapeCSV(zoneInfo) .. "\n")
        file:write(EscapeCSV(timeInfo) .. "\n")
        file:write("\n")

        for raidNum, participants in pairs(raidData) do
            file:write("Raid " .. raidNum .. "\n")

            file:write("Player Name,Gear Score,Class\n")

            for _, player in ipairs(participants) do
                local csvLine = string.format("%s,%s,%s\n",
                    EscapeCSV(player.name),
                    EscapeCSV(player.gearScore),
                    EscapeCSV(player.class))
                file:write(csvLine)
            end

            file:write("\n")
        end

        file:close()

    else
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "Error: Could not create/update snapshot file")
    end
end

local function HandleTeamMembersChanged(reason, ...)
    if reason == "joined_by_self" then
        ShowEventSelectionWindow()

    elseif reason == "leaved_by_self" or reason == "dismissed" then
      if currentSession then
          EndRaidSession(reason)
      end
  end
end

local raidChatListenerEvents = {
    CHAT_MESSAGE = function(channel, relation, name, message, info)
        local playerName = X2Unit:UnitName("player")
        if name == playerName then
            local msg = string.lower(message or "")

            if msg == "!newsession" then
                local function StartNewSession()
                    local _, _, players = CollectRaidSnapshot()
                    if players and #players > 0 then
                        ShowEventSelectionWindow()
                    else
                        X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF35CAEERaidSnapshot: |cFFFF0000No raid detected")
                    end
                end

                if currentSession then
                    EndRaidSession("manual_restart")
                    StartNewSession()
                else
                    StartNewSession()
                end

            elseif msg == "!endsession" then
                if currentSession then
                    EndRaidSession("manual_end")
                else
                    X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF35CAEERaidSnapshot: |cFFFF0000No active session to end")
                end

            elseif msg == "!raidhelp" then
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF35CAEERaidSnapshot: |cFFFFD700Available commands:")
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFFFD700!newsession - End current session (if any) and/or start a new one")
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFFFD700!endsession - End current session")
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFFFD700!Raidhelp - Show this help")
            end
        end
    end
}

local raidChatListener = CreateEmptyWindow("RaidSnapshotChatListener", "UIParent")
raidChatListener:Show(false)
raidChatListener:SetHandler("OnEvent", function(this, event, ...)
    raidChatListenerEvents[event](...)
end)

local function RegisterChatEvents(window, eventTable)
    for key, _ in pairs(eventTable) do
        window:RegisterEvent(key)
    end
end
RegisterChatEvents(raidChatListener, raidChatListenerEvents)


local function EnteredWorld()
    UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_MEMBERS_CHANGED, HandleTeamMembersChanged)
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF35CAEERaidSnapshot: |cFFFFD700Automatic raid tracking activated")
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFFFD700Type !Raidhelp for available commands")
end
UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)