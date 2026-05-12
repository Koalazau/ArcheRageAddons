-------------- Original Author: Strawberry --------------
----------------- Discord: exec_noir --------------------
-- Modified: Arrow points direction when target off-screen,
-- moves above target and points down when target on-screen
-- Fixed: Now properly handles UI scale factor
---------------------------------------------------------
if API_TYPE == nil then
    ADDON:ImportAPI(8)
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "Globals folder not found. Please install it at https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals")
    return
end
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.EFFECT_DRAWABLE)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)

local function GetUIScaleFactor() 
    return UIParent:GetUIScale() or 1 
end

local yOffset = 60
local frame = CreateEmptyWindow("refreshForcer", "UIParent")
frame:SetExtent(50, 50)
frame:Show(true)
frame:AddAnchor("CENTER", "UIParent", 0, -yOffset)

local arrow = frame:CreateEffectDrawableByKey("ui/quest/quest_notifier.dds", "direction", "overlay")
arrow:SetVisible(false)
arrow:SetExtent(25, 25)
arrow:AddAnchor("CENTER", frame, 0, 0)
arrow:SetEffectPriority(1, "alpha", 0.5, 0.0)
arrow:SetEffectInitialColor(1, 1, 1, 1, 1)
arrow:SetEffectFinalColor(1, 1, 1, 1, 1)

--arrow:SetEffectInitialColor(1, 1, 0, 0, 1)
--arrow:SetEffectFinalColor(1, 1, 0, 0, 1)

arrow:SetMoveEffectType(1, "circle", 0, 0, 0, 0)
arrow:SetMoveEffectCircle(1, 0, 360)
arrow:SetStartEffect(true)

local prevAngle = 0
local screenMargin = 50

local function ShortestArc(from, to)
    local diff = (to - from + 540) % 360 - 180
    return from + diff
end

local function IsTargetOnScreen(x, y)
    local scaleFactor = GetUIScaleFactor()
    local screenWidth = UIParent:GetScreenWidth() / scaleFactor
    local screenHeight = UIParent:GetScreenHeight() / scaleFactor
    local margin = screenMargin / scaleFactor
    
    return x >= margin and x <= screenWidth - margin and 
           y >= margin and y <= screenHeight - margin
end

local function GetEdgePosition(targetX, targetY)
    local scaleFactor = GetUIScaleFactor()
    local screenWidth = UIParent:GetScreenWidth() / scaleFactor
    local screenHeight = UIParent:GetScreenHeight() / scaleFactor
    local centerX = screenWidth / 2
    local centerY = (screenHeight / 2) - (yOffset / scaleFactor)
    
    local dx = targetX - centerX
    local dy = targetY - centerY
    
    local length = math.sqrt(dx * dx + dy * dy)
    if length == 0 then return centerX, centerY end
    
    dx = dx / length
    dy = dy / length
    
    local edgeX, edgeY
    local margin = 100 / scaleFactor
    
    if dx > 0 then
        local t = (screenWidth - margin - centerX) / dx
        edgeX = centerX + t * dx
        edgeY = centerY + t * dy
        if edgeY >= margin and edgeY <= screenHeight - margin then
            return edgeX, edgeY
        end
    end
    
    if dx < 0 then
        local t = (margin - centerX) / dx
        edgeX = centerX + t * dx
        edgeY = centerY + t * dy
        if edgeY >= margin and edgeY <= screenHeight - margin then
            return edgeX, edgeY
        end
    end
    
    if dy > 0 then
        local t = (screenHeight - margin - centerY) / dy
        edgeX = centerX + t * dx
        edgeY = centerY + t * dy
        if edgeX >= margin and edgeX <= screenWidth - margin then
            return edgeX, edgeY
        end
    end
    
    if dy < 0 then
        local t = (margin - centerY) / dy
        edgeX = centerX + t * dx
        edgeY = centerY + t * dy
        if edgeX >= margin and edgeX <= screenWidth - margin then
            return edgeX, edgeY
        end
    end
    
    return centerX, centerY
end

frame:SetHandler("OnUpdate",
    function()
        local nScrX_Tar, nScrY_Tar, nScrZ_Tar = X2Unit:GetUnitScreenPosition("target")
        if nScrX_Tar ~= nil and nScrY_Tar ~= nil and nScrZ_Tar ~= nil then
            arrow:SetVisible(true)
            
            local targetOnScreen = IsTargetOnScreen(nScrX_Tar, nScrY_Tar) and nScrZ_Tar > 0
            
            if targetOnScreen then
                local x = math.floor(0.5 + nScrX_Tar)
                local y = math.floor(0.5 + nScrY_Tar)
                
                frame:RemoveAllAnchors()
                frame:AddAnchor("TOPLEFT", "UIParent", x - 25, y - 80)
                
                arrow:SetExtent(40, 40)
                
                local targetAngle = 180
                local corrected = ShortestArc(prevAngle, targetAngle)
                arrow:SetMoveEffectCircle(1, prevAngle, corrected)
                arrow:SetStartEffect(true)
                prevAngle = corrected % 360
            else
                local scaleFactor = GetUIScaleFactor()
                local screenWidth = UIParent:GetScreenWidth() / scaleFactor
                local screenHeight = UIParent:GetScreenHeight() / scaleFactor
                local centerX = screenWidth / 2
                local centerY = (screenHeight / 2) - (yOffset / scaleFactor)
                
                frame:RemoveAllAnchors()
                frame:AddAnchor("CENTER", "UIParent", 0, -yOffset)
                
                arrow:SetExtent(25, 25)
            
                local dx = nScrX_Tar - centerX
                local dy = nScrY_Tar - centerY
                local angle = math.atan2(dy, dx)
                local deg = math.deg(angle) + 90
                if deg < 0 then deg = deg + 360 end
                
                if nScrZ_Tar <= 0 then
                    deg = (deg + 180) % 360
                end
                
                local corrected = ShortestArc(prevAngle, deg)
                arrow:SetMoveEffectCircle(1, prevAngle, corrected)
                arrow:SetStartEffect(true)
                prevAngle = corrected % 360
            end
        else
            arrow:SetVisible(false)    
        end
    end
)