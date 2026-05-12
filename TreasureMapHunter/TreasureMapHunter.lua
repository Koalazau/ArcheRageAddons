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
ADDON:ImportObject(OBJECT_TYPE.EFFECT_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WEBBROWSER)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.BAG.id)

local treasureMapWindow = nil
local compassWindow = nil
local updater = nil
local refreshTimer = nil
local windowX = 350
local windowY = 70
local titleFontSize = 20
local filePath = "Treasure Map Hunter Pos.txt"
local savedPositions = {}

local TREASURE_MAP_LIST = "Treasure Map Hunter"

local currentTarget = nil
local playerX, playerY, playerAngle = 0, 0, 0
local previousAngle = 0 
local currentDistance = 0
local blinkState = false

local lastKnownMaps = {}

local PI = math.pi
local Y_OFFSET = 28672
local X_OFFSET = 21504
local UNITS_PER_DEGREE = 1024

local directionTransitions = {}
local baseFontSize = 14
local maxFontSize = 18
local baseColor = {0.5, 0.5, 0.5}
local targetColor = {0, 1, 0}

local function LoadSavedPositions()
    local file = io.open(filePath, "r")
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
    local file = io.open(filePath, "w")
    if file then
        for name, pos in pairs(savedPositions) do
            file:write(string.format("%s,%d,%d\n", name, pos.x, pos.y))
        end
        file:close()
    end
end

local function GetUIScaleFactor()
    return UIParent:GetUIScale() or 1
end

local function ApplyMouseHandlers(widget, handlers)
    for event, fn in pairs(handlers) do
        widget:SetHandler(event, fn)
    end
end

local function convertDMSToWorld(dir, deg, min, sec, offset, units_per_degree)
    local decimal_degrees = deg + (min / 60) + (sec / 3600)
    if dir == "W" or dir == "S" then
        decimal_degrees = -decimal_degrees
    end
    return (decimal_degrees * units_per_degree) + offset
end

local function parseCoordinates(coordText)
    local lonDir, lonDeg, lonMin, lonSec, latDir, latDeg, latMin, latSec = 
        coordText:match("([WE]) (%d+)°(%d+)' (%d+)\", ([NS]) (%d+)°(%d+)' (%d+)\"")
    
    if lonDir and latDir then
        local worldX = convertDMSToWorld(lonDir, tonumber(lonDeg), tonumber(lonMin), tonumber(lonSec), X_OFFSET, UNITS_PER_DEGREE)
        local worldY = convertDMSToWorld(latDir, tonumber(latDeg), tonumber(latMin), tonumber(latSec), Y_OFFSET, UNITS_PER_DEGREE)
        return worldX, worldY
    end
    return nil, nil
end

local function calculateDistance(x1, y1, x2, y2)
    local lon1 = (x1 - X_OFFSET) / UNITS_PER_DEGREE
    local lat1 = (y1 - Y_OFFSET) / UNITS_PER_DEGREE
    local lon2 = (x2 - X_OFFSET) / UNITS_PER_DEGREE
    local lat2 = (y2 - Y_OFFSET) / UNITS_PER_DEGREE
    
    local deltaLon = lon2 - lon1
    local deltaLat = lat2 - lat1
    
    local distanceInDegrees = math.sqrt(deltaLat * deltaLat + deltaLon * deltaLon)
    
    return distanceInDegrees * UNITS_PER_DEGREE
end

local function getDirectionToTarget(playerX, playerY, targetX, targetY)
    local dx = targetX - playerX
    local dy = targetY - playerY
    local angle = math.atan2(dy, dx)
    
    local normalizedAngle = angle % (2 * PI)
    if normalizedAngle < 0 then
        normalizedAngle = normalizedAngle + (2 * PI)
    end
    
    return normalizedAngle
end

local function getDistanceColor(distance)
    if distance <= 20 then
        local ratio = distance / 20
        local red = ratio
        local green = 1
        local blue = 0
        return red, green, blue
    elseif distance <= 100 then
        local ratio = (distance - 20) / 80
        local red = 1
        local green = 1 - ratio
        local blue = 0
        return red, green, blue
    else
        return 1, 0, 0
    end
