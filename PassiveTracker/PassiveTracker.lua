ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)

ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)

local timeUpdater = CreateEmptyWindow("timeUpdater", "UIParent")
timeUpdater:Show(true)

local counter = 0
local trackedBuffs = {}
local buffIcons = {}
local iconSize = 35
local iconSpacing = iconSize + 5  
local maxIcons = 7 
local iconCounter = 0
local filePath = "SavedBuffWindowPosition.txt"
local savedPositions = {}
local savedSkillIcons = {}
local skillCooldowns = {}
local previousSkillStates = {}

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

local function SaveWindowPosition(name, x, y)
    savedPositions[name] = { x = x, y = y }
    local file = io.open(filePath, "w")
    for name, pos in pairs(savedPositions) do
        file:write(string.format("%s,%d,%d\n", name, pos.x, pos.y))
    end
    file:close()
end

local function CalculateWindowDimensions()
    local windowWidth = (maxIcons * iconSpacing) + 10  
    local windowHeight = (2 * iconSize) + 15           
    return windowWidth, windowHeight
end

local function GetCustomIcon(buffName)
    for buffKey, buffNames in pairs(buffDefinitions) do
        if buffNames.customIcon then
            if type(buffNames[1]) == "table" then
                for _, primaryBuffName in ipairs(buffNames[1]) do
                    if buffName == primaryBuffName then
                        return buffNames.customIcon
                    end
                end
            elseif buffNames[1] and buffName == buffNames[1] then
                return buffNames.customIcon
            end
            if buffNames[2] and buffName == buffNames[2] then
                return buffNames.customIcon
            end
        end
    end
    
    for skillName, skillData in pairs(SkillDefinitions) do
        if skillData.customIcon and buffName == skillName then
            return skillData.customIcon
        end
    end
    
    return nil
end

local buffWindow = CreateEmptyWindow("BuffWindow", "UIParent")
if buffWindow then    

    local windowWidth, windowHeight = CalculateWindowDimensions()
    buffWindow:SetExtent(windowWidth, windowHeight)
    
    LoadSavedPositions()
    if savedPositions["BuffWindow"] then
        local X = savedPositions["BuffWindow"].x
        local Y = savedPositions["BuffWindow"].y      
        buffWindow:AddAnchor("TOPLEFT", "UIParent", X, Y)
    else
        buffWindow:AddAnchor("CENTER", "UIParent", 0, 0) 
    end

    local background = buffWindow:CreateColorDrawable(0, 0, 0, 0.5, "background")
    background:AddAnchor("TOPLEFT", buffWindow, 0, 0)
    background:AddAnchor("BOTTOMRIGHT", buffWindow, 0, 0)

    local function OnShow()
        if buffWindow.ShowProc ~= nil then
            buffWindow:ShowProc()
        end
        buffWindow:SetStartAnimation(true, true)
    end
    buffWindow:SetHandler("OnShow", OnShow)

    buffWindow:EnableDrag(true)

    function buffWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    buffWindow:SetHandler("OnDragStart", buffWindow.OnDragStart)

    function buffWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
        local correctedX, correctedY = self:CorrectOffsetByScreen()
        SaveWindowPosition("BuffWindow", correctedX, correctedY)
    end
    buffWindow:SetHandler("OnDragStop", buffWindow.OnDragStop)

    buffWindow:Show(true)
else    
    return
end

local function CreateBuffIcon(buffName, iconTexture, duration, overlayColor, row)   
    if buffWindow then
        local icon = buffWindow:CreateIconDrawable("artwork")       
        icon:SetExtent(iconSize, iconSize)
        
        local yOffset = 5 + (row * (iconSize + 5))
        icon:AddAnchor("TOPLEFT", buffWindow, 0, yOffset) 
        
        icon:AddTexture(iconTexture)
        icon:SetVisible(true)

        local overlay = buffWindow:CreateColorDrawable(overlayColor[1], overlayColor[2], overlayColor[3], overlayColor[4], "overlay")
        overlay:AddAnchor("TOPLEFT", icon, 0, 0)
        overlay:AddAnchor("BOTTOMRIGHT", icon, 0, 0)
        overlay:SetVisible(true)

        local BuffDuration = buffWindow:CreateChildWidget("label", "BuffDuration", 0, true)
        BuffDuration:Show(true)
        BuffDuration:EnablePick(false)
        BuffDuration.style:SetColor(1, 1, 0, 1.0)
        BuffDuration.style:SetOutline(true)
        BuffDuration.style:SetFontSize(math.floor(iconSize * 0.7))  
        BuffDuration.style:SetAlign(ALIGN_CENTER)
        BuffDuration:AddAnchor("CENTER", icon)
        BuffDuration:SetText(duration or "")

        return { window = icon, timer = BuffDuration, overlay = overlay, row = row }
    else        
        return nil
    end
