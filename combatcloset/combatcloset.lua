ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX_MULTILINE)
ADDON:ImportObject(OBJECT_TYPE.WEBBROWSER)

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)
ADDON:ImportAPI(API_TYPE.PLAYER.id)
ADDON:ImportAPI(API_TYPE.EQUIPMENT.id)
ADDON:ImportAPI(API_TYPE.BAG.id)
ADDON:ImportAPI(API_TYPE.HOTKEY.id)

local ADDON_VERSION = "2.1"

local function ApplyMouseHandlers(widget, handlers)
    for event, fn in pairs(handlers) do
        widget:SetHandler(event, fn)
    end
end

local function CreateOverlay(parent, size, texture, anchorPoint)
    local overlay = parent:CreateIconDrawable("artwork")
    overlay:SetExtent(size, size)
    overlay:AddAnchor("CENTER", parent, 0, 0)
    if texture then
        overlay:AddTexture(texture)
    end
    overlay:SetVisible(false)
    return overlay
end

local defaultBtnFontColor = {
    normal = UIParent:GetFontColor("btn_df"),
    highlight = UIParent:GetFontColor("btn_ov"),
    pushed = UIParent:GetFontColor("btn_on"),
    disabled = UIParent:GetFontColor("btn_dis"),
}

local function CreateSkin(path, coordsKey, fontColor, inset)
    return {
        drawableType = "ninePart",
        path = path,
        coordsKey = coordsKey,
        autoResize = true,
        fontColor = fontColor or defaultBtnFontColor,
        fontInset = inset or { left = 0, right = 0, top = 0, bottom = 0 },
    }
end

local CONSTANTS = {
    CONFIG_PATH = "../Documents/Addon/combatcloset/config.txt",
    LEGACY_CONFIG_PATH = "../Documents/Addon/combatcloset/config.lua",
    ICONS_PATH = "addon/combatcloset/Icons/",
    BAG_SIZE = 150,
    EQUIPMENT_SLOTS = {1, 3, 4, 8, 6, 9, 5, 7, 15, 2, 10, 11, 12, 13, 16, 17, 18, 19, 28},
    ALTERNATIVE_SLOTS = {13, 11, 17},
    STYLES = {
        TEXT_DEFAULT = "text_default",
        BTN_CLOSE_DEFAULT = "btn_close_default",
        BUTTON_COMMON_OPTION = "button_common_option"
    },
    TEXTURES = {
        HOVER_OVERLAY = "addon/combatcloset/Icons/0.5 opac overlay.dds",
        CLICK_OVERLAY = "addon/combatcloset/Icons/0.5 opac black overlay.dds",
        SELECTION_OVERLAY = "addon/combatcloset/Icons/Overlay.dds",
        ITEM_GRADE_HEROIC = "ui/icon/item_grade_5heroic.dds",
        ITEM_GRADE_COMMON = "ui/icon/item_grade_1common.dds",
        HUD_BACKGROUND = "ui/common/hud.dds"
    }
}

local configPath = CONSTANTS.CONFIG_PATH
local config = rawget(_G, "config") or {}
local gear_to_process = {}
local buttons = buttons or {}
local buttonsTable = buttonsTable or {}

local function escapeField(s)
    s = tostring(s or "")
    s = s:gsub("\n", " ")
    s = s:gsub("|", "/")
    return s
end

local function ParseHotkeyString(hotkeyString)
    if not hotkeyString or hotkeyString == "" or hotkeyString == "None" then
        return "None", ""
    end
    
    local modifier, key = hotkeyString:match("^(.-)%-(.+)$")
    if modifier and key then
        return modifier, key
    end
    
    modifier, key = hotkeyString:match("^(.-)%+(.+)$")
    if modifier and key then
        return modifier, key
    end
    
    return "None", hotkeyString
end

local function CombineHotkey(modifier, key)
    if not modifier or modifier == "None" or not key or key == "" then
        return ""
    end
    
    if modifier == "Ctrl" then
        return "Ctrl-" .. key  
    elseif modifier == "Shift" then
        return "Shift-" .. key  
    elseif modifier == "Alt" then
        return "Alt-" .. key 
    else
        return key
    end
end

local function DisplayHotkey(hotkey)
    if not hotkey or hotkey == "" then return "" end
    local modifier, key = ParseHotkeyString(hotkey)
    local dk = key
    if dk and dk:match("^NUMBER[0-9]$") then
        dk = "NUM " .. dk:match("^NUMBER([0-9])$")
    elseif dk == "NUMBER+" then
        dk = "NUM (+)"
    elseif dk == "NUMBER-" then
        dk = "NUM (-)"
    elseif dk == "NUMBER*" then
        dk = "NUM (*)"
    elseif dk == "NUMBER/" then
        dk = "NUM (/)"
    elseif dk == "MIDDLEBUTTON" then
        dk = "M-Middle"
    elseif dk == "WHEELUP" then
        dk = "M-UP"
    elseif dk == "WHEELDOWN" then
        dk = "M-DOWN"
    end
    if modifier == "Ctrl" then
        return "Ctrl-" .. dk
    elseif modifier == "Shift" then
        return "Shift-" .. dk
    elseif modifier == "Alt" then
        return "Alt-" .. dk
    elseif modifier == "None" then
        return dk or ""
    else
        return (modifier or "") .. (dk and ("-" .. dk) or "")
    end
end

local HotkeyUtils = {}

HotkeyUtils.keyDisplayToApi = {
    ["M-Middle"] = "MIDDLEBUTTON",
    ["M-UP"] = "WHEELUP",
    ["M-DOWN"] = "WHEELDOWN",
    ["MOUSE4"] = "MOUSE4",
    ["MOUSE5"] = "MOUSE5",

    ["NUM 0"] = "NUMBER0",
    ["NUM 1"] = "NUMBER1",
    ["NUM 2"] = "NUMBER2",
    ["NUM 3"] = "NUMBER3",
    ["NUM 4"] = "NUMBER4",
    ["NUM 5"] = "NUMBER5",
    ["NUM 6"] = "NUMBER6",
    ["NUM 7"] = "NUMBER7",
    ["NUM 8"] = "NUMBER8",
    ["NUM 9"] = "NUMBER9",
    ["NUM (+)"] = "NUMBER+",
    ["NUM (-)"] = "NUMBER-",
    ["NUM (*)"] = "NUMBER*",
    ["NUM (/)"] = "NUMBER/"
}

HotkeyUtils.keyApiToDisplay = {
    ["MIDDLEBUTTON"] = "M-Middle",
    ["WHEELUP"] = "M-UP",
    ["WHEELDOWN"] = "M-DOWN",
    ["MOUSE4"] = "MOUSE4",
    ["MOUSE5"] = "MOUSE5",

    ["NUMBER0"] = "NUM 0",
    ["NUMBER1"] = "NUM 1",
    ["NUMBER2"] = "NUM 2",
    ["NUMBER3"] = "NUM 3",
    ["NUMBER4"] = "NUM 4",
    ["NUMBER5"] = "NUM 5",
    ["NUMBER6"] = "NUM 6",
    ["NUMBER7"] = "NUM 7",
    ["NUMBER8"] = "NUM 8",
    ["NUMBER9"] = "NUM 9",
    ["NUMBER+"] = "NUM (+)",
    ["NUMBER-"] = "NUM (-)",
    ["NUMBER*"] = "NUM (*)",
    ["NUMBER/"] = "NUM (/)"
}

HotkeyUtils.GetKeysByType = function(keyType)
    if keyType == "Letters" then
        return {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}
    elseif keyType == "Digits" then
        return {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
    elseif keyType == "Numpad" then
        return {"NUM 0", "NUM 1", "NUM 2", "NUM 3", "NUM 4", "NUM 5", "NUM 6", "NUM 7", "NUM 8", "NUM 9", "NUM (+)", "NUM (-)", "NUM (*)", "NUM (/)"}
    elseif keyType == "Functions" then
        return {"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"}
    elseif keyType == "Mouse" then
        return {"M-Middle", "M-UP", "M-DOWN", "MOUSE4", "MOUSE5"}
    else
        return {}
    end
end

HotkeyUtils.BuildHotkeyString = function(keyType, key, modifier)
    if keyType == "None" or not key or key == "" then
        return ""
    end

    local apiKey = HotkeyUtils.keyDisplayToApi[key] or key

    if modifier == "None" or not modifier then
        return apiKey
    else
        return modifier .. "-" .. apiKey
    end
end

HotkeyUtils.IsValidHotkeySelection = function(keyType, key, modifier)
    if keyType == "None" then
        return true
    end
    if not key or key == "" then
        return false
    end
    return true
end

local function toBool(v)
    if v == true or v == "true" or v == "1" then return true end
    return false
end

local function FixIconPath(path)
    if not path then return nil end
    local p = tostring(path)
    p = p:gsub("addon/brazilianSwap/", CONSTANTS.ICONS_PATH)
    return p
end

local function GetCurrentEffectTitle()
    local titleData = X2Player:GetEffectAppellation()
    return titleData and titleData[1] or nil
end

local optionsWindow, iconSelectionWindow, editSetWindow

local function SaveConfig()
    local file = io.open(configPath, "w")
    if not file then
        return
    end
    for _, set in ipairs(config) do
        file:write(string.format("Set|%s|%s|%s|%s|%s\n",
            escapeField(set.Text),
            escapeField(set.Char),
            escapeField(set.Icon),
            escapeField(set.Title),
            escapeField(set.Hotkey or "")))
        if set.Items then
            for _, item in ipairs(set.Items) do
                local slotField = item.slot and tostring(item.slot) or ((item.alternative and "true") or "false")
                file:write(string.format("Item|%s|%s|%s\n",
                    escapeField(item.name),
                    escapeField(slotField),
                    escapeField(item.stats)))
            end
        end
        file:write("EndSet\n")
    end
    file:close()
end

local function LoadLegacyLuaConfig()
    local p = CONSTANTS.LEGACY_CONFIG_PATH
    local f = io.open(p, "r")
    if f then f:close()
        local chunk, loadErr = loadfile(p)
        if not chunk then
            return false
        end
        local env = {}
        setmetatable(env, { __index = _G })
        if setfenv then setfenv(chunk, env) end
        local ok, execErr = pcall(chunk)
        if not ok then
            return false
        end
        local legacy = env.config or rawget(_G, "config")
        if type(legacy) == "table" and #legacy > 0 then
            for _, set in ipairs(legacy) do
                if set.Icon then set.Icon = FixIconPath(set.Icon) end
            end
            config = legacy
            _G.config = config
            return true
        end
    end
    return false
end

local function LoadConfig()
    local file = io.open(configPath, "r")
    if not file then
        local migrated = LoadLegacyLuaConfig()
        if migrated then
            SaveConfig()
        else
            config = config or {}
            _G.config = config
            SaveConfig()
        end
        return
    end

    local loaded = {}
    local current = nil
    for line in file:lines() do
        local kind, a, b, c, d, e = line:match("([^|]+)|([^|]*)|([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)")
        if kind == "Set" then
            current = {
                Text = a,
                Char = b,
                Icon = FixIconPath(c),
                Title = tonumber(d) or nil,
                Hotkey = (e and e ~= "") and e or nil,
                Items = {}
            }
        elseif kind == "Item" and current ~= nil then
            local maybeNum = tonumber(b)
            if maybeNum ~= nil then
                table.insert(current.Items, {
                    name = a,
                    slot = maybeNum,
                    stats = c ~= "" and c or nil,
                })
            else
                table.insert(current.Items, {
                    name = a,
                    alternative = toBool(b),
                    stats = c ~= "" and c or nil,
                })
            end
        elseif line == "EndSet" and current ~= nil then
            table.insert(loaded, current)
            current = nil
        end
    end
    file:close()
    if #loaded > 0 then
        config = loaded
        _G.config = config 
    end
end

local function CreateActionButton(config)
    local btn = config.parent:CreateChildWidget("button", config.name, 1, true)
    if config.anchorTargetPoint then
        btn:AddAnchor(config.anchor, config.anchorTarget, config.anchorTargetPoint, config.offsetX or 0, config.offsetY or 0)
    else
        btn:AddAnchor(config.anchor, config.anchorTarget, config.offsetX or 0, config.offsetY or 0)
    end
    btn:SetText(config.text or "")
    if type(config.skin) == "string" then
        btn:SetStyle(config.skin)
    else
        ApplyButtonSkin(btn, config.skin)
    end
    ApplyMouseHandlers(btn, config.handlers or {})
    if config.width and config.height then
        btn:SetExtent(config.width, config.height)
    end
    return btn
end

local function normalizeItemName(name)
    if not name then return "" end
    local normalized = tostring(name)
    normalized = normalized:gsub("^[%+%-]?%d+%s+", "")
    normalized = normalized:gsub("%s*%([^%)]*%)%s*$", "")
    normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
    return normalized
end

local function GetCurrentEquippedGear()
    local items = {}
    local gear_pieces = CONSTANTS.EQUIPMENT_SLOTS
    for _, i in ipairs(gear_pieces) do
        local item = X2Equipment:GetEquippedItemTooltipInfo(i, true)
        if item ~= nil then
            local normalizedName = normalizeItemName(item.name)
            local new_item = { name = normalizedName, grade = item.itemGrade, slot = i }
            
            if item.evolvingInfo and item.evolvingInfo.modifier then
                local stats = {}
                for _, subTable in ipairs(item.evolvingInfo.modifier) do
                    if subTable.name and subTable.value then
                        table.insert(stats, tostring(subTable.name))
                    end
                end
                if #stats > 0 then
                    new_item.stats = table.concat(stats, ";")
                end
            end
            
            table.insert(items, new_item)
        end
    end
    return items
end

local function parseStatsString(s)
    local set = {}
    if not s or s == "" then return set end
    for stat in string.gmatch(s, "([^;]+)") do
        set[string.lower(stat)] = true
    end
    return set
end

local function IsAlternativeSlot(slot)
    for _, altSlot in ipairs(CONSTANTS.ALTERNATIVE_SLOTS) do
        if slot == altSlot then return true end
    end
    return false
end

local function ComputeAlternative(gearItem)
    if gearItem and gearItem.slot then
        return IsAlternativeSlot(gearItem.slot)
    end
    return gearItem and gearItem.alternative == true or false
end

local function CheckCurrentAppellation(activeName)
    local activeButton = buttonsTable[activeName]
    if activeButton then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("|cFF35CAEEActivated Set: |cFFFFD700%s", activeButton.name))
    else
        X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("|cFF35CAEEActivated Set: |cFFFFD700%s", activeName))
    end