end

local function getBlinkInterval(distance)
    if distance > 20 then
        return 0 
    elseif distance <= 0.1 then
        return 0.20 
    else
        if distance <= 5 then
            return 0.25 
        elseif distance <= 10 then
            return 0.30 
        elseif distance <= 15 then
            return 0.50 
        else
            return 0.75 
        end
    end
end

local function getDirectionIntensity(targetAngle, directionAngle)
    local angleDiff = math.abs(targetAngle - directionAngle)
    if angleDiff > PI then
        angleDiff = 2 * PI - angleDiff
    end
    
    local maxInfluence = PI / 4
    if angleDiff > maxInfluence then
        return 0
    end
    
    return 1 - (angleDiff / maxInfluence)
end

local function getDirectionAngle(direction)
    local angles = {
        ["N"] = PI / 2,
        ["NE"] = PI / 4,
        ["E"] = 0,
        ["SE"] = 7 * PI / 4,
        ["S"] = 3 * PI / 2,
        ["SW"] = 5 * PI / 4,
        ["W"] = PI,
        ["NW"] = 3 * PI / 4
    }
    return angles[direction] or 0
end

local function extractCoordinates(displayText)
    local coords = displayText:match("^%d+x (.+)$")
    if coords then
        return coords
    else
        return displayText
    end
end

local function compareDistance(a, b)
    local x, y, z, angle = X2Unit:GetUnitWorldPositionByTarget("player", false)
    if not x or not y or not angle then
        return
    end
    
    playerX, playerY, playerAngle = x, y, angle

    local realCoordsA = extractCoordinates(a)
    local realCoordsB = extractCoordinates(b)

    local aTargetX, aTargetY = parseCoordinates(realCoordsA)
    if not aTargetX or not aTargetY then
        return
    end
    
    local bTargetX, bTargetY = parseCoordinates(realCoordsB)
    if not bTargetX or not bTargetY then
        return
    end
    
    return calculateDistance(playerX, playerY, aTargetX, aTargetY) < calculateDistance(playerX, playerY, bTargetX, bTargetY)
end

local function ScanInventoryForTreasureMaps()
    local targetItemName = "Treasure Map with Coordinates"
    local foundCoordinates = {}
    local coordinatesCount = {} 

    for i = 1, 150 do
        local itemInfo = X2Bag:GetBagItemInfo(0, i)

        if itemInfo and itemInfo.name == targetItemName then
            local longitudeDir = itemInfo.longitudeDir or ""
            local longitudeDeg = itemInfo.longitudeDeg or 0
            local longitudeMin = itemInfo.longitudeMin or 0
            local longitudeSec = itemInfo.longitudeSec or 0

            local latitudeDir = itemInfo.latitudeDir or ""
            local latitudeDeg = itemInfo.latitudeDeg or 0
            local latitudeMin = itemInfo.latitudeMin or 0
            local latitudeSec = itemInfo.latitudeSec or 0

            local formattedCoordinates = string.format("%s %d°%d' %d\", %s %d°%d' %d\"",
                tostring(longitudeDir), tonumber(longitudeDeg), tonumber(longitudeMin), tonumber(longitudeSec),
                tostring(latitudeDir), tonumber(latitudeDeg), tonumber(latitudeMin), tonumber(latitudeSec)
            )

            if coordinatesCount[formattedCoordinates] then
                coordinatesCount[formattedCoordinates] = coordinatesCount[formattedCoordinates] + 1
            else
                coordinatesCount[formattedCoordinates] = 1
                table.insert(foundCoordinates, formattedCoordinates)
            end
        end
    end

    local displayCoordinates = {}
    for i, coords in ipairs(foundCoordinates) do
        if coordinatesCount[coords] > 1 then
            table.insert(displayCoordinates, coordinatesCount[coords] .. "x " .. coords)
        else
            table.insert(displayCoordinates, coords)
        end
    end

    if #displayCoordinates > 1 then
        table.sort(displayCoordinates, compareDistance)
    end

    return displayCoordinates