end

local function UpdateBuffIcons()
    local topRowBuffs = {}
    local bottomRowBuffs = {}
    
    for buffName, buffData in pairs(trackedBuffs) do
        local duration = tonumber(buffData.duration) 
        if duration then 
            duration = duration
        else
            duration = math.huge
        end
        
        local targetRow = buffData.row or 0 
        
        if targetRow == 0 then
            table.insert(topRowBuffs, { name = buffName, duration = duration })
        else
            table.insert(bottomRowBuffs, { name = buffName, duration = duration })
        end
    end
    
    table.sort(topRowBuffs, function(a, b) return a.duration < b.duration end)
    table.sort(bottomRowBuffs, function(a, b) return a.duration < b.duration end)
    
    local xOffset = 5 
    local iconCount = 0
    for _, buff in ipairs(topRowBuffs) do
        local buffName = buff.name
        if buffIcons[buffName] and iconCount < maxIcons then
            buffIcons[buffName].window:AddAnchor("TOPLEFT", buffWindow, xOffset, 5)
            buffIcons[buffName].timer:SetText(trackedBuffs[buffName].duration)
            xOffset = xOffset + iconSpacing
            iconCount = iconCount + 1
        end
    end
    
    xOffset = 5  
    iconCount = 0
    for _, buff in ipairs(bottomRowBuffs) do
        local buffName = buff.name
        if buffIcons[buffName] and iconCount < maxIcons then
            buffIcons[buffName].window:AddAnchor("TOPLEFT", buffWindow, xOffset, 5 + iconSize + 5) 
            buffIcons[buffName].timer:SetText(trackedBuffs[buffName].duration)
            xOffset = xOffset + iconSpacing
            iconCount = iconCount + 1
        end
    end
end

local function RemoveBuffIcon(buffName)
    if buffIcons[buffName] then
        buffIcons[buffName].window:Show(false)
        buffIcons[buffName].overlay:Show(false)
        buffIcons[buffName].timer:Show(false)
        buffIcons[buffName] = nil
    end
end

local function TrackBuff(buffName, iconTexture, duration, overlayColor, row)
    iconCounter = iconCounter + 1
    local iconId = buffName .. tostring(iconCounter)
    local icon = CreateBuffIcon(iconId, iconTexture, duration, overlayColor, row)
    if icon then
        trackedBuffs[iconId] = { 
            duration = duration, 
            buffName = buffName,
            row = row or 0 
        }
        buffIcons[iconId] = icon
        UpdateBuffIcons()        
    end
end