end

local function MoveSetUp(setName)
    local playerName = X2Unit:UnitName("player")
    for j = 2, #config do
        if config[j].Text == setName and config[j].Char == playerName then
            local prevIndex = j - 1
            while prevIndex >= 1 and config[prevIndex].Char ~= playerName do
                prevIndex = prevIndex - 1
            end
            if prevIndex >= 1 then
                config[j], config[prevIndex] = config[prevIndex], config[j]
                SaveConfig()
                RefreshEquipWindowButtons()
                RefreshOptionsWindowList()
            end
            break
        end
    end
end

local function MoveSetDown(setName)
    local playerName = X2Unit:UnitName("player")
    for j = 1, #config - 1 do
        if config[j].Text == setName and config[j].Char == playerName then
            local nextIndex = j + 1
            while nextIndex <= #config and config[nextIndex].Char ~= playerName do
                nextIndex = nextIndex + 1
            end
            if nextIndex <= #config then
                config[j], config[nextIndex] = config[nextIndex], config[j]
                SaveConfig()
                RefreshEquipWindowButtons()
                RefreshOptionsWindowList()
            end
            break
        end
    end
end

local function DeleteSet(setName)
    for j = #config, 1, -1 do
        if config[j].Text == setName and config[j].Char == X2Unit:UnitName("player") then
            table.remove(config, j)
            break
        end
    end
    SaveConfig()
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF35CAEESet |cFFEE5535deleted: |cFFFFD700" .. setName)
    RefreshEquipWindowButtons()
    RefreshOptionsWindowList()
end

local function bagHasAllStats(bagItemInfo, requiredSet)
    if not requiredSet or next(requiredSet) == nil then return true end
    if not bagItemInfo or not bagItemInfo.evolvingInfo or not bagItemInfo.evolvingInfo.modifier then return false end
    local present = {}
    for _, subTable in ipairs(bagItemInfo.evolvingInfo.modifier) do
        if subTable.name then
            present[string.lower(tostring(subTable.name))] = true
        end
    end
    for stat, _ in pairs(requiredSet) do
        if not present[stat] then return false end
    end
    return true
end

local function ExecuteGearSwap(set, activeName)
    if not set or not set.Items then return end
    
    gear_to_process = {}
    
    local used_positions = {}
    local itemsToProcess = {}

    for j = 1, #set.Items do
        local gearItem = set.Items[j]
        local useAlternative = gearItem.alternative == true
        local itemFound = false

        for i = 1, CONSTANTS.BAG_SIZE do
            local bagItemInfo = X2Bag:GetBagItemInfo(0, i)

            if bagItemInfo and string.find(tostring(bagItemInfo.name):lower(), gearItem.name:lower(), 1, true) then
                local ok = true
                if gearItem.stats and gearItem.stats ~= "" then
                    local required = parseStatsString(gearItem.stats)
                    ok = bagHasAllStats(bagItemInfo, required)
                end
                if ok then
                    if not used_positions[i] then
                        table.insert(itemsToProcess, { gear_item = gearItem, pos = i })
                        used_positions[i] = true
                        itemFound = true
                        break
                    end
                end
            end

            if itemFound then
                break
            end
        end
    end

    for _, item in ipairs(itemsToProcess) do
        table.insert(gear_to_process, item)
    end

    if #gear_to_process > 0 then
        for i = 1, #buttons do
            local button = buttons[i]
            button:Enable(false)
        end
    end
end

local function SwapToGearSet(set)
    if not set or not set.Items then return end
    
    local activeName = set.Text
    if set.Title ~= nil then
        local currentTitle = X2Player:GetShowingAppellation()
        local currentTitleId = currentTitle[1]
        X2Player:ChangeAppellation(currentTitleId, set.Title)
    end
    
    CheckCurrentAppellation(activeName)
    
    if lastClickedButton then
        if lastClickedButton.overlay then
            lastClickedButton.overlay:SetVisible(false)
        end
    end
    
    local setButton = buttonsTable[activeName]
    if setButton and setButton.button and setButton.button.overlay then
        setButton.button.overlay:SetVisible(true)
        lastClickedButton = setButton.button
    end
    
    ExecuteGearSwap(set, activeName)
end

local function RegisterGearSetHotkey(set)
    if not set.Hotkey or set.Hotkey == "" then return end
    
    local actionName = "GEARSET_" .. (set.Text or "Unknown"):upper():gsub("[^%w]", "_")
    set.HotkeyAction = actionName
    
    if X2Hotkey and X2Hotkey.SetBindingUiEvent then
        local success, error = pcall(function()
            X2Hotkey:SetBindingUiEvent(actionName, set.Hotkey)
        end)
        if not success then
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFEE5535Failed to bind hotkey |cFFFFD700'" .. set.Hotkey .. "'|cFFEE5535 for |cFF35CAEESet: |cFFFFD700" .. set.Text .. "|cFFEE5535 Error: " .. tostring(error))
        end
    end
end

local function UnregisterGearSetHotkey(set)
    if not set.HotkeyAction then return end
    
    if X2Hotkey and X2Hotkey.SetBindingUiEvent then
        local success, error = pcall(function()
            X2Hotkey:SetBindingUiEvent(set.HotkeyAction, "")
        end)
        if not success then
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFFEE5535Failed to unbind hotkey for |cFF35CAEESet: |cFFFFD700" .. set.Text .. "|cFFEE5535 Error: " .. tostring(error))
        end
    end
    set.HotkeyAction = nil
end

local function OnHotkeyAction(actionName, isReleased)
    if isReleased then return end
    
    local playerName = X2Unit:UnitName("player")
    for _, set in ipairs(config) do
        if set.Char == playerName and set.HotkeyAction == actionName then
            SwapToGearSet(set)
            break
        end
    end
end

local function RegisterAllHotkeys()
    local playerName = X2Unit:UnitName("player")
    for _, set in ipairs(config) do
        if set.Char == playerName and set.Hotkey and set.Hotkey ~= "" then
            RegisterGearSetHotkey(set)
        end
    end
end



CreateButton = function(set, index)
    local playerName = X2Unit:UnitName("player")
    if set.Char and set.Char == playerName then
        local name = set.Text
        local col = (index - 1) % buttonsPerRow
        local row = math.floor((index - 1) / buttonsPerRow)
        local x = windowPadding + col * buttonSpacing
        local y = windowPadding + row * buttonSpacing

        local uniqueId = tostring(_G.currentButtonNonce or 0) .. "_" .. name
        local button = equipWindow:CreateChildWidget("button", uniqueId .. "_button", 0, true)
        table.insert(buttons, button)
        buttonsTable[name] = { button = button, name = name }
        button:SetExtent(buttonSize, buttonSize)
        button:SetText("")
        if button.RemoveAllAnchors then button:RemoveAllAnchors() end
        button:AddAnchor("TOPLEFT", equipWindow, x, y)
        button:Show(true)
        button:EnableDrag(false)

        local Tooltip = button:CreateChildWidget("label", uniqueId .. "_tooltip_label", 0, true)
        Tooltip:SetHeight(30)
        Tooltip:SetAutoResize(true)
        
        local tooltipBackground = Tooltip:CreateNinePartDrawable(CONSTANTS.TEXTURES.HUD_BACKGROUND, "background")
        tooltipBackground:SetCoords(733, 169, 14, 15) 
        tooltipBackground:SetInset(7, 7, 6, 7)
        tooltipBackground:AddAnchor("TOPLEFT", Tooltip, -10, 0)
        tooltipBackground:AddAnchor("BOTTOMRIGHT", Tooltip, 10, 0)
        tooltipBackground:SetVisible(true)

        Tooltip:SetText(set.Text)
        Tooltip.style:SetColorByKey("brown")
        Tooltip:AddAnchor("TOPRIGHT", button, "BOTTOMLEFT", -10, 0)
        Tooltip:Show(false)
        button.Tooltip = Tooltip

        local iconOverlay = button:CreateIconDrawable("artwork")
        iconOverlay:SetExtent(buttonSize, buttonSize)
        iconOverlay:AddAnchor("CENTER", button, 0, 0)
        iconOverlay:SetVisible(true)
        iconOverlay:AddTexture(set.Icon)
        iconOverlay:AddTexture(CONSTANTS.TEXTURES.ITEM_GRADE_HEROIC)
        button.iconOverlay = iconOverlay

        local hoverOverlay = button:CreateIconDrawable("artwork")
        hoverOverlay:AddTexture(CONSTANTS.TEXTURES.HOVER_OVERLAY)
        hoverOverlay:AddTexture(CONSTANTS.TEXTURES.ITEM_GRADE_COMMON)
        hoverOverlay:SetExtent(buttonSize, buttonSize)
        hoverOverlay:AddAnchor("CENTER", button, 0, 0)
        hoverOverlay:SetVisible(false)
        button.hoverOverlay = hoverOverlay

        local OnClicOverlay = button:CreateIconDrawable("artwork")
        OnClicOverlay:AddTexture(CONSTANTS.TEXTURES.CLICK_OVERLAY)
        OnClicOverlay:SetExtent(buttonSize, buttonSize)
        OnClicOverlay:AddAnchor("CENTER", button, 0, 0)
        OnClicOverlay:SetVisible(false)
        button.OnClicOverlay = OnClicOverlay

        local selectionOverlay = button:CreateIconDrawable("artwork")
        selectionOverlay:AddTexture(CONSTANTS.TEXTURES.SELECTION_OVERLAY)
        selectionOverlay:SetExtent(buttonSize, buttonSize)
        selectionOverlay:AddAnchor("CENTER", button, 0, 0)
        selectionOverlay:SetVisible(false)
        button.overlay = selectionOverlay

        local hotkeyLabel = button:CreateChildWidget("label", uniqueId .. "_hotkey_label", 0, true)
        hotkeyLabel:SetHeight(12)
        hotkeyLabel:SetAutoResize(true)
        hotkeyLabel.style:SetFontSize(10)
        hotkeyLabel.style:SetAlign(LEFT)
        hotkeyLabel.style:SetColorByKey("white")
        hotkeyLabel:AddAnchor("TOPLEFT", button, 3, 3)
        
        local hotkeyText = ""
        if set.Hotkey and set.Hotkey ~= "" then
            hotkeyText = DisplayHotkey(set.Hotkey)
            if #hotkeyText > 5 then
                hotkeyText = string.sub(hotkeyText, 1, 5) .. ".."
            end
        end
        hotkeyLabel:SetText(hotkeyText)
        hotkeyLabel:Show(true)
        button.hotkeyLabel = hotkeyLabel

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
                end
                if self.Tooltip then
                    self.Tooltip:Show(false)
                end
            end,

            OnMouseDown = function(self)
                if self.OnClicOverlay then
                    self.OnClicOverlay:SetVisible(true)
                end
            end,
            OnMouseUp = function(self)
                if self.OnClicOverlay then
                    self.OnClicOverlay:SetVisible(false)
                end
            end,

            OnClick = function()
                SwapToGearSet(set)
            end
        }
        ApplyMouseHandlers(button, mouseHandlers)
    end
end

function RefreshEquipWindowButtons()
    if not equipWindow then return end
    
    for _, button in ipairs(buttons) do
        if button then
            if button.RemoveAllAnchors then button:RemoveAllAnchors() end
            button:AddAnchor("TOPLEFT", equipWindow, 9999, 9999)
            button:Show(false)
        end
    end
    buttons = {}
    buttonsTable = {}
    
    local buttonCount = 0
    for _, set in ipairs(config) do
        if set.Char == X2Unit:UnitName("player") then
            buttonCount = buttonCount + 1
        end
    end
    
    local cols = math.min(buttonCount, buttonsPerRow)
    local rows = math.ceil(buttonCount / buttonsPerRow)
    local totalWidth = (cols * buttonSpacing) - (buttonSpacing - buttonSize) + 2 * windowPadding
    local totalHeight = (rows * buttonSpacing) - (buttonSpacing - buttonSize) + 2 * windowPadding
    equipWindow:SetExtent(totalWidth, totalHeight)
    
    _G.currentButtonNonce = (_G.currentButtonNonce or 0) + 1
    local buttonIndex = 1
    for i = 1, #config do
        local set = config[i]
        if set.Char == X2Unit:UnitName("player") then
            CreateButton(set, buttonIndex)
            if set.Hotkey and set.Hotkey ~= "" then
                RegisterGearSetHotkey(set)
            end
            buttonIndex = buttonIndex + 1
        end
    end

    equipWindow:Show(false)
    equipWindow:Show(true)
end

function RefreshOptionsWindowList()
    if not optionsWindow or not optionsWindow:IsVisible() then return end

    if optionsWindow.rowWidgets then
        for _, row in ipairs(optionsWindow.rowWidgets) do
            if row then
                if row.RemoveAllAnchors then row:RemoveAllAnchors() end
                row:AddAnchor("TOPLEFT", optionsWindow, 9999, 9999)
                row:Show(false)
            end
        end
    end
    optionsWindow.rowWidgets = {}

    local rowHeight = 36
    local yOffset = 0
    local playerName = X2Unit:UnitName("player")

    local setCount = 0
    for _, set in ipairs(config) do
        if set.Char and set.Char == playerName then
            setCount = setCount + 1
        end
    end
    local windowHeight = math.max(200, 50 + (setCount * rowHeight) + 50 + 20)
    optionsWindow:SetExtent(400, windowHeight)

    if optionsWindow.listContainer then
        optionsWindow.listContainer:Show(false)
    end
    local listContainer = optionsWindow:CreateChildWidget("window", "setListRefresh_" .. tostring(os.time() or math.random(1,999999)), 0, true)
    listContainer:AddAnchor("TOPLEFT", optionsWindow, 10, 50)
    listContainer:AddAnchor("BOTTOMRIGHT", optionsWindow, -10, -80)
    listContainer:Show(true)
    optionsWindow.listContainer = listContainer
    if optionsWindow.saveBtn then 
        optionsWindow.saveBtn:Enable(true)
        optionsWindow.saveBtn:Show(false); optionsWindow.saveBtn:Show(true)
    end
    optionsWindow.refreshNonce = (optionsWindow.refreshNonce or 0) + 1
    local nonce = tostring(optionsWindow.refreshNonce)

    local visibleIndex = 0
    for i = 1, #config do
        local set = config[i]
        if set.Char and set.Char == playerName then
            local row = listContainer:CreateChildWidget("window", "row_" .. nonce .. "_" .. tostring(i), 0, true)
            row:SetExtent(listContainer:GetWidth() or 360, rowHeight)
            row:AddAnchor("TOPLEFT", listContainer, 0, yOffset)
            row:Show(true)

            local icon = row:CreateIconDrawable("artwork")
            icon:SetExtent(32, 32)
            icon:AddAnchor("LEFT", row, 0, 0)
            icon:AddTexture(set.Icon)
            icon:SetVisible(true)

            local nameLabel = row:CreateChildWidget("label", "name_" .. nonce .. "_" .. tostring(i), 0, true)
            nameLabel:SetHeight(32)
            nameLabel:SetAutoResize(true)
            local displayText = set.Text or ""
            if set.Hotkey and set.Hotkey ~= "" then
                displayText = displayText .. " [" .. DisplayHotkey(set.Hotkey) .. "]"
            end
            nameLabel:SetText(displayText)
            nameLabel:AddAnchor("LEFT", icon, "RIGHT", 8, 0)
            nameLabel.style:SetColorByKey("default")
            nameLabel:Show(true)

            local moveUpBtn = row:CreateChildWidget("button", "moveUp_" .. nonce .. "_" .. tostring(i), 0, true)
            moveUpBtn:SetText("Up")
            moveUpBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
            moveUpBtn:AddAnchor("RIGHT", row, -160, 0)
            moveUpBtn:SetExtent(40, 30)
            moveUpBtn:Show(true)
            function moveUpBtn:OnClick()
                MoveSetUp(set.Text or "")
            end
            moveUpBtn:SetHandler("OnClick", moveUpBtn.OnClick)

            local moveDownBtn = row:CreateChildWidget("button", "moveDown_" .. nonce .. "_" .. tostring(i), 0, true)
            moveDownBtn:SetText("Down")
            moveDownBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
            moveDownBtn:AddAnchor("RIGHT", row, -95, 0)
            moveDownBtn:SetExtent(60, 30)
            moveDownBtn:Show(true)
            function moveDownBtn:OnClick()
                MoveSetDown(set.Text or "")
            end
            moveDownBtn:SetHandler("OnClick", moveDownBtn.OnClick)

            local editBtn = row:CreateChildWidget("button", "edit_" .. nonce .. "_" .. tostring(i), 0, true)
            editBtn:SetText("Edit")
            editBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
            editBtn:AddAnchor("RIGHT", row, -50, 0)
            editBtn:SetExtent(40, 30)
            editBtn:Show(true)

            function editBtn:OnClick()
                ShowEditSetWindow(set)
            end
            editBtn:SetHandler("OnClick", editBtn.OnClick)

            local deleteBtn = row:CreateChildWidget("button", "delete_" .. nonce .. "_" .. tostring(i), 0, true)
            deleteBtn:SetText("X")
            deleteBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
            deleteBtn:AddAnchor("RIGHT", row, -5, 0)
            deleteBtn:SetExtent(40, 30)
            deleteBtn:Show(true)
            function deleteBtn:OnClick()
                DeleteSet(set.Text or "")
            end
            deleteBtn:SetHandler("OnClick", deleteBtn.OnClick)

            visibleIndex = visibleIndex + 1
            if moveUpBtn.Enable then moveUpBtn:Enable(visibleIndex > 1) end
            if moveDownBtn.Enable then moveDownBtn:Enable(visibleIndex < setCount) end

            table.insert(optionsWindow.rowWidgets, row)
            yOffset = yOffset + rowHeight
        end
    end
end

local function SaveNewSet(setName, iconPath, hotkey)
    local currentGear = GetCurrentEquippedGear()
    local currentTitle = GetCurrentEffectTitle()
    local newSet = {
        Text = setName,
        Icon = iconPath,
        Char = X2Unit:UnitName("player"),
        Title = currentTitle,
        Hotkey = (hotkey and hotkey ~= "") and hotkey or nil,
        Items = currentGear
    }
    table.insert(config, newSet)
    SaveConfig()
    local hk = newSet.Hotkey or ""
    X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("|cFF35CAEESet |cFF35EE35saved: |cFFFFD700%s |cFF35EE35 hotkey |cFFFFD700\"%s\"", tostring(setName), tostring(hk)))
    if newSet.Hotkey then
        RegisterGearSetHotkey(newSet)
    end
    RefreshEquipWindowButtons()
    RefreshOptionsWindowList()
end

local availableIcons

local function ShowIconSelectionWindow()
    if iconSelectionWindow then
        iconSelectionWindow:Show(false)
        iconSelectionWindow = nil
    end

    iconSelectionWindow = CreateEmptyWindow("iconSelectionWindow", "UIParent")
    iconSelectionWindow:AddAnchor("CENTER", "UIParent", 0, 0)
    iconSelectionWindow:SetCloseOnEscape(true)
    iconSelectionWindow:EnableDrag(true)

    local function OnShow()
        SettingWindowSkin(iconSelectionWindow)
        iconSelectionWindow:SetStartAnimation(true, true)
    end
    iconSelectionWindow:SetHandler("OnShow", OnShow)

    function iconSelectionWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    iconSelectionWindow:SetHandler("OnDragStart", iconSelectionWindow.OnDragStart)

    function iconSelectionWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
    end
    iconSelectionWindow:SetHandler("OnDragStop", iconSelectionWindow.OnDragStop)

    local title = iconSelectionWindow:CreateChildWidget("label", "iconTitle", 0, false)
    title:SetHeight(20)
    title.style:SetFontSize(18)
    title:SetText("Create New Set")
    title:AddAnchor("TOP", iconSelectionWindow, 0, 10)
    title.style:SetAlign(CENTER)
    title.style:SetColorByKey("brown")

    local closeX = iconSelectionWindow:CreateChildWidget("button", "iconCloseX", 0, true)
    closeX:SetExtent(30, 30)
    closeX:SetStyle(CONSTANTS.STYLES.BTN_CLOSE_DEFAULT)
    closeX:AddAnchor("TOPRIGHT", iconSelectionWindow, -5, 5)
    closeX:Show(true)
    function closeX:OnClick()
        selectedIcon = nil
        iconSelectionWindow:Show(false)
    end
    closeX:SetHandler("OnClick", closeX.OnClick)

    local iconGrid = iconSelectionWindow:CreateChildWidget("window", "iconGrid", 0, true)
    iconGrid:AddAnchor("TOPLEFT", iconSelectionWindow, 10, 40)
    iconGrid:AddAnchor("TOPRIGHT", iconSelectionWindow, -10, 0)
    iconGrid:SetHeight(200)
    iconGrid:Show(true)


    local iconsPerRow = 6
    local iconSize = 48
    local iconSpacing = 60
    local selectedIconButton = nil
    
    local totalIcons = availableIcons and #availableIcons or 0
    local iconRows = math.ceil(totalIcons / iconsPerRow)
    local gridWidth = iconsPerRow * iconSpacing - (iconSpacing - iconSize) + 20  
    local gridHeight = iconRows * iconSpacing + 20
    local windowWidth = gridWidth + 20  
    local windowHeight = gridHeight + 150  
    iconSelectionWindow:SetExtent(windowWidth, windowHeight)

    if not availableIcons or #availableIcons == 0 then
        local emptyLabel = iconSelectionWindow:CreateChildWidget("label", "noIconsLabel", 0, true)
        emptyLabel:SetHeight(20)
        emptyLabel.style:SetFontSize(14)
        emptyLabel:SetText("No icons configured. Check availableIcons list.")
        emptyLabel:AddAnchor("CENTER", iconGrid, 0, 0)
        emptyLabel.style:SetAlign(CENTER)
        emptyLabel.style:SetColorByKey("brown")
        emptyLabel:Show(true)
    end

    local function GetEditText()
        return tostring(iconSelectionWindow.currentText or "")
    end

    local function UpdateSaveEnabled()
        local nameText = GetEditText()
        local nameOk = (nameText ~= "")
        local iconOk = (iconSelectionWindow and iconSelectionWindow.selectedIcon ~= nil)
        if iconSelectionWindow.saveBtn then
            local enable = nameOk and iconOk
            iconSelectionWindow.saveBtn:Enable(enable)
        end
    end

    for idx, iconPath in ipairs(availableIcons) do
        local row = math.floor((idx - 1) / iconsPerRow)
        local col = (idx - 1) % iconsPerRow
        local x = col * iconSpacing + 10
        local y = row * iconSpacing + 10

        local iconBtn = iconGrid:CreateChildWidget("button", "iconBtn_" .. tostring(idx), 0, true)
        iconBtn:SetExtent(iconSize, iconSize)
        iconBtn:AddAnchor("TOPLEFT", iconGrid, x, y)
        iconBtn:Show(true)

        local iconDrawable = iconBtn:CreateIconDrawable("artwork")
        iconDrawable:SetExtent(iconSize, iconSize)
        iconDrawable:AddAnchor("CENTER", iconBtn, 0, 0)
        iconDrawable:AddTexture(iconPath)
        iconDrawable:SetVisible(true)

        local hoverOverlay = iconBtn:CreateIconDrawable("overlay")
        hoverOverlay:SetExtent(iconSize, iconSize)
        hoverOverlay:AddAnchor("CENTER", iconBtn, 0, 0)
        hoverOverlay:AddTexture(CONSTANTS.TEXTURES.HOVER_OVERLAY)
        hoverOverlay:SetVisible(false)

        local selectionOverlay = iconBtn:CreateIconDrawable("overlay")
        selectionOverlay:SetExtent(iconSize, iconSize)
        selectionOverlay:AddAnchor("CENTER", iconBtn, 0, 0)
        selectionOverlay:AddTexture(CONSTANTS.TEXTURES.SELECTION_OVERLAY)
        selectionOverlay:SetVisible(false)

        iconBtn.hoverOverlay = hoverOverlay
        iconBtn.selectionOverlay = selectionOverlay
        iconBtn.iconPath = iconPath

        function iconBtn:OnEnter()
            if self.hoverOverlay then
                self.hoverOverlay:SetVisible(true)
            end
        end
        iconBtn:SetHandler("OnEnter", iconBtn.OnEnter)

        function iconBtn:OnLeave()
            if self.hoverOverlay then
                self.hoverOverlay:SetVisible(false)
            end
        end
        iconBtn:SetHandler("OnLeave", iconBtn.OnLeave)

        function iconBtn:OnClick()
            if selectedIconButton and selectedIconButton.selectionOverlay then
                selectedIconButton.selectionOverlay:SetVisible(false)
            end
            
            iconSelectionWindow.selectedIcon = self.iconPath
            selectedIconButton = self
            if self.selectionOverlay then
                self.selectionOverlay:SetVisible(true)
            end
            
            UpdateSaveEnabled()
        end
        iconBtn:SetHandler("OnClick", iconBtn.OnClick)
    end

    local nameLabel = iconSelectionWindow:CreateChildWidget("label", "nameLabel", 0, false)
    nameLabel:SetHeight(20)
    nameLabel.style:SetFontSize(14)
    nameLabel:SetText("Set Name:")
    nameLabel:AddAnchor("BOTTOMLEFT", iconSelectionWindow, 50, -95)
    nameLabel.style:SetAlign(LEFT)
    nameLabel.style:SetColorByKey("brown")
    nameLabel:Show(true)

    local textBg = iconSelectionWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")  
    textBg:SetExtent(280, 25) 
    textBg:AddAnchor("LEFT", nameLabel, "RIGHT", 45, 0) 
    
    local textInput = iconSelectionWindow:CreateChildWidget("editboxmultiline", "setNameInput", 0, true)
    textInput:SetExtent(270, 20) 
    textInput.style:SetFontSize(14) 
    textInput:AddAnchor("LEFT", nameLabel, "RIGHT", 45, 0) 
    textInput.style:SetColorByKey("brown")
    textInput:SetMaxTextLength(20)
    textInput:Show(true)
    iconSelectionWindow.textInput = textInput
    iconSelectionWindow.currentText = ""
    textInput:SetCursorColorByColorKey("brown") 
    textInput:SetCursorHeight(-2)
    textInput:SetCursorOffset(-3) 

    local hotkeyLabel = iconSelectionWindow:CreateChildWidget("label", "hotkeyLabel", 0, false)
    hotkeyLabel:SetHeight(20)
    hotkeyLabel.style:SetFontSize(14)
    hotkeyLabel:SetText("Hotkey:")
    hotkeyLabel:AddAnchor("BOTTOMLEFT", iconSelectionWindow, 50, -15)
    hotkeyLabel.style:SetAlign(LEFT)
    hotkeyLabel.style:SetColorByKey("brown")
    hotkeyLabel:Show(true)
    
    local function GetNewSetHotkeyText()
        if not iconSelectionWindow or not iconSelectionWindow.keyTypeCombo then
            return ""
        end
        
        local keyType = iconSelectionWindow.keyTypeCombo:GetText()
        local key = iconSelectionWindow.keyCombo and iconSelectionWindow.keyCombo:GetText() or ""
        local modifier = iconSelectionWindow.modifierCombo and iconSelectionWindow.modifierCombo:GetText() or "None"
        
        return HotkeyUtils.BuildHotkeyString(keyType, key, modifier)
    end

    local function UpdateNewSetSaveEnabled()
        local nameText = iconSelectionWindow.currentText or ""
        local nameOk = (nameText ~= "")
        local iconOk = (iconSelectionWindow and iconSelectionWindow.selectedIcon ~= nil)
        
        local keyType = iconSelectionWindow.keyTypeCombo and iconSelectionWindow.keyTypeCombo:GetText() or "None"
        local key = iconSelectionWindow.keyCombo and iconSelectionWindow.keyCombo:GetText() or ""
        local validHotkey = (keyType == "None") or (key ~= "")
        
        if iconSelectionWindow.saveBtn then
            local enable = nameOk and iconOk and validHotkey
            iconSelectionWindow.saveBtn:Enable(enable)
        end
    end
    
    local keyTypeOptions = {
        { text = "None", handler = function()
            if iconSelectionWindow.keyCombo then iconSelectionWindow.keyCombo:Show(false) end
            if iconSelectionWindow.modifierCombo then iconSelectionWindow.modifierCombo:Show(false) end
            UpdateNewSetSaveEnabled()
        end },
        { text = "Letters", handler = function()
            local keys = HotkeyUtils.GetKeysByType("Letters")
            local keyOptions = {}
            for _, key in ipairs(keys) do
                table.insert(keyOptions, { text = key, handler = function()
                    UpdateNewSetSaveEnabled()
                end })
            end
            if iconSelectionWindow.keyCombo then iconSelectionWindow.keyCombo:Show(false) end
            iconSelectionWindow.keyCombo = CreateComboBox(iconSelectionWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
            iconSelectionWindow.keyCombo:Show(true)
            if iconSelectionWindow.modifierCombo then
                iconSelectionWindow.modifierCombo:SetText("None")
                iconSelectionWindow.modifierCombo:Show(true)
            end
            UpdateNewSetSaveEnabled()
        end },
        { text = "Digits", handler = function()
            local keys = HotkeyUtils.GetKeysByType("Digits")
            local keyOptions = {}
            for _, key in ipairs(keys) do
                table.insert(keyOptions, { text = key, handler = function()
                    UpdateNewSetSaveEnabled()
                end })
            end
            if iconSelectionWindow.keyCombo then iconSelectionWindow.keyCombo:Show(false) end
            iconSelectionWindow.keyCombo = CreateComboBox(iconSelectionWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
            iconSelectionWindow.keyCombo:Show(true)
            if iconSelectionWindow.modifierCombo then
                iconSelectionWindow.modifierCombo:SetText("None")
                iconSelectionWindow.modifierCombo:Show(true)
            end
            UpdateNewSetSaveEnabled()
        end },
        { text = "Numpad", handler = function()
            local keys = HotkeyUtils.GetKeysByType("Numpad")
            local keyOptions = {}
            for _, key in ipairs(keys) do
                table.insert(keyOptions, { text = key, handler = function()
                    UpdateNewSetSaveEnabled()
                end })
            end
            if iconSelectionWindow.keyCombo then iconSelectionWindow.keyCombo:Show(false) end
            iconSelectionWindow.keyCombo = CreateComboBox(iconSelectionWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
            iconSelectionWindow.keyCombo:Show(true)
            if iconSelectionWindow.modifierCombo then
                iconSelectionWindow.modifierCombo:SetText("None")
                iconSelectionWindow.modifierCombo:Show(true)
            end
            UpdateNewSetSaveEnabled()
        end },
        { text = "Functions", handler = function()
            local keys = HotkeyUtils.GetKeysByType("Functions")
            local keyOptions = {}
            for _, key in ipairs(keys) do
                table.insert(keyOptions, { text = key, handler = function()
                    UpdateNewSetSaveEnabled()
                end })
            end
            if iconSelectionWindow.keyCombo then iconSelectionWindow.keyCombo:Show(false) end
            iconSelectionWindow.keyCombo = CreateComboBox(iconSelectionWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
            iconSelectionWindow.keyCombo:Show(true)
            if iconSelectionWindow.modifierCombo then
                iconSelectionWindow.modifierCombo:SetText("None")
                iconSelectionWindow.modifierCombo:Show(true)
            end
            UpdateNewSetSaveEnabled()
        end },
        { text = "Mouse", handler = function()
            local keys = HotkeyUtils.GetKeysByType("Mouse")
            local keyOptions = {}
            for _, key in ipairs(keys) do
                table.insert(keyOptions, { text = key, handler = function()
                    UpdateNewSetSaveEnabled()
                end })
            end
            if iconSelectionWindow.keyCombo then iconSelectionWindow.keyCombo:Show(false) end
            iconSelectionWindow.keyCombo = CreateComboBox(iconSelectionWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
            iconSelectionWindow.keyCombo:Show(true)
            if iconSelectionWindow.modifierCombo then
                iconSelectionWindow.modifierCombo:SetText("None")
                iconSelectionWindow.modifierCombo:Show(true)
            end
            UpdateNewSetSaveEnabled()
        end }
    }
    
    iconSelectionWindow.keyTypeCombo = CreateComboBox(iconSelectionWindow, 80, 25, 6, keyTypeOptions, 25, "LEFT", hotkeyLabel, 45, -2)
    iconSelectionWindow.keyTypeCombo:SetText("None")
    
    local modifierOptions = {
        { text = "None", handler = function() UpdateNewSetSaveEnabled() end },
        { text = "Shift", handler = function() UpdateNewSetSaveEnabled() end },
        { text = "Ctrl", handler = function() UpdateNewSetSaveEnabled() end },
        { text = "Alt", handler = function() UpdateNewSetSaveEnabled() end }
    }
    
    iconSelectionWindow.modifierCombo = CreateComboBox(iconSelectionWindow, 80, 25, 4, modifierOptions, 25, "LEFT", hotkeyLabel, 240, -2)
    iconSelectionWindow.modifierCombo:SetText("None")
    iconSelectionWindow.modifierCombo:Show(false) 


    local saveBtn = iconSelectionWindow:CreateChildWidget("button", "saveBtn", 0, true)
    saveBtn:SetExtent(80, 30)
    saveBtn:SetText("Save")
    saveBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
    saveBtn:AddAnchor("BOTTOMRIGHT", iconSelectionWindow, -15, -50)
    saveBtn:Enable(false)
    saveBtn:Show(true)
    iconSelectionWindow.saveBtn = saveBtn

    local cancelBtn = iconSelectionWindow:CreateChildWidget("button", "cancelBtn", 0, true)
    cancelBtn:SetExtent(80, 30)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
    cancelBtn:AddAnchor("BOTTOMLEFT", iconSelectionWindow, 15, -50)
    cancelBtn:Show(true)

    if textInput.SetHandler then
        function textInput:OnTextChanged()
            local currentText = textInput:GetText() or ""
            currentText = currentText:match("^%s*(.-)%s*$") or ""
            if #currentText > 20 then
                currentText = string.sub(currentText, 1, 20)
                textInput:SetText(currentText)
            end
            iconSelectionWindow.currentText = currentText
            
            UpdateNewSetSaveEnabled()
        end
        textInput:SetHandler("OnTextChanged", textInput.OnTextChanged)
        
    end

    function saveBtn:OnClick()
        local setName = iconSelectionWindow.currentText or ""
        local hotkey = GetNewSetHotkeyText()
        local hasIcon = (iconSelectionWindow and iconSelectionWindow.selectedIcon ~= nil)
        if setName and string.len(setName) > 0 and hasIcon then
            SaveNewSet(setName, iconSelectionWindow.selectedIcon, hotkey)
            iconSelectionWindow.selectedIcon = nil
            iconSelectionWindow:Show(false)
        end
    end
    saveBtn:SetHandler("OnClick", saveBtn.OnClick)


    function cancelBtn:OnClick()
        iconSelectionWindow.selectedIcon = nil
        iconSelectionWindow:Show(false)
    end
    cancelBtn:SetHandler("OnClick", cancelBtn.OnClick)

    iconSelectionWindow:Show(true)

end

function ShowEditSetWindow(set)
    if not set then return end
    if editSetWindow then
        editSetWindow:Show(false)
        editSetWindow = nil
    end

    editSetWindow = CreateEmptyWindow("editSetWindow", "UIParent")
    editSetWindow:AddAnchor("CENTER", "UIParent", 0, 0)
    editSetWindow:SetCloseOnEscape(true)
    editSetWindow:EnableDrag(true)

    local function OnShow()
        SettingWindowSkin(editSetWindow)
        editSetWindow:SetStartAnimation(true, true)
    end
    editSetWindow:SetHandler("OnShow", OnShow)

    function editSetWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    editSetWindow:SetHandler("OnDragStart", editSetWindow.OnDragStart)

    function editSetWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
    end
    editSetWindow:SetHandler("OnDragStop", editSetWindow.OnDragStop)

    local title = editSetWindow:CreateChildWidget("label", "editTitle", 0, false)
    title:SetHeight(20)
    title.style:SetFontSize(18)
    local originalName = tostring(set.Text or "")
    local originalIcon = FixIconPath(set.Icon)
    title:SetText("Edit Set: " .. originalName)
    title:AddAnchor("TOP", editSetWindow, 0, 10)
    title.style:SetAlign(CENTER)
    title.style:SetColorByKey("brown")
    editSetWindow.titleLabel = title

    local closeX = editSetWindow:CreateChildWidget("button", "editCloseX", 0, true)
    closeX:SetExtent(30, 30)
    closeX:SetStyle(CONSTANTS.STYLES.BTN_CLOSE_DEFAULT)
    closeX:AddAnchor("TOPRIGHT", editSetWindow, -5, 5)
    closeX:Show(true)
    function closeX:OnClick()
        editSetWindow:Show(false)
    end
    closeX:SetHandler("OnClick", closeX.OnClick)

    local iconGrid = editSetWindow:CreateChildWidget("window", "iconGrid", 0, true)
    iconGrid:AddAnchor("TOPLEFT", editSetWindow, 10, 40)
    iconGrid:AddAnchor("TOPRIGHT", editSetWindow, -10, 0)
    iconGrid:SetHeight(200)
    iconGrid:Show(true)

    editSetWindow.selectedIcon = originalIcon
    editSetWindow.currentText = originalName
    editSetWindow.originalName = originalName
    editSetWindow.originalIcon = originalIcon
    editSetWindow.currentHotkey = set.Hotkey or ""
    editSetWindow.originalHotkey = set.Hotkey or ""

    local iconsPerRow = 6
    local iconSize = 48
    local iconSpacing = 60
    local selectedIconButton = nil

    local totalIcons = availableIcons and #availableIcons or 0
    local iconRows = math.ceil(totalIcons / iconsPerRow)
    local gridWidth = iconsPerRow * iconSpacing - (iconSpacing - iconSize) + 20
    local gridHeight = iconRows * iconSpacing + 20
    local windowWidth = gridWidth + 20
    local windowHeight = gridHeight + 150
    editSetWindow:SetExtent(windowWidth, windowHeight)

    local function GetEditText()
        if editSetWindow and editSetWindow.textInput and editSetWindow.textInput.GetText then
            local t = editSetWindow.textInput:GetText()
            if t ~= nil then
                return tostring(t):match("^%s*(.-)%s*$") or ""
            end
        end
        return tostring(editSetWindow.currentText or "")
    end

    editSetWindow.overwriteActive = false
    
    local function GetHotkeyText()
        if not editSetWindow or not editSetWindow.keyTypeCombo then
            return ""
        end
        
        local keyType = editSetWindow.keyTypeCombo:GetText()
        local key = editSetWindow.keyCombo and editSetWindow.keyCombo:GetText() or ""
        local modifier = editSetWindow.modifierCombo and editSetWindow.modifierCombo:GetText() or "None"
        
        return HotkeyUtils.BuildHotkeyString(keyType, key, modifier)
    end
    
    local function UpdateSaveEnabled()
        local nameText = GetEditText()
        local keyType = editSetWindow.keyTypeCombo and editSetWindow.keyTypeCombo:GetText() or "None"
        local key = editSetWindow.keyCombo and editSetWindow.keyCombo:GetText() or ""
        local modifier = editSetWindow.modifierCombo and editSetWindow.modifierCombo:GetText() or "None"
        
        local iconSelected = (editSetWindow and editSetWindow.selectedIcon ~= nil)
        local nameChanged = (nameText ~= (editSetWindow.originalName or ""))
        local iconChanged = ((editSetWindow.selectedIcon or "") ~= (editSetWindow.originalIcon or ""))
        local hotkeyChanged = (GetHotkeyText() ~= (editSetWindow.originalHotkey or ""))
        local changed = nameChanged or iconChanged or hotkeyChanged
        local validHotkey = HotkeyUtils.IsValidHotkeySelection(keyType, key, modifier)
        local enable = (nameText ~= "" and iconSelected and validHotkey and (changed or editSetWindow.overwriteActive))
        
        if editSetWindow.saveBtn then
            editSetWindow.saveBtn:Enable(enable)
        end
        
    end

    for idx, iconPath in ipairs(availableIcons or {}) do
        local row = math.floor((idx - 1) / iconsPerRow)
        local col = (idx - 1) % iconsPerRow
        local x = col * iconSpacing + 10
        local y = row * iconSpacing + 10

        local iconBtn = iconGrid:CreateChildWidget("button", "editIconBtn_" .. tostring(idx), 0, true)
        iconBtn:SetExtent(iconSize, iconSize)
        iconBtn:AddAnchor("TOPLEFT", iconGrid, x, y)
        iconBtn:Show(true)

        local iconDrawable = iconBtn:CreateIconDrawable("artwork")
        iconDrawable:SetExtent(iconSize, iconSize)
        iconDrawable:AddAnchor("CENTER", iconBtn, 0, 0)
        iconDrawable:AddTexture(iconPath)
        iconDrawable:SetVisible(true)

        local hoverOverlay = iconBtn:CreateIconDrawable("overlay")
        hoverOverlay:SetExtent(iconSize, iconSize)
        hoverOverlay:AddAnchor("CENTER", iconBtn, 0, 0)
        hoverOverlay:AddTexture(CONSTANTS.TEXTURES.HOVER_OVERLAY)
        hoverOverlay:SetVisible(false)

        local selectionOverlay = iconBtn:CreateIconDrawable("overlay")
        selectionOverlay:SetExtent(iconSize, iconSize)
        selectionOverlay:AddAnchor("CENTER", iconBtn, 0, 0)
        selectionOverlay:AddTexture(CONSTANTS.TEXTURES.SELECTION_OVERLAY)
        selectionOverlay:SetVisible(false)

        iconBtn.hoverOverlay = hoverOverlay
        iconBtn.selectionOverlay = selectionOverlay
        iconBtn.iconPath = iconPath

        if FixIconPath(iconPath) == editSetWindow.selectedIcon then
            selectedIconButton = iconBtn
            selectionOverlay:SetVisible(true)
        end

        function iconBtn:OnEnter()
            if self.hoverOverlay then self.hoverOverlay:SetVisible(true) end
        end
        iconBtn:SetHandler("OnEnter", iconBtn.OnEnter)

        function iconBtn:OnLeave()
            if self.hoverOverlay then self.hoverOverlay:SetVisible(false) end
        end
        iconBtn:SetHandler("OnLeave", iconBtn.OnLeave)

        function iconBtn:OnClick()
            if selectedIconButton and selectedIconButton.selectionOverlay then
                selectedIconButton.selectionOverlay:SetVisible(false)
            end
            editSetWindow.selectedIcon = self.iconPath
            selectedIconButton = self
            if self.selectionOverlay then self.selectionOverlay:SetVisible(true) end
            UpdateSaveEnabled()
        end
        iconBtn:SetHandler("OnClick", iconBtn.OnClick)
    end

    local nameLabel = editSetWindow:CreateChildWidget("label", "nameLabel", 0, false)
    nameLabel:SetHeight(20)
    nameLabel.style:SetFontSize(14)
    nameLabel:SetText("Set Name:")
    nameLabel:AddAnchor("BOTTOMLEFT", editSetWindow, 50, -95)
    nameLabel.style:SetAlign(LEFT)
    nameLabel.style:SetColorByKey("brown")
    nameLabel:Show(true)
    
    local hotkeyLabel = editSetWindow:CreateChildWidget("label", "hotkeyLabel", 0, false)
    hotkeyLabel:SetHeight(20)
    hotkeyLabel.style:SetFontSize(14)
    hotkeyLabel:SetText("Hotkey:")
    hotkeyLabel:AddAnchor("BOTTOMLEFT", editSetWindow, 50, -15)
    hotkeyLabel.style:SetAlign(LEFT)
    hotkeyLabel.style:SetColorByKey("brown")
    hotkeyLabel:Show(true)

    local textBg = editSetWindow:CreateColorDrawable(0, 0, 0, 0.35, "artwork")
    textBg:SetExtent(280, 25)
    textBg:AddAnchor("LEFT", nameLabel, "RIGHT", 45, 0)
    
    local textInput = editSetWindow:CreateChildWidget("editboxmultiline", "setNameInput", 0, true)
    textInput:SetExtent(270, 20)
    textInput.style:SetFontSize(14)
    textInput:AddAnchor("LEFT", nameLabel, "RIGHT", 45, 0)
    textInput.style:SetColorByKey("brown")
    textInput:SetMaxTextLength(20)
    textInput:Show(true)
    editSetWindow.textInput = textInput
    editSetWindow.currentText = tostring(set.Text or "")
    textInput:SetText(editSetWindow.currentText)
    textInput:SetCursorColorByColorKey("brown") 
    textInput:SetCursorHeight(-2)
    textInput:SetCursorOffset(-3)
        
    local keyTypeOptions = {
        { text = "None", handler = function()
            if editSetWindow.keyCombo then editSetWindow.keyCombo:Show(false) end
            if editSetWindow.modifierCombo then editSetWindow.modifierCombo:Show(false) end
            UpdateSaveEnabled()
        end },
        { text = "Letters", handler = function()
            local keys = HotkeyUtils.GetKeysByType("Letters")
            local keyOptions = {}
            for _, key in ipairs(keys) do
                table.insert(keyOptions, { text = key, handler = function() UpdateSaveEnabled() end })
            end
            if editSetWindow.keyCombo then editSetWindow.keyCombo:Show(false) end
            editSetWindow.keyCombo = CreateComboBox(editSetWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
            editSetWindow.keyCombo:Show(true)
            if editSetWindow.modifierCombo then editSetWindow.modifierCombo:Show(true) end
            UpdateSaveEnabled()
        end },
        { text = "Digits", handler = function()
            local keys = HotkeyUtils.GetKeysByType("Digits")
            local keyOptions = {}
            for _, key in ipairs(keys) do
                table.insert(keyOptions, { text = key, handler = function() UpdateSaveEnabled() end })
            end
            if editSetWindow.keyCombo then editSetWindow.keyCombo:Show(false) end
            editSetWindow.keyCombo = CreateComboBox(editSetWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
            editSetWindow.keyCombo:Show(true)
            if editSetWindow.modifierCombo then editSetWindow.modifierCombo:Show(true) end
            UpdateSaveEnabled()
        end },
        { text = "Numpad", handler = function()
            local keys = HotkeyUtils.GetKeysByType("Numpad")
            local keyOptions = {}
            for _, key in ipairs(keys) do
                table.insert(keyOptions, { text = key, handler = function() UpdateSaveEnabled() end })
            end
            if editSetWindow.keyCombo then editSetWindow.keyCombo:Show(false) end
            editSetWindow.keyCombo = CreateComboBox(editSetWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
            editSetWindow.keyCombo:Show(true)
            if editSetWindow.modifierCombo then editSetWindow.modifierCombo:Show(true) end
            UpdateSaveEnabled()
        end },
        { text = "Functions", handler = function()
            local keys = HotkeyUtils.GetKeysByType("Functions")
            local keyOptions = {}
            for _, key in ipairs(keys) do
                table.insert(keyOptions, { text = key, handler = function() UpdateSaveEnabled() end })
            end
            if editSetWindow.keyCombo then editSetWindow.keyCombo:Show(false) end
            editSetWindow.keyCombo = CreateComboBox(editSetWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
            editSetWindow.keyCombo:Show(true)
            if editSetWindow.modifierCombo then editSetWindow.modifierCombo:Show(true) end
            UpdateSaveEnabled()
        end },
        { text = "Mouse", handler = function()
            local keys = HotkeyUtils.GetKeysByType("Mouse")
            local keyOptions = {}
            for _, key in ipairs(keys) do
                table.insert(keyOptions, { text = key, handler = function() UpdateSaveEnabled() end })
            end
            if editSetWindow.keyCombo then editSetWindow.keyCombo:Show(false) end
            editSetWindow.keyCombo = CreateComboBox(editSetWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
            editSetWindow.keyCombo:Show(true)
            if editSetWindow.modifierCombo then editSetWindow.modifierCombo:Show(true) end
            UpdateSaveEnabled()
        end }
    }
    
    editSetWindow.keyTypeCombo = CreateComboBox(editSetWindow, 80, 25, 6, keyTypeOptions, 25, "LEFT", hotkeyLabel, 45, -2)
    editSetWindow.keyTypeCombo:SetText("None")
    
    local modifierOptions = {
        { text = "None", handler = function() UpdateSaveEnabled() end },
        { text = "Shift", handler = function() UpdateSaveEnabled() end },
        { text = "Ctrl", handler = function() UpdateSaveEnabled() end },
        { text = "Alt", handler = function() UpdateSaveEnabled() end }
    }
    
    editSetWindow.modifierCombo = CreateComboBox(editSetWindow, 80, 25, 4, modifierOptions, 25, "LEFT", hotkeyLabel, 240, -2)
    editSetWindow.modifierCombo:SetText("None")
    editSetWindow.modifierCombo:Show(false) 
    
    if set.Hotkey and set.Hotkey ~= "" then
        local currentModifier, currentKey = ParseHotkeyString(set.Hotkey)
        if currentModifier and currentKey then
            local keyType = "None"
            local displayKey = currentKey
            
            if currentKey:match("^F%d+$") then
                keyType = "Functions"
            elseif currentKey:match("^%d$") then
                keyType = "Digits"
            elseif currentKey:match("^NUMBER") then
                keyType = "Numpad"
                displayKey = HotkeyUtils.keyApiToDisplay[currentKey] or currentKey
            elseif currentKey == "MIDDLEBUTTON" or currentKey == "WHEELUP" or currentKey == "WHEELDOWN" or currentKey == "MOUSE4" or currentKey == "MOUSE5" then
                keyType = "Mouse"
                displayKey = HotkeyUtils.keyApiToDisplay[currentKey] or currentKey
            elseif currentKey:match("^[A-Z]$") then
                keyType = "Letters"
            end
            
            editSetWindow.keyTypeCombo:SetText(keyType)
            
            if keyType ~= "None" then
                local keys = HotkeyUtils.GetKeysByType(keyType)
                local keyOptions = {}
                for _, key in ipairs(keys) do
                    table.insert(keyOptions, { text = key, handler = function() end })
                end
                editSetWindow.keyCombo = CreateComboBox(editSetWindow, 80, 25, 8, keyOptions, 25, "LEFT", hotkeyLabel, 150, -2)
                editSetWindow.keyCombo:SetText(displayKey)
                editSetWindow.keyCombo:Show(true)
            end
            
            if keyType ~= "None" then
                editSetWindow.modifierCombo:Show(true)
                if currentModifier == "Ctrl" then
                    editSetWindow.modifierCombo:SetText("Ctrl")
                elseif currentModifier == "Shift" then
                    editSetWindow.modifierCombo:SetText("Shift")
                elseif currentModifier == "Alt" then
                    editSetWindow.modifierCombo:SetText("Alt")
                else
                    editSetWindow.modifierCombo:SetText("None")
                end
            else
                editSetWindow.modifierCombo:Show(false)
            end
        end
    end

    local saveBtn = editSetWindow:CreateChildWidget("button", "saveBtn", 0, true)
    saveBtn:SetExtent(80, 30)
    saveBtn:SetText("Save")
    saveBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
    saveBtn:AddAnchor("BOTTOMRIGHT", editSetWindow, -10, -50)
    saveBtn:Show(true)
    editSetWindow.saveBtn = saveBtn

    local overwriteBtn = editSetWindow:CreateChildWidget("button", "overwriteBtn", 0, true)
    overwriteBtn:SetExtent(130, 30)
    overwriteBtn:SetStyle("text_default")
    overwriteBtn:AddAnchor("RIGHT", saveBtn, "LEFT", -10, 0)
    overwriteBtn:Show(true)

    local function UpdateOverwriteVisual()
        if editSetWindow.overwriteActive then
            overwriteBtn:SetText("Overwrite Set [ON]")
            overwriteBtn:SetTextColor(0, 1, 0, 1)
        else
            overwriteBtn:SetText("Overwrite Set [OFF]")
            if overwriteBtn.style and overwriteBtn.style.SetColorByKey then
                overwriteBtn.style:SetColorByKey("brown")
            end
        end
    end

    function overwriteBtn:OnClick()
        editSetWindow.overwriteActive = not editSetWindow.overwriteActive
        UpdateOverwriteVisual()
        UpdateSaveEnabled()
    end

    overwriteBtn:SetHandler("OnClick", overwriteBtn.OnClick)
    function overwriteBtn:OnEnter()
        UpdateOverwriteVisual()
    end
    function overwriteBtn:OnLeave()
        UpdateOverwriteVisual()
    end
    overwriteBtn:SetHandler("OnEnter", overwriteBtn.OnEnter)
    overwriteBtn:SetHandler("OnLeave", overwriteBtn.OnLeave)
    UpdateOverwriteVisual()

    local cancelBtn = editSetWindow:CreateChildWidget("button", "cancelBtn", 0, true)
    cancelBtn:SetExtent(80, 30)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
    cancelBtn:AddAnchor("BOTTOMLEFT", editSetWindow, 10, -50)
    cancelBtn:Show(true)
    function cancelBtn:OnClick()
        editSetWindow:Show(false)
    end
    cancelBtn:SetHandler("OnClick", cancelBtn.OnClick)

    if textInput.SetHandler then
        function textInput:OnTextChanged()
            local currentText = textInput:GetText() or ""
            currentText = currentText:match("^%s*(.-)%s*$") or ""
            if #currentText > 20 then
                currentText = string.sub(currentText, 1, 20)
                textInput:SetText(currentText)
            end
            editSetWindow.currentText = currentText
            UpdateSaveEnabled()
        end
        textInput:SetHandler("OnTextChanged", textInput.OnTextChanged)
    end
    

    function saveBtn:OnClick()
        local newName = GetEditText()
        local newIcon = editSetWindow.selectedIcon
        local newHotkey = GetHotkeyText()
        
        if newName and #newName > 0 and newIcon then
            local oldName = tostring(set.Text or "")
            local oldHotkey = tostring(set.Hotkey or "")
            
            if newName ~= oldName then
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF35CAEESet |cFF35EE35name changed from |cFFFFD700'" .. oldName .. "'|cFF35EE35 to |cFFFFD700'" .. newName .. "'")
            end
            
            local function GetIconShort(p)
                local s = tostring(p or "")
                s = s:gsub("\\", "/")
                s = s:match("([^/]+)$") or s
                return s
            end
            
            if (newIcon or "") ~= (editSetWindow.originalIcon or "") then
                local fromS = GetIconShort(editSetWindow.originalIcon)
                local toS = GetIconShort(newIcon)
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF35CAEESet |cFFFFD700'" .. newName .. "'|cFF35EE35 changed icon from |cFFFFD700" .. tostring(fromS) .. "|cFF35EE35 to |cFFFFD700" .. tostring(toS))
            end
            
            if newHotkey ~= oldHotkey then
                UnregisterGearSetHotkey(set)
                if newHotkey == "" then
                    X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF35CAEESet |cFFFFD700'" .. newName .. "'|cFFEE5535: hotkey removed")
                else
                    X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF35CAEESet |cFFFFD700'" .. newName .. "'|cFF35EE35: hotkey changed to |cFFFFD700" .. newHotkey)
                end
            end
            
            if editSetWindow.overwriteActive then
                set.Items = GetCurrentEquippedGear()
                set.Title = GetCurrentEffectTitle()
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF35CAEESet |cFFFFD700'" .. newName .. "'|cFF35EE35: items and title overwritten from current gear/title.")
            end
            
            set.Text = newName
            set.Icon = FixIconPath(newIcon)
            set.Hotkey = (newHotkey ~= "") and newHotkey or nil
            
            SaveConfig()
            
            if set.Hotkey then
                RegisterGearSetHotkey(set)
            end
            
            RefreshEquipWindowButtons()
            RefreshOptionsWindowList()
            editSetWindow:Show(false)
        end
    end
    saveBtn:SetHandler("OnClick", saveBtn.OnClick)

    UpdateSaveEnabled()
    
    function editSetWindow:OnUpdate(dt)
        UpdateSaveEnabled()
    end
    editSetWindow:SetHandler("OnUpdate", editSetWindow.OnUpdate)

    editSetWindow:Show(true)
end

local equiping = false
equipWindow = equipWindow or CreateEmptyWindow("equipWindow", "UIParent")
equipWindow:Show(true)
local delay = 0
local cooldown = 20
local savedPositions = {}
local used_positions = {}
local itemsToProcess = {}
local filePath = "SavedEquipWindowPositions.txt"
buttonSize = buttonSize or 40
buttonSpacing = buttonSpacing or 42
windowPadding = windowPadding or 5
buttonsPerRow = buttonsPerRow or 3
lastClickedButton = lastClickedButton or nil
optionsWindow = optionsWindow or nil
iconSelectionWindow = iconSelectionWindow or nil
selectedIcon = selectedIcon or nil
pendingSetName = pendingSetName or nil

availableIcons = {}
for _, iconName in ipairs({"PVE.dds", "PVP.dds", "Packs.dds", "Sleep.dds", "Trade.dds", "merchants_costume_fishing.dds"}) do
    table.insert(availableIcons, CONSTANTS.ICONS_PATH .. iconName)
end
for i = 1, 36 do
    table.insert(availableIcons, CONSTANTS.ICONS_PATH .. i .. ".dds")
end

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
    if savedPositions["buttonsPerRow"] then
        buttonsPerRow = savedPositions["buttonsPerRow"].x
    end
end

local function SaveButtonsPerRow()
    savedPositions["buttonsPerRow"] = { x = buttonsPerRow, y = 0 }
    local file = io.open(filePath, "w")
    for k, pos in pairs(savedPositions) do
        file:write(string.format("%s,%d,%d\n", k, pos.x, pos.y))
    end
    file:close()
end

local function SaveWindowPosition(name, x, y)
    savedPositions[name] = { x = x, y = y }
    local file = io.open(filePath, "w")
    for name, pos in pairs(savedPositions) do
        file:write(string.format("%s,%d,%d\n", name, pos.x, pos.y))
    end
    file:close()
end

local function GetUIScaleFactor()
    return UIParent:GetUIScale() or 1.0
end

local function ToggleOptionsWindow()
    if optionsWindow and optionsWindow:IsVisible() then
        optionsWindow:Show(false)
        return
    end
    
    if optionsWindow then
        optionsWindow:Show(true)
        return
    end

    optionsWindow = CreateEmptyWindow("optionsWindow", "UIParent")
    optionsWindow:AddAnchor("CENTER", "UIParent", 0, 0)
    optionsWindow:SetCloseOnEscape(true)

    local function OnShow()
        if optionsWindow.ShowProc ~= nil then
            optionsWindow:ShowProc()
        end
    
        SettingWindowSkin(optionsWindow)
        optionsWindow:SetStartAnimation(true, true)
    end

    optionsWindow:SetHandler("OnShow", OnShow)
    optionsWindow:EnableDrag(true)

    function optionsWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    optionsWindow:SetHandler("OnDragStart", optionsWindow.OnDragStart)

    function optionsWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
    end
    optionsWindow:SetHandler("OnDragStop", optionsWindow.OnDragStop)
    optionsWindow.rowWidgets = {}

    local title = optionsWindow:CreateChildWidget("label", "title", 0, false)
    title:SetHeight(20)
    title.style:SetFontSize(20)
    title:SetText("Set Settings")
    title:AddAnchor("TOP", optionsWindow, 0, 10)
    title.style:SetAlign(CENTER)
    title.style:SetColorByKey("brown")

    local closeX = optionsWindow:CreateChildWidget("button", "closeX", 0, true)
    closeX:SetExtent(35, 35)
    closeX:SetStyle(CONSTANTS.STYLES.BTN_CLOSE_DEFAULT)
    closeX:AddAnchor("TOPRIGHT", optionsWindow, -5, 5)
    closeX:Show(true)

    function closeX:OnClick()
        optionsWindow:Show(false)
    end
    closeX:SetHandler("OnClick", closeX.OnClick)

    local listContainer = optionsWindow:CreateChildWidget("window", "setList", 0, true)
    listContainer:AddAnchor("TOPLEFT", optionsWindow, 10, 50)
    listContainer:AddAnchor("BOTTOMRIGHT", optionsWindow, -10, -80)
    listContainer:Show(true)
    optionsWindow.listContainer = listContainer

    local rowHeight = 36
    local yOffset = 0
    local playerName = X2Unit:UnitName("player")
    
    local setCount = 0
    for _, set in ipairs(config) do
        if set.Char and set.Char == playerName then
            setCount = setCount + 1
        end
    end
    
    local windowHeight = 50 + (setCount * rowHeight) + 50 + 20
    local minHeight = 200 
    windowHeight = math.max(windowHeight, minHeight)
    optionsWindow:SetExtent(400, windowHeight)
    
    local visibleIndex = 0
    for i = 1, #config do
        local set = config[i]
        if set.Char and set.Char == playerName then
            local row = listContainer:CreateChildWidget("window", "row_" .. tostring(i), 0, true)
            row:SetExtent( listContainer:GetWidth() or 360, rowHeight)
            row:AddAnchor("TOPLEFT", listContainer, 0, yOffset)
            row:Show(true)

            local icon = row:CreateIconDrawable("artwork")
            icon:SetExtent(32, 32)
            icon:AddAnchor("LEFT", row, 0, 0)
            icon:AddTexture(set.Icon)
            icon:SetVisible(true)

            local nameLabel = row:CreateChildWidget("label", "name_" .. tostring(i), 0, true)
            nameLabel:SetHeight(32)
            nameLabel:SetAutoResize(true)
            local displayText = set.Text or ""
            if set.Hotkey and set.Hotkey ~= "" then
                displayText = displayText .. " [" .. DisplayHotkey(set.Hotkey) .. "]"
            end
            nameLabel:SetText(displayText)
            nameLabel:AddAnchor("LEFT", icon, "RIGHT", 8, 0)
            nameLabel.style:SetColorByKey("default")
            nameLabel:Show(true)
            
            local moveUpBtn = row:CreateChildWidget("button", "moveUp_" .. tostring(i), 0, true)            
            moveUpBtn:SetText("Up")
            moveUpBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
            moveUpBtn:AddAnchor("RIGHT", row, -160, 0)
            moveUpBtn:SetExtent(40, 30)
            moveUpBtn:Show(true)
            function moveUpBtn:OnClick()
                MoveSetUp(set.Text or "")
            end
            moveUpBtn:SetHandler("OnClick", moveUpBtn.OnClick)
            
            local moveDownBtn = row:CreateChildWidget("button", "moveDown_" .. tostring(i), 0, true)
            moveDownBtn:SetText("Down")
            moveDownBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
            moveDownBtn:AddAnchor("RIGHT", row, -95, 0)
            moveDownBtn:SetExtent(60, 30)
            moveDownBtn:Show(true)
            function moveDownBtn:OnClick()
                MoveSetDown(set.Text or "")
            end
            moveDownBtn:SetHandler("OnClick", moveDownBtn.OnClick)

            local editBtn = row:CreateChildWidget("button", "edit_" .. tostring(i), 0, true)
            editBtn:SetText("Edit")
            editBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
            editBtn:AddAnchor("RIGHT", row, -50, 0)
            editBtn:SetExtent(40, 30)
            editBtn:Show(true)

            function editBtn:OnClick()
                ShowEditSetWindow(set)
            end
            editBtn:SetHandler("OnClick", editBtn.OnClick)

            local deleteBtn = row:CreateChildWidget("button", "delete_" .. tostring(i), 0, true)            
            deleteBtn:SetText("X")
            deleteBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
            deleteBtn:AddAnchor("RIGHT", row, -5, 0)
            deleteBtn:SetExtent(40, 30)
            deleteBtn:Show(true)
            function deleteBtn:OnClick()
                DeleteSet(set.Text or "")
            end
            deleteBtn:SetHandler("OnClick", deleteBtn.OnClick)

            visibleIndex = visibleIndex + 1
            if moveUpBtn.Enable then moveUpBtn:Enable(visibleIndex > 1) end
            if moveDownBtn.Enable then moveDownBtn:Enable(visibleIndex < setCount) end

            yOffset = yOffset + rowHeight
        end
    end

    local rowsLabel = optionsWindow:CreateChildWidget("label", "rowsLabel", 0, true)
    rowsLabel:SetHeight(20)
    rowsLabel:SetAutoResize(true)
    rowsLabel.style:SetFontSize(11)
    rowsLabel.style:SetColorByKey("brown")
    rowsLabel:SetText("Rows:")
    rowsLabel:AddAnchor("BOTTOMLEFT", optionsWindow, 10, -18)
    rowsLabel:Show(true)

    local rowsLeftBtn = optionsWindow:CreateChildWidget("button", "rowsLeftBtn", 0, true)
    rowsLeftBtn:SetExtent(14, 16)
    rowsLeftBtn:SetText("<")
    rowsLeftBtn:AddAnchor("LEFT", rowsLabel, "RIGHT", 4, 0)
    rowsLeftBtn:Show(true)

    local rowsCountLabel = optionsWindow:CreateChildWidget("label", "rowsCountLabel", 0, true)
    rowsCountLabel:SetHeight(20)
    rowsCountLabel:SetAutoResize(true)
    rowsCountLabel.style:SetFontSize(11)
    rowsCountLabel.style:SetColorByKey("brown")
    rowsCountLabel.style:SetAlign(ALIGN_CENTER)
    rowsCountLabel:SetText(tostring(buttonsPerRow))
    rowsCountLabel:AddAnchor("LEFT", rowsLeftBtn, "RIGHT", 4, 0)
    rowsCountLabel:Show(true)

    local rowsRightBtn = optionsWindow:CreateChildWidget("button", "rowsRightBtn", 0, true)
    rowsRightBtn:SetExtent(14, 16)
    rowsRightBtn:SetText(">")
    rowsRightBtn:AddAnchor("LEFT", rowsCountLabel, "RIGHT", 4, 0)
    rowsRightBtn:Show(true)

    function rowsLeftBtn:OnClick()
        if buttonsPerRow > 1 then
            buttonsPerRow = buttonsPerRow - 1
            rowsCountLabel:SetText(tostring(buttonsPerRow))
            SaveButtonsPerRow()
            RefreshEquipWindowButtons()
        end
    end
    rowsLeftBtn:SetHandler("OnClick", rowsLeftBtn.OnClick)

    function rowsRightBtn:OnClick()
        if buttonsPerRow < 20 then
            buttonsPerRow = buttonsPerRow + 1
            rowsCountLabel:SetText(tostring(buttonsPerRow))
            SaveButtonsPerRow()
            RefreshEquipWindowButtons()
        end
    end
    rowsRightBtn:SetHandler("OnClick", rowsRightBtn.OnClick)

    local saveBtn = optionsWindow:CreateChildWidget("button", "saveSetBtn", 0, true)
    saveBtn:SetExtent(120, 30)
    saveBtn:SetText("Save Current Set")
    saveBtn:SetStyle(CONSTANTS.STYLES.TEXT_DEFAULT)
    saveBtn:AddAnchor("BOTTOM", optionsWindow, 0, -15)
    saveBtn:Show(true)
    function saveBtn:OnClick()
        ShowIconSelectionWindow()
    end
    saveBtn:SetHandler("OnClick", saveBtn.OnClick)
    saveBtn:Enable(true)
    optionsWindow.saveBtn = saveBtn

    optionsWindow:Enable(true)
    optionsWindow:Show(true)
end

local versionWindow = nil

local function CreateVersionWindow()
    if versionWindow then
        return versionWindow
    end

    versionWindow = CreateEmptyWindow("combatClosetVersionWindow", "UIParent")
    versionWindow:SetExtent(660, 640)
    versionWindow:AddAnchor("CENTER", "UIParent", 0, 0)
    versionWindow:EnableDrag(true)
    versionWindow:SetCloseOnEscape(true)
    
    function versionWindow:OnShow()
        SettingWindowSkin(versionWindow)
        versionWindow:SetStartAnimation(true, true)
    end
    versionWindow:SetHandler("OnShow", versionWindow.OnShow)

    function versionWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    versionWindow:SetHandler("OnDragStart", versionWindow.OnDragStart)

    function versionWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
    end
    versionWindow:SetHandler("OnDragStop", versionWindow.OnDragStop)
    
    local closeButton = versionWindow:CreateChildWidget("button", "closeButton", 0, true)
    closeButton:SetStyle("text_default")
    closeButton:AddAnchor("TOPRIGHT", versionWindow, -10, 5)
    closeButton:SetText("X")
    closeButton:SetExtent(30, 20)
    closeButton:Show(true)
    
    function closeButton:OnClick()
        versionWindow:Show(false)
    end
    closeButton:SetHandler("OnClick", closeButton.OnClick)
    
    local webbrowser = UIParent:CreateWidget("webbrowser", "combatCloset_webbrowser", versionWindow)
    webbrowser:SetExtent(650, 600)
    webbrowser:AddAnchor("TOP", versionWindow, 0, 35)
    webbrowser:Show(true)
    versionWindow.webbrowser = webbrowser
    versionWindow:SetHandler("OnWheelUp", function() webbrowser:WheelUp() end)
    versionWindow:SetHandler("OnWheelDown", function() webbrowser:WheelDown() end)
    
    return versionWindow
end

local function CheckAddonVersion()
    local window = CreateVersionWindow()
    
    if window:IsVisible() then
        window:Show(false)
    else
        local addonName = "Combat%20Closet"
        local url = string.format("https://archerageaddonmanager.github.io/addon-version-checker/?addon=%s&version=%s", 
                                 addonName, ADDON_VERSION)
        
        window.webbrowser:RequestExternalPage("about:blank")
        window.webbrowser:RequestExternalPage(url)
        window:Show(true)
    end
end

local function SetupEscMenuButton()
    ADDON:AddEscMenuButton(2, 3200, "hero", "Combat Closet")
    ADDON:RegisterContentTriggerFunc(3200, function(show)
        if equipWindow then
            equipWindow:Show(not equipWindow:IsVisible())
        end
    end)
end

local function CreateEquipWindow()
    equipWindow:SetExtent(100, 45)
    equipWindow:AddAnchor("CENTER", "UIParent", 0, 0)

    local background = equipWindow:CreateColorDrawable(0, 0, 0, 0.5, "background")
    background:AddAnchor("TOPLEFT", equipWindow, 0, 0)
    background:AddAnchor("BOTTOMRIGHT", equipWindow, 0, 0)

    equipWindow:EnableDrag(true)

    function equipWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    equipWindow:SetHandler("OnDragStart", equipWindow.OnDragStart)

    function equipWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
        local correctedX, correctedY = self:CorrectOffsetByScreen()
        SaveWindowPosition("equipWindow", correctedX, correctedY)
    end
    equipWindow:SetHandler("OnDragStop", equipWindow.OnDragStop)

    local versionBtn = CreateActionButton({
        parent = equipWindow,
        name = "version_button",
        anchor = "BOTTOMLEFT",
        anchorTarget = equipWindow,
        anchorTargetPoint = "BOTTOMRIGHT",
        offsetX = 0,
        offsetY = -28,
        skin = CONSTANTS.STYLES.TEXT_DEFAULT,
        width = 24,
        height = 24,
        text = "?",
        handlers = {
            OnClick = function()
                CheckAddonVersion()
            end,
        },
    })
    versionBtn:Show(true)
    versionBtn:EnableDrag(false)

    local optionBtn = CreateActionButton({
        parent = equipWindow,
        name = "options_button",
        anchor = "BOTTOMLEFT",
        anchorTarget = equipWindow,
        anchorTargetPoint = "BOTTOMRIGHT",
        offsetX = 0,
        offsetY = 2,
        skin = CONSTANTS.STYLES.BUTTON_COMMON_OPTION,
        width = 24,
        height = 24,
        handlers = {
            OnClick = function()
                ToggleOptionsWindow()
            end,
        },
    })
    optionBtn:Show(true)
    optionBtn:EnableDrag(false)
end

local function ApplySavedPosition()
    if savedPositions["equipWindow"] then
        local uiScale = GetUIScaleFactor()
        local scaledX = savedPositions["equipWindow"].x / uiScale
        local scaledY = savedPositions["equipWindow"].y / uiScale
        equipWindow:RemoveAllAnchors()
        equipWindow:AddAnchor("TOPLEFT", "UIParent", scaledX, scaledY)
    end
end

local function EnteredWorld()
    LoadConfig()
    LoadSavedPositions()
    CreateEquipWindow()
    SetupEscMenuButton()

    RegisterAllHotkeys()

    local buttonCount = 0
    for _, set in ipairs(config) do
        if set.Char == X2Unit:UnitName("player") then
            buttonCount = buttonCount + 1
        end
    end

    local cols = math.min(buttonCount, buttonsPerRow)
    local rows = math.ceil(buttonCount / buttonsPerRow)
    local totalWidth = (cols * buttonSpacing) - (buttonSpacing - buttonSize) + 2 * windowPadding
    local totalHeight = (rows * buttonSpacing) - (buttonSpacing - buttonSize) + 2 * windowPadding
    equipWindow:SetExtent(totalWidth, totalHeight)

    local buttonIndex = 1
    for i = 1, #config do
        local set = config[i]
        if set.Char == X2Unit:UnitName("player") then
            CreateButton(set, buttonIndex)
            buttonIndex = buttonIndex + 1
        end
    end

    ApplySavedPosition()
end

UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)

equipWindow:SetHandler("OnEvent", function(self, event, ...)
    if event == "HOTKEY_ACTION" then
        OnHotkeyAction(...)
    end
end)
equipWindow:RegisterEvent("HOTKEY_ACTION")

function equipWindow:OnUpdate(dt)
    if #gear_to_process > 0 then
        if delay >= cooldown then
            local item_to_equip = table.remove(gear_to_process, 1)
            if #gear_to_process == 0 then
                for i = 1, #buttons do
                    local button = buttons[i]
                    button:Enable(true)
                end
            end
            local gearItem = item_to_equip.gear_item
            X2Bag:EquipBagItem(item_to_equip.pos, ComputeAlternative(gearItem))
            delay = 0
        end
    end
    if delay < cooldown then
        delay = delay + 1
    end
end

equipWindow:SetHandler("OnUpdate", equipWindow.OnUpdate)