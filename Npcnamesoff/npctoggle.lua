-------------- Original Script by: Strawberry --------------
----------------- Discord: exec_noir -----------------------
----------------- Modified by Koala ------------------------
-- Modified to toggle OIT_NAME_TAG_NPC_SHOW 

if API_TYPE == nil then
    ADDON:ImportAPI(8)
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "Globals folder not found. Please install it at https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals")
    return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)

local contentState = 1
local okButton = nil
local toggleButton = nil
local savedPositions = {}
local filePath = "npcnamesoffbutton.txt"

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
    return UIParent:GetUIScale() or 1.0
end

local function CreateButton(npcnameoption)
    if okButton ~= nil then
        return
    end
    
    okButton = UIParent:CreateWidget("button", "cloneModeButton", "UIParent", "")
    okButton:SetText("NPC")
    
    local color = {}
    color.normal    = UIParent:GetFontColor("red")
    color.highlight = UIParent:GetFontColor("red")
    color.pushed    = UIParent:GetFontColor("red")
    color.disabled  = UIParent:GetFontColor("btn_dis")
    
    if npcnameoption == 1 then
        color.normal    = UIParent:GetFontColor("green")
        color.highlight = UIParent:GetFontColor("green")
        color.pushed    = UIParent:GetFontColor("green")
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "Custom Clone Mode is ENABLED.")
    else
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "Custom Clone Mode is DISABLED.")
    end
    
    local buttonskin = {
        drawableType = "ninePart",
        path = "ui/common/default.dds",
        coordsKey = "btn",
        autoResize = true,
        fontColor =  color,
        fontInset = {
            left = 11,
            right = 11,
            top = 0,
            bottom = 0,
        },
    }
    
    okButton:SetStyle("text_default")
    
    LoadSavedPositions()
    if savedPositions["cloneModeButton"] then
        okButton:AddAnchor("TOPLEFT", "UIParent", savedPositions["cloneModeButton"].x, savedPositions["cloneModeButton"].y)
    else
        okButton:AddAnchor("CENTER", "UIParent", 0, 0)
    end
    
    okButton:Show(true)
    okButton:EnableDrag(true)
    
    function okButton:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    okButton:SetHandler("OnDragStart", okButton.OnDragStart)
    
    function okButton:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
        
        -- Save the new position
        local offsetX, offsetY = self:GetOffset()
        local uiScale = GetUIScaleFactor()
        local normalizedX = offsetX * uiScale
        local normalizedY = offsetY * uiScale
        SaveButtonPosition("cloneModeButton", normalizedX, normalizedY)
    end
    okButton:SetHandler("OnDragStop", okButton.OnDragStop)
    
    function okButton:OnClick()
        local npcnameoption = X2Option:GetOptionItemValue(OIT_NAME_TAG_NPC_SHOW)
        
        if npcnameoption == 1 then
            -- Currently enabled, disable it
            color.normal = UIParent:GetFontColor("red")
            color.highlight = UIParent:GetFontColor("red")
            color.pushed = UIParent:GetFontColor("red")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "Npc names OFF")
            X2Option:SetItemFloatValue(OIT_NAME_TAG_NPC_SHOW, 0)
        else
            -- Currently disabled, enable it
            color.normal = UIParent:GetFontColor("green")
            color.highlight = UIParent:GetFontColor("green")
            color.pushed = UIParent:GetFontColor("green")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "Npc names ON")
            X2Option:SetItemFloatValue(OIT_NAME_TAG_NPC_SHOW, 1)
        end
        
        okButton:SetStyle("text_default")
    end
    okButton:SetHandler("OnClick", okButton.OnClick)
end

local function ToggleCloneModeButton(show)
    if show == nil then
        show = okButton == nil and true or (not okButton:IsVisible())
    end
    
    if show == true and okButton == nil then
        local npcnameoption = X2Option:GetOptionItemValue(OIT_NAME_TAG_NPC_SHOW)
        CreateButton(npcnameoption)
    end
    
    if okButton ~= nil then
        okButton:Show(show)
    end
    
    return true
end

local function EnteredWorld()
    local npcnameoption = X2Option:GetOptionItemValue(OIT_NAME_TAG_NPC_SHOW)
    CreateButton(npcnameoption)
end

UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)