local function CheckAndTrackBuffs()
    local player = "player"
    local hiddenBuffCount = X2Unit:UnitHiddenBuffCount(player)
    local buffCount = X2Unit:UnitBuffCount(player)
    local debuffCount = X2Unit:UnitDeBuffCount(player)

    local allBuffs = {}

    for i = 1, hiddenBuffCount do
        local buff = X2Unit:UnitHiddenBuffTooltip(player, i)
        if buff and buff.name then
            table.insert(allBuffs, buff)
        end
    end

    for i = 1, buffCount do
        local buff = X2Unit:UnitBuffTooltip(player, i)
        if buff and buff.name then
            table.insert(allBuffs, buff)
        end
    end

    for i = 1, debuffCount do
        local buff = X2Unit:UnitDeBuffTooltip(player, i)
        if buff and buff.name then
            table.insert(allBuffs, buff)
        end
    end

    local buffVariables = {}
    for _, buffNames in pairs(buffDefinitions) do
        if type(buffNames[1]) == "table" then
            for _, buffName in ipairs(buffNames[1]) do
                buffVariables[buffName] = { isActive = false, duration = nil }
            end
        elseif buffNames[1] then 
            buffVariables[buffNames[1]] = { isActive = false, duration = nil }
        end
        if buffNames[2] then 
            buffVariables[buffNames[2]] = { isActive = false, duration = nil }
        end
    end

    for _, buff in ipairs(allBuffs) do
        if buff and buff.name then
            for buffKey, buffNames in pairs(buffDefinitions) do
                if type(buffNames[1]) == "table" then
                    for _, buffName in ipairs(buffNames[1]) do
                        if buff.name == buffName then
                            local duration = buff["timeLeft"] and tostring(math.floor(buff["timeLeft"] / 1000)) or ""
                            buffVariables[buffName] = { isActive = true, duration = duration, path = buff.path }
                        end
                    end
                elseif buffNames[1] and buff.name == buffNames[1] then
                    local duration = buff["timeLeft"] and tostring(math.floor(buff["timeLeft"] / 1000)) or ""
                    buffVariables[buffNames[1]] = { isActive = true, duration = duration, path = buff.path }
                end
            end
        end
    end

    for _, buff in ipairs(allBuffs) do
        if buff and buff.name then
            for buffKey, buffNames in pairs(buffDefinitions) do
                local buff1Active = false
                if type(buffNames[1]) == "table" then
                    for _, buffName in ipairs(buffNames[1]) do
                        if buffVariables[buffName] and buffVariables[buffName].isActive then
                            buff1Active = true
                            break
                        end
                    end
                elseif buffNames[1] and buffVariables[buffNames[1]] and buffVariables[buffNames[1]].isActive then
                    buff1Active = true
                end

                if buff.name == buffNames[2] and not buff1Active then
                    local duration = buff["timeLeft"] and tostring(math.floor(buff["timeLeft"] / 1000)) or ""
                    buffVariables[buffNames[2]] = { isActive = true, duration = duration, path = buff.path }
                end
            end
        end
    end

    for buffKey, buffNames in pairs(buffDefinitions) do
        local buff1Found = false
        if type(buffNames[1]) == "table" then
            for _, buffName in ipairs(buffNames[1]) do
                for _, buff in ipairs(allBuffs) do
                    if buff and buff.name == buffName then
                        buff1Found = true
                        break
                    end
                end
                if buff1Found then
                    break
                end
            end
        elseif buffNames[1] then 
            for _, buff in ipairs(allBuffs) do
                if buff and buff.name == buffNames[1] then
                    buff1Found = true
                    break
                end
            end
        end

        if not buff1Found then
            if type(buffNames[1]) == "table" then
                for _, buffName in ipairs(buffNames[1]) do
                    buffVariables[buffName] = { isActive = false, duration = nil }
                end
            elseif buffNames[1] then
                buffVariables[buffNames[1]] = { isActive = false, duration = nil }
            end
        end
    end

    for buffName, buffData in pairs(buffVariables) do
        if buffData and buffData.isActive then
            local overlayColor = nil
            local customIcon = GetCustomIcon(buffName)
            local iconTexture = customIcon or buffData.path
            
            for buffKey, buffNames in pairs(buffDefinitions) do
                if type(buffNames[1]) == "table" then
                    local isPrimary = false
                    for _, primaryBuffName in ipairs(buffNames[1]) do
                        if buffName == primaryBuffName then
                            overlayColor = {0, 1, 0, 0.3}
                            isPrimary = true
                            break
                        end
                    end
                    if not isPrimary and buffName == buffNames[2] then
                        overlayColor = {1, 0, 0, 0.2}
                    end
                elseif buffName == buffNames[1] then
                    overlayColor = {0, 1, 0, 0.3}
                elseif buffName == buffNames[2] then
                    overlayColor = {1, 0, 0, 0.2}
                end
            end

            local iconExists = false
            for iconId, trackedBuffData in pairs(trackedBuffs) do
                if trackedBuffData.buffName == buffName and not trackedBuffData.isSkillCooldown then
                    iconExists = true
                    trackedBuffData.duration = buffData.duration
                    if buffIcons[iconId] then
                        buffIcons[iconId].timer:SetText(buffData.duration)
                        
                        local isSecondaryBuff = false
                        for buffKey, buffNames in pairs(buffDefinitions) do
                            if buffName == buffNames[2] then
                                isSecondaryBuff = true
                                break
                            end
                        end
                        
                        if isSecondaryBuff then
                            buffIcons[iconId].timer.style:SetColor(1, 0, 0, 1.0) 
                        else
                            buffIcons[iconId].timer.style:SetColor(0, 1, 0, 1.0) 
                        end
                    end
                    break
                end
            end

            if not iconExists then
                local targetRow = 0 
                local isSecondaryBuff = false
                for buffKey, buffNames in pairs(buffDefinitions) do
                    if type(buffNames[1]) == "table" then
                        if buffName == buffNames[2] then
                            isSecondaryBuff = true
                            break
                        end
                    elseif buffName == buffNames[2] then
                        isSecondaryBuff = true
                        break
                    end
                end
                
                if isSecondaryBuff then
                    targetRow = 1 
                end
                
                TrackBuff(buffName, iconTexture, buffData.duration, overlayColor, targetRow)
            end
        else
            local iconsToRemove = {}
            for iconId, trackedBuffData in pairs(trackedBuffs) do
                if trackedBuffData.buffName == buffName and not trackedBuffData.isSkillCooldown then
                    table.insert(iconsToRemove, iconId)
                end
            end
            
            for _, iconId in ipairs(iconsToRemove) do
                RemoveBuffIcon(iconId)
                trackedBuffs[iconId] = nil
            end
        end
    end

    for skillName, skillData in pairs(SkillDefinitions) do
        if not skillData.whenBuffAppears then
            local skillFound = false
            local skillIconPath = nil
            local currentDuration = nil
            
            for _, buff in ipairs(allBuffs) do
                if buff and buff.name == skillName then
                    skillFound = true
                    local customIcon = GetCustomIcon(skillName)
                    skillIconPath = customIcon or buff.path
                    currentDuration = buff["timeLeft"] and tostring(math.floor(buff["timeLeft"] / 1000)) or ""
                    
                    if skillIconPath then
                        savedSkillIcons[skillName] = skillIconPath
                    end
                    
                    local overlayColor = {0, 1, 0, 0.3}
                    local iconExists = false
                    for iconId, trackedBuffData in pairs(trackedBuffs) do
                        if trackedBuffData.buffName == skillName and not trackedBuffData.isSkillCooldown then
                            iconExists = true
                            trackedBuffData.duration = currentDuration
                            trackedBuffData.row = 0  
                            if buffIcons[iconId] then
                                buffIcons[iconId].timer:SetText(currentDuration)
                                buffIcons[iconId].timer.style:SetColor(0, 1, 0, 1.0)
                                buffIcons[iconId].overlay:SetColor(overlayColor[1], overlayColor[2], overlayColor[3], overlayColor[4])
                            end
                            break
                        end
                    end
                    
                    if not iconExists then
                        TrackBuff(skillName, skillIconPath, currentDuration, overlayColor, 0)  
                    end
                    
                    previousSkillStates[skillName] = {
                        isActive = true,
                        duration = tonumber(currentDuration) or 0,
                        lastSeenTime = os.time()
                    }
                    break
                end
            end
            
            if not skillFound then
                local prevState = previousSkillStates[skillName]
                
                if prevState and prevState.isActive then
                    if savedSkillIcons[skillName] and not skillCooldowns[skillName] then
                        skillCooldowns[skillName] = {
                            endTime = os.time() + skillData.cooldown,
                            iconPath = savedSkillIcons[skillName]
                        }
                    end
                end
                
                if prevState then
                    previousSkillStates[skillName].isActive = false
                else
                    previousSkillStates[skillName] = { isActive = false }
                end
                
                local iconsToRemove = {}
                for iconId, trackedBuffData in pairs(trackedBuffs) do
                    if trackedBuffData.buffName == skillName and not trackedBuffData.isSkillCooldown then
                        table.insert(iconsToRemove, iconId)
                    end
                end
                
                for _, iconId in ipairs(iconsToRemove) do
                    RemoveBuffIcon(iconId)
                    trackedBuffs[iconId] = nil
                end
            end
        end
    end

    for skillName, skillData in pairs(SkillDefinitions) do
        if skillData.whenBuffAppears then
            local skillFound = false
            local skillIconPath = nil
            local currentDuration = nil
            
            for _, buff in ipairs(allBuffs) do
                if buff and buff.name == skillName then
                    skillFound = true
                    local customIcon = GetCustomIcon(skillName)
                    skillIconPath = customIcon or buff.path
                    currentDuration = buff["timeLeft"] and tostring(math.floor(buff["timeLeft"] / 1000)) or ""
                    
                    if skillIconPath then
                        savedSkillIcons[skillName] = skillIconPath
                    end
                    
                    local prevState = previousSkillStates[skillName]
                    local justActivated = not prevState or not prevState.isActive
                    
                    if justActivated then
                        skillCooldowns[skillName] = {
                            endTime = os.time() + skillData.cooldown,
                            iconPath = skillIconPath,
                            startTime = os.time()
                        }
                    end
                    
                    previousSkillStates[skillName] = {
                        isActive = true,
                        duration = tonumber(currentDuration) or 0,
                        lastSeenTime = os.time()
                    }
                    break
                end
            end
            
            if not skillFound then
                local prevState = previousSkillStates[skillName]
                if prevState and prevState.isActive then
                    previousSkillStates[skillName].isActive = false
                else
                    previousSkillStates[skillName] = { isActive = false }
                end
            end
            
            local shouldShowBuff = skillFound
            local shouldShowCooldown = false
            
            if not shouldShowBuff and skillCooldowns[skillName] then
                local currentTime = os.time()
                local remainingTime = skillCooldowns[skillName].endTime - currentTime
                if remainingTime > 0 then
                    shouldShowCooldown = true
                    currentDuration = tostring(remainingTime)
                    skillIconPath = skillCooldowns[skillName].iconPath
                else
                    skillCooldowns[skillName] = nil
                end
            end
            
            if shouldShowBuff then
                local overlayColor = {0, 1, 0, 0.3}  
                local iconExists = false
                for iconId, trackedBuffData in pairs(trackedBuffs) do
                    if trackedBuffData.buffName == skillName then
                        iconExists = true
                        trackedBuffData.duration = currentDuration
                        trackedBuffData.isSkillCooldown = false
                        trackedBuffData.row = 0  
                        if buffIcons[iconId] then
                            buffIcons[iconId].timer:SetText(currentDuration)
                            buffIcons[iconId].overlay:SetColor(overlayColor[1], overlayColor[2], overlayColor[3], overlayColor[4])
                            buffIcons[iconId].timer.style:SetColor(0, 1, 0, 1.0)
                        end
                        break
                    end
                end
                
                if not iconExists then
                    TrackBuff(skillName, skillIconPath, currentDuration, overlayColor, 0)  
                end
                
            elseif shouldShowCooldown then
                local overlayColor = {1, 0, 0, 0.2}  
                local iconExists = false
                for iconId, trackedBuffData in pairs(trackedBuffs) do
                    if trackedBuffData.buffName == skillName then
                        iconExists = true
                        trackedBuffData.duration = currentDuration
                        trackedBuffData.isSkillCooldown = true
                        trackedBuffData.row = 1  
                        if buffIcons[iconId] then
                            buffIcons[iconId].timer:SetText(currentDuration)
                            buffIcons[iconId].overlay:SetColor(overlayColor[1], overlayColor[2], overlayColor[3], overlayColor[4])
                            buffIcons[iconId].timer.style:SetColor(1, 0, 0, 1.0)
                        end
                        break
                    end
                end
                
                if not iconExists then
                    TrackBuff(skillName, skillIconPath, currentDuration, overlayColor, 1)  
                end
                
            else
                local iconsToRemove = {}
                for iconId, trackedBuffData in pairs(trackedBuffs) do
                    if trackedBuffData.buffName == skillName then
                        table.insert(iconsToRemove, iconId)
                    end
                end
                
                for _, iconId in ipairs(iconsToRemove) do
                    RemoveBuffIcon(iconId)
                    trackedBuffs[iconId] = nil
                end
            end
        end
    end

    local currentTime = os.time()
    for skillName, cooldownData in pairs(skillCooldowns) do
        local remainingTime = cooldownData.endTime - currentTime
        
        if SkillDefinitions[skillName] and not SkillDefinitions[skillName].whenBuffAppears then
            if remainingTime > 0 then
                local iconExists = false
                for iconId, trackedBuffData in pairs(trackedBuffs) do
                    if trackedBuffData.buffName == skillName and trackedBuffData.isSkillCooldown then
                        iconExists = true
                        trackedBuffData.duration = tostring(remainingTime)
                        trackedBuffData.row = 1 
                        if buffIcons[iconId] then
                            buffIcons[iconId].timer:SetText(tostring(remainingTime))
                            buffIcons[iconId].timer.style:SetColor(1, 0, 0, 1.0)
                        end
                        break
                    end
                end
                
                if not iconExists then
                    iconCounter = iconCounter + 1
                    local iconId = skillName .. "_cd_" .. tostring(iconCounter)
                    local customIcon = GetCustomIcon(skillName)
                    local iconPath = customIcon or cooldownData.iconPath
                    local icon = CreateBuffIcon(iconId, iconPath, tostring(remainingTime), {1, 0, 0, 0.2}, 1) 
                    if icon then
                        trackedBuffs[iconId] = { 
                            duration = tostring(remainingTime), 
                            buffName = skillName,
                            isSkillCooldown = true,
                            row = 1  
                        }
                        buffIcons[iconId] = icon
                    end
                end
            else
                skillCooldowns[skillName] = nil
                local iconsToRemove = {}
                for iconId, trackedBuffData in pairs(trackedBuffs) do
                    if trackedBuffData.buffName == skillName and trackedBuffData.isSkillCooldown then
                        table.insert(iconsToRemove, iconId)
                    end
                end
                
                for _, iconId in ipairs(iconsToRemove) do
                    RemoveBuffIcon(iconId)
                    trackedBuffs[iconId] = nil
                end
            end
        end
    end

    local buffsToRemove = {}
    for iconId, trackedBuffData in pairs(trackedBuffs) do
        local shouldRemove = false
        
        if trackedBuffData.isSkillCooldown then
            shouldRemove = false
        else
            local isSkillBuff = false
            for skillName, _ in pairs(SkillDefinitions) do
                if trackedBuffData.buffName == skillName then
                    isSkillBuff = true
                    break
                end
            end
            
            local isBuffDefinitionBuff = false
            for buffKey, buffNames in pairs(buffDefinitions) do
                if type(buffNames[1]) == "table" then
                    for _, buffName in ipairs(buffNames[1]) do
                        if trackedBuffData.buffName == buffName then
                            isBuffDefinitionBuff = true
                            break
                        end
                    end
                elseif trackedBuffData.buffName == buffNames[1] then
                    isBuffDefinitionBuff = true
                end
                if trackedBuffData.buffName == buffNames[2] then
                    isBuffDefinitionBuff = true
                end
                if isBuffDefinitionBuff then break end
            end
            
            if isSkillBuff or isBuffDefinitionBuff then
                shouldRemove = false
            else
                if not (buffVariables[trackedBuffData.buffName] and buffVariables[trackedBuffData.buffName].isActive) then
                    shouldRemove = true
                end
            end
        end
        
        if shouldRemove then
            table.insert(buffsToRemove, iconId)
        end
    end

    for _, iconId in ipairs(buffsToRemove) do
        RemoveBuffIcon(iconId)
        trackedBuffs[iconId] = nil
    end
end

function timeUpdater:OnUpdate(dt)
    counter = counter + dt
    if counter >= 1 then
        CheckAndTrackBuffs()
        UpdateBuffIcons()
        counter = 0
    end
end

timeUpdater:SetHandler("OnUpdate", timeUpdater.OnUpdate)

local function EnteredWorld()
    timeUpdater:SetHandler("OnUpdate", timeUpdater.OnUpdate)
    LoadSavedPositions()
end

UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)