end

local function compareMapsLists(list1, list2)
    if #list1 ~= #list2 then
        return false
    end
    
    local count1 = {}
    local count2 = {}
    
    for _, coord in ipairs(list1) do
        count1[coord] = (count1[coord] or 0) + 1
    end
    
    for _, coord in ipairs(list2) do
        count2[coord] = (count2[coord] or 0) + 1
    end
    
    for coord, count in pairs(count1) do
        if count2[coord] ~= count then
            return false
        end
    end
    
    return true
end

local function isCurrentTargetValid(mapCoordinates)
    if not currentTarget then
        return false
    end
    
    for _, coords in ipairs(mapCoordinates) do
        local realCoords = extractCoordinates(coords)
        if realCoords == currentTarget then
            return true
        end
    end
    return false
end

local function getShortestRotation(from, to)
    local diff = (to - from + 180) % 360 - 180
    return from + diff
end

local function CreateCompassWindow()
    if compassWindow then
        return compassWindow
    end

    compassWindow = CreateEmptyWindow("compassWindow", "UIParent")
    compassWindow:SetExtent(200, 260) 
    compassWindow:AddAnchor("CENTER", "UIParent", 360, 0)
    compassWindow:EnableDrag(true)
    compassWindow:SetCloseOnEscape(true)

    function compassWindow:OnShow()
        SettingWindowSkin(compassWindow)
        compassWindow:SetStartAnimation(true, true)
    end
    compassWindow:SetHandler("OnShow", compassWindow.OnShow)

    function compassWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    compassWindow:SetHandler("OnDragStart", compassWindow.OnDragStart)

    function compassWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
    end
    compassWindow:SetHandler("OnDragStop", compassWindow.OnDragStop)

    local title = compassWindow:CreateChildWidget("label", "compassTitle", 0, false)
    title:SetHeight(20)
    title:SetText("Compass")
    title.style:SetFontSize(16)
    title:AddAnchor("TOP", compassWindow, 0, 10)
    title.style:SetAlign(ALIGN_CENTER)
    title.style:SetColor(1, 1, 1, 1)

    local distanceLabel = compassWindow:CreateChildWidget("label", "distanceLabel", 0, false)
    distanceLabel:SetHeight(20)
    distanceLabel:SetText("Distance: 0m")
    distanceLabel.style:SetFontSize(14)
    distanceLabel:AddAnchor("TOP", title, 0, 40)
    distanceLabel.style:SetAlign(ALIGN_CENTER)
    distanceLabel.style:SetColor(1, 1, 1, 1)
    compassWindow.distanceLabel = distanceLabel

    local closeButton = compassWindow:CreateChildWidget("button", "closeButton", 0, true)
    closeButton:SetStyle("text_default")
    closeButton:AddAnchor("TOPRIGHT", compassWindow, -10, 10)
    closeButton:SetText("X")
    closeButton:SetExtent(30, 20)
    closeButton:Show(true)

    function closeButton:OnClick()
        compassWindow:Show(false)
    end
    closeButton:SetHandler("OnClick", closeButton.OnClick)

    local webMapButton = compassWindow:CreateChildWidget("button", "webMapButton", 0, true)
    webMapButton:SetStyle("text_default")
    webMapButton:AddAnchor("BOTTOMLEFT", compassWindow, 10, -10)
    webMapButton:AddAnchor("BOTTOMRIGHT", compassWindow, -10, -10)
    webMapButton:SetText("Web Map")
    webMapButton:SetHeight(32)
    webMapButton:Show(true)

    function webMapButton:OnClick()
        if currentTarget then
            if _G.OpenWebMapWithCoordinates then
                _G.OpenWebMapWithCoordinates(currentTarget)
            end
        end
    end
    webMapButton:SetHandler("OnClick", webMapButton.OnClick)

    local directions = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
    local positions = {
        {0, -60},    
        {42, -42},   
        {60, 0},     
        {42, 42},    
        {0, 60},     
        {-42, 42},   
        {-60, 0},    
        {-42, -42}   
    }

    compassWindow.directionLabels = {}
    for i, dir in ipairs(directions) do
        local label = compassWindow:CreateChildWidget("label", "dir_" .. dir, 0, false)
        label:SetHeight(20)
        label:SetText(dir)
        label.style:SetFontSize(baseFontSize)
        label:AddAnchor("CENTER", compassWindow, positions[i][1], positions[i][2] + 15) 
        label.style:SetAlign(ALIGN_CENTER)
        label.style:SetColor(baseColor[1], baseColor[2], baseColor[3], 1)
        label:Show(true)
        compassWindow.directionLabels[dir] = label
        
        directionTransitions[dir] = {
            currentIntensity = 0,
            targetIntensity = 0
        }
    end

    local playerCompass = compassWindow:CreateEffectDrawable("Addon/TreasureMapHunter/Icones/Arrow.dds", "overlay")
    
    if playerCompass then
        playerCompass:SetVisible(true)
        playerCompass:SetExtent(30, 30)
        playerCompass:AddAnchor("CENTER", compassWindow, 0, 15) 
        
        playerCompass:SetEffectPriority(1, "alpha", 0.5, 0.0)
        playerCompass:SetEffectInitialColor(1, 1, 1, 1, 1) 
        playerCompass:SetEffectFinalColor(1, 1, 1, 1, 1)
        
        playerCompass:SetMoveEffectType(1, "circle", 0, 0, 0, 0)
        playerCompass:SetMoveEffectCircle(1, 0, 0)
        
        compassWindow.playerCompass = playerCompass
    end

    return compassWindow
end

local function UpdateCompass(dt)
    if not compassWindow or not compassWindow:IsVisible() or not currentTarget then
        return
    end

    local x, y, z, angle = X2Unit:GetUnitWorldPositionByTarget("player", false)
    if not x or not y or not angle then
        return
    end

    playerX, playerY, playerAngle = x, y, angle

    local targetX, targetY = parseCoordinates(currentTarget)
    if not targetX or not targetY then
        return
    end

    currentDistance = calculateDistance(playerX, playerY, targetX, targetY)
    
    local angleDegrees = math.deg(playerAngle)
    local rotationAngle = (-angleDegrees + 180) % 360
    local targetAngle = getShortestRotation(previousAngle, rotationAngle)
    
    if compassWindow.playerCompass then
        compassWindow.playerCompass:SetMoveEffectCircle(1, previousAngle, targetAngle)
        compassWindow.playerCompass:SetStartEffect(true)
        previousAngle = targetAngle % 360
    end
end

local function CreateRefreshTimer()
    if refreshTimer then
        return
    end

    refreshTimer = CreateEmptyWindow("refreshTimer", "UIParent")
    refreshTimer:Show(true)

    local snakeSpeed = 0.5 
    local snakeLength = 4 
    local directions = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
    local snakeActive = false

    function refreshTimer:OnUpdate(dt)
        if not compassWindow or not compassWindow:IsVisible() or not currentTarget then
            return
        end

        local currentTime = os.clock()
        
        if currentDistance <= 3.0 and currentDistance > 0 then
            if not snakeActive then
                snakeActive = true
                for _, dir in ipairs(directions) do
                    if compassWindow.directionLabels[dir] then
                        compassWindow.directionLabels[dir].style:SetColor(baseColor[1], baseColor[2], baseColor[3], 1)
                        compassWindow.directionLabels[dir].style:SetFontSize(baseFontSize)
                    end
                end
            end
            
            local totalDirections = #directions
            local cycleTime = currentTime % snakeSpeed 
            local cycleProgress = cycleTime / snakeSpeed 
            local currentHeadPosition = math.floor(cycleProgress * totalDirections) + 1
            
            for _, dir in ipairs(directions) do
                if compassWindow.directionLabels[dir] then
                    compassWindow.directionLabels[dir].style:SetColor(baseColor[1], baseColor[2], baseColor[3], 1)
                    compassWindow.directionLabels[dir].style:SetFontSize(baseFontSize)
                end
            end
            
            for i = 0, snakeLength - 1 do
                local segmentIndex = ((currentHeadPosition - i - 1) % totalDirections) + 1
                if segmentIndex < 1 then segmentIndex = segmentIndex + totalDirections end
                local dir = directions[segmentIndex]
                
                if compassWindow.directionLabels[dir] then
                    local intensity = (snakeLength - i) / snakeLength
                    
                    local red = baseColor[1] + (targetColor[1] - baseColor[1]) * intensity
                    local green = baseColor[2] + (targetColor[2] - baseColor[2]) * intensity
                    local blue = baseColor[3] + (targetColor[3] - baseColor[3]) * intensity
                    
                    local fontSize = baseFontSize + (maxFontSize - baseFontSize) * intensity
                    
                    compassWindow.directionLabels[dir].style:SetColor(red, green, blue, 1)
                    compassWindow.directionLabels[dir].style:SetFontSize(math.floor(fontSize))
                end
            end
        else
            if snakeActive then
                snakeActive = false
                for _, dir in ipairs(directions) do
                    if compassWindow.directionLabels[dir] then
                        compassWindow.directionLabels[dir].style:SetColor(baseColor[1], baseColor[2], baseColor[3], 1)
                        compassWindow.directionLabels[dir].style:SetFontSize(baseFontSize)
                    end
                end
            end
        end
        
        if currentDistance <= 20 and currentDistance > 0 then
            local blinkInterval = getBlinkInterval(currentDistance)
            if blinkInterval > 0 then
                local timeInCycle = (currentTime % blinkInterval) / blinkInterval
                blinkState = timeInCycle < 0.5
                
                local red, green, blue = getDistanceColor(currentDistance)
                if blinkState then
                    compassWindow.distanceLabel.style:SetColor(red, green, blue, 1)
                else
                    compassWindow.distanceLabel.style:SetColor(red * 0.3, green * 0.3, blue * 0.3, 1)
                end
            else
                local red, green, blue = getDistanceColor(currentDistance)
                compassWindow.distanceLabel.style:SetColor(red, green, blue, 1)
            end
        else
            local red, green, blue = getDistanceColor(currentDistance)
            compassWindow.distanceLabel.style:SetColor(red, green, blue, 1)
        end
        
        local distanceText = string.format("Distance: %.1fm", currentDistance)
        compassWindow.distanceLabel:SetText(distanceText)
    end

    refreshTimer:SetHandler("OnUpdate", refreshTimer.OnUpdate)
end

local function RecreateComboBox()
    if treasureMapWindow.mapComboBox then
        treasureMapWindow.mapComboBox:Show(false)
        treasureMapWindow.mapComboBox = nil
    end

    local mapCoordinates = lastKnownMaps
    local comboBoxOptions = {}
    
    if #mapCoordinates > 0 then
        for _, coords in ipairs(mapCoordinates) do
            table.insert(comboBoxOptions, {
                text = coords,
                handler = function(self)
                    currentTarget = extractCoordinates(self:GetText())
                    if not compassWindow then
                        compassWindow = CreateCompassWindow()
                    end
                    if _G.UpdateWebMapCoordinates then
                        _G.UpdateWebMapCoordinates(currentTarget)
                    end
                    
                    if not refreshTimer then
                        CreateRefreshTimer()
                    end
                    compassWindow:Show(true)
                end
            })
        end
    else
        table.insert(comboBoxOptions, {
            text = "No treasure maps found.",
        })
    end

    local triggerWidth = 200
    local triggerHeight = 30
    local maxVisibleOptions = 5
    local optionHeight = 25
    local comboBoxAnchor = "TOPLEFT"
    local comboBoxAnchorParent = treasureMapWindow
    local comboBoxOffsetX = 150
    local comboBoxOffsetY = 60

    local mapComboBox = CreateComboBox(treasureMapWindow, triggerWidth, triggerHeight, maxVisibleOptions, comboBoxOptions, optionHeight, comboBoxAnchor, comboBoxAnchorParent, comboBoxOffsetX, comboBoxOffsetY)
    treasureMapWindow.mapComboBox = mapComboBox
    mapComboBox:Show(true)

    if #mapCoordinates == 0 then
        mapComboBox:SetText("No maps available")
        mapComboBox:Enable(false)
        treasureMapWindow.clearSelectionButton:Enable(false)
    else
        mapComboBox:Enable(true)
        treasureMapWindow.clearSelectionButton:Enable(true)
        
        if currentTarget then
            for i, option in ipairs(comboBoxOptions) do
                if extractCoordinates(option.text) == currentTarget then
                    mapComboBox:SetText(option.text)
                    mapComboBox:Select(i)
                    break
                end
            end
        else
            mapComboBox:SetText("Select a treasure map")
        end
    end
end

local function CheckInventoryChanges()
    local currentMaps = ScanInventoryForTreasureMaps()
    
    if not compareMapsLists(currentMaps, lastKnownMaps) then
        if not isCurrentTargetValid(currentMaps) then
            currentTarget = nil
            if compassWindow then
                compassWindow:Show(false)
            end
            if _G.CloseWebMapWindow then
                _G.CloseWebMapWindow()
            end
        end
        
        lastKnownMaps = currentMaps
        RecreateComboBox()
    end
end

local function ClearSelection()
    currentTarget = nil
    if compassWindow then
        compassWindow:Show(false)
    end
    if _G.CloseWebMapWindow then
        _G.CloseWebMapWindow()
    end
    if treasureMapWindow and treasureMapWindow.mapComboBox then
        treasureMapWindow.mapComboBox:ResetDisplay()
        treasureMapWindow.mapComboBox:Show(true)
        treasureMapWindow.mapComboBox:SetText("Select a treasure map")
    end
end

local function CreateTreasureMapWindow()
    if treasureMapWindow then
        if not treasureMapWindow.mapComboBox then
            RecreateComboBox()
        end
        return treasureMapWindow
    end

    treasureMapWindow = CreateEmptyWindow("treasureMapList", "UIParent")
    treasureMapWindow:SetExtent(windowX, windowY)
    treasureMapWindow:AddAnchor("CENTER", "UIParent", 0, -350)
    treasureMapWindow:EnableDrag(true)
    treasureMapWindow:SetCloseOnEscape(true)

    function treasureMapWindow:OnShow()
        SettingWindowSkin(treasureMapWindow)
        treasureMapWindow:SetStartAnimation(true, true)
        if not treasureMapWindow.mapComboBox then
            RecreateComboBox()
        end
    end
    treasureMapWindow:SetHandler("OnShow", treasureMapWindow.OnShow)

    function treasureMapWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    treasureMapWindow:SetHandler("OnDragStart", treasureMapWindow.OnDragStart)

    function treasureMapWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
    end
    treasureMapWindow:SetHandler("OnDragStop", treasureMapWindow.OnDragStop)

    local windowTitle = treasureMapWindow:CreateChildWidget("label", "treasureMapTitle", 0, false)
    windowTitle:SetHeight(30)
    windowTitle:SetText(TREASURE_MAP_LIST)
    windowTitle.style:SetFontSize(titleFontSize)
    windowTitle:AddAnchor("TOP", treasureMapWindow, 0, 10)
    windowTitle.style:SetAlign(ALIGN_CENTER)
    windowTitle.style:SetColor(1, 1, 1, 1)

    local closeButton = treasureMapWindow:CreateChildWidget("button", "closeButton", 0, true)
    closeButton:SetStyle("text_default")
    closeButton:AddAnchor("TOPRIGHT", treasureMapWindow, -10, 10)
    closeButton:SetText("X")
    closeButton:SetExtent(45, 30)
    closeButton:Show(true)

    function closeButton:OnClick()
        treasureMapWindow:Show(false)
    end
    closeButton:SetHandler("OnClick", closeButton.OnClick)

    local clearSelectionButton = treasureMapWindow:CreateChildWidget("button", "clearSelectionButton", 0, true)
    clearSelectionButton:SetStyle("text_default")
    clearSelectionButton:AddAnchor("TOPLEFT", treasureMapWindow, 20, 60)
    clearSelectionButton:SetText("Clear Selection")
    clearSelectionButton:SetExtent(120, 30)
    clearSelectionButton:Show(true)

    function clearSelectionButton:OnClick()
        ClearSelection()
    end
    clearSelectionButton:SetHandler("OnClick", clearSelectionButton.OnClick)
    treasureMapWindow.clearSelectionButton = clearSelectionButton

    return treasureMapWindow
end

local treasureMapToggleButton = nil
local buttonSize = 23

local function CreateTreasureMapButton()
    if treasureMapToggleButton then return end
    
    treasureMapToggleButton = UIParent:CreateWidget("button", "treasureMapToggle", "UIParent")
    treasureMapToggleButton:SetExtent(buttonSize, buttonSize)
    treasureMapToggleButton:SetText("")
    treasureMapToggleButton:Show(true)
    treasureMapToggleButton:EnableDrag(true)

    local iconOverlay = treasureMapToggleButton:CreateIconDrawable("artwork")
    iconOverlay:SetExtent(buttonSize, buttonSize)
    iconOverlay:AddAnchor("CENTER", treasureMapToggleButton, 0, 0)
    iconOverlay:SetVisible(true)
    iconOverlay:AddTexture("Addon/TreasureMapHunter/Icones/Main.dds")
    treasureMapToggleButton.iconOverlay = iconOverlay

    local hoverOverlay = treasureMapToggleButton:CreateIconDrawable("artwork")
    hoverOverlay:AddTexture("Addon/TreasureMapHunter/Icones/Main_hover.dds")
    hoverOverlay:SetExtent(buttonSize, buttonSize)
    hoverOverlay:AddAnchor("CENTER", treasureMapToggleButton, 0, 0)
    hoverOverlay:SetVisible(false)
    treasureMapToggleButton.hoverOverlay = hoverOverlay

    local OnClickOverlay = treasureMapToggleButton:CreateIconDrawable("artwork")
    OnClickOverlay:AddTexture("Addon/TreasureMapHunter/Icones/Main_click.dds")
    OnClickOverlay:SetExtent(buttonSize, buttonSize)
    OnClickOverlay:AddAnchor("CENTER", treasureMapToggleButton, 0, 0)
    OnClickOverlay:SetVisible(false)
    treasureMapToggleButton.OnClickOverlay = OnClickOverlay

    local Tooltip = treasureMapToggleButton:CreateChildWidget("label", "Tooltip", 0, true)
    Tooltip:SetHeight(30)
    Tooltip:SetAutoResize(true)
    local Tooltipbackground = Tooltip:CreateNinePartDrawable("ui/common/hud.dds", "background")
    Tooltipbackground:SetCoords(733, 169, 14, 15)
    Tooltipbackground:SetInset(7, 7, 6, 7)
    Tooltipbackground:AddAnchor("TOPLEFT", Tooltip, -10, 0)
    Tooltipbackground:AddAnchor("BOTTOMRIGHT", Tooltip, 10, 0)
    Tooltip:SetText("Treasure Map Hunter")
    Tooltip.style:SetAlign(ALIGN_CENTER)
    Tooltip.style:SetColorByKey("brown")
    Tooltip.style:SetFontSize(12)
    Tooltip:AddAnchor("TOPLEFT", treasureMapToggleButton, -20, -40)
    Tooltip:Show(false)
    treasureMapToggleButton.Tooltip = Tooltip

    local mouseHandlers = {
        OnEnter = function(self)
            if self.hoverOverlay then
                self.hoverOverlay:SetVisible(true)
            end
            if self.Tooltip then
                self.Tooltip:Show(true)
            end
        end,
        OnLeave = function(self)
            if self.hoverOverlay then
                self.hoverOverlay:SetVisible(false)
                self.OnClickOverlay:SetVisible(false)
            end
            if self.Tooltip then
                self.Tooltip:Show(false)
            end
        end,
    }

    ApplyMouseHandlers(treasureMapToggleButton, mouseHandlers)

    if savedPositions["treasureMapToggle"] then
        local uiScale = GetUIScaleFactor()
        local scaledX = savedPositions["treasureMapToggle"].x / uiScale
        local scaledY = savedPositions["treasureMapToggle"].y / uiScale
        treasureMapToggleButton:AddAnchor("TOPLEFT", "UIParent", scaledX, scaledY)
    else
        treasureMapToggleButton:AddAnchor("CENTER", "UIParent", 0, 0)
    end

    function treasureMapToggleButton:OnClick()
        if not treasureMapWindow then
            CreateTreasureMapWindow()
            treasureMapWindow:Show(true)
        else
            if treasureMapWindow:IsVisible() then
                treasureMapWindow:Show(false)
            else
                treasureMapWindow:Show(true)
            end
        end
    end
    treasureMapToggleButton:SetHandler("OnClick", treasureMapToggleButton.OnClick)

    function treasureMapToggleButton:OnMouseDown()
        if self.OnClickOverlay then
            self.OnClickOverlay:SetVisible(true)
        end
    end
    treasureMapToggleButton:SetHandler("OnMouseDown", treasureMapToggleButton.OnMouseDown)

    function treasureMapToggleButton:OnMouseUp()
        if self.OnClickOverlay then
            self.OnClickOverlay:SetVisible(false)
        end
    end
    treasureMapToggleButton:SetHandler("OnMouseUp", treasureMapToggleButton.OnMouseUp)

    function treasureMapToggleButton:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    treasureMapToggleButton:SetHandler("OnDragStart", treasureMapToggleButton.OnDragStart)

    function treasureMapToggleButton:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
        local correctedX, correctedY = self:CorrectOffsetByScreen()
        SaveButtonPosition("treasureMapToggle", correctedX, correctedY)
    end
    treasureMapToggleButton:SetHandler("OnDragStop", treasureMapToggleButton.OnDragStop)
end

local function CreateUpdater()
    if updater then
        return
    end

    updater = CreateEmptyWindow("treasureMapUpdater", "UIParent")
    updater:Show(true)

    local compassUpdateCounter = 0
    local inventoryUpdateCounter = 0

    function updater:OnUpdate(dt)
        UpdateCompass(dt)
        
        if compassWindow and compassWindow:IsVisible() and currentTarget then
            local targetX, targetY = parseCoordinates(currentTarget)
            if targetX and targetY then
                local targetAngle = getDirectionToTarget(playerX, playerY, targetX, targetY)
                
                local directions = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
                for _, dir in ipairs(directions) do
                    local dirAngle = getDirectionAngle(dir)
                    local intensity = getDirectionIntensity(targetAngle, dirAngle)
                    
                    local red = baseColor[1] + (targetColor[1] - baseColor[1]) * intensity
                    local green = baseColor[2] + (targetColor[2] - baseColor[2]) * intensity
                    local blue = baseColor[3] + (targetColor[3] - baseColor[3]) * intensity
                    local fontSize = baseFontSize + (maxFontSize - baseFontSize) * intensity
                    
                    if compassWindow.directionLabels[dir] then
                        compassWindow.directionLabels[dir].style:SetColor(red, green, blue, 1)
                        compassWindow.directionLabels[dir].style:SetFontSize(math.floor(fontSize))
                    end
                end
            end
        end
        
        inventoryUpdateCounter = inventoryUpdateCounter + dt
        if inventoryUpdateCounter >= 0.5 then 
            CheckInventoryChanges()
            inventoryUpdateCounter = 0
        end
    end

    updater:SetHandler("OnUpdate", updater.OnUpdate)
end

local function EnteredWorld()
    LoadSavedPositions() 
    lastKnownMaps = ScanInventoryForTreasureMaps()
    
    CreateTreasureMapButton()
    CreateUpdater()
end

UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)