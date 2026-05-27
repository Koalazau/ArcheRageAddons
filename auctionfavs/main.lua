if API_TYPE == nil then
    ADDON:ImportAPI(8)
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "[TestAddon] Globals folder not found. Please install it.")
    return
end

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.AUCTION.id)
ADDON:ImportAPI(API_TYPE.HOTKEY.id)

ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.THREE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.SLIDER)
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX_MULTILINE)
ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)

local UIC_AUCTION      = 58
local LISTENER_ACTION  = "auctionfavs_listener"
local POS_SAVE_KEY     = "panelPos"
local FAV_SAVE_KEY     = "favorites"
local FAV_FILE_PATH    = "../Documents/Addon/auctionfavs/favorites.txt"
local DEFAULT_X        = 400
local DEFAULT_Y        = 300

local PANEL_WIDTH      = 300
local TITLE_Y          = 28
local LIST_TOP_Y       = 56
local LIST_PAD_X       = 10
local ROW_HEIGHT       = 26
local VISIBLE_ROWS     = 10
local SLIDER_W         = 18
local ROW_GAP          = 2
local DELETE_RESERVE   = 24
local PANEL_HEIGHT     = LIST_TOP_Y + VISIBLE_ROWS * ROW_HEIGHT + 64

local ROW_TEXT_DEFAULT = { 0.88, 0.88, 0.88, 1.0 }
local ROW_TEXT_HOVER   = { 0.45, 1.00, 0.45, 1.0 }

local function trim(s)
    return (s or ""):gsub("\n", ""):match("^%s*(.-)%s*$") or ""
end

local function GetUIScaleFactor()
    return UIParent:GetUIScale() or 1.0
end

local favorites = {}

local function SaveFavorites()
    ADDON:SaveData(FAV_SAVE_KEY, favorites)
    local f = io.open(FAV_FILE_PATH, "w")
    if f then
        for _, fav in ipairs(favorites) do
            if fav.text and fav.text ~= "" then
                f:write(fav.text .. "\n")
            end
        end
        f:close()
    end
end

local function LoadFavorites()
    local f = io.open(FAV_FILE_PATH, "r")
    if f then
        favorites = {}
        for line in f:lines() do
            local clean = trim(line)
            if clean ~= "" then
                table.insert(favorites, { text = clean })
            end
        end
        f:close()
        return
    end
    favorites = ADDON:LoadData(FAV_SAVE_KEY) or {}
end

LoadFavorites()

local bagPanel = CreateEmptyWindow("auctionfavspanel", "UIParent")
bagPanel:SetExtent(PANEL_WIDTH, PANEL_HEIGHT)
bagPanel:Clickable(true)
bagPanel:SetCloseOnEscape(true)
bagPanel:Show(false)

local savedPos   = ADDON:LoadData(POS_SAVE_KEY) or {}
local savedPhysX = tonumber(savedPos.x) or DEFAULT_X
local savedPhysY = tonumber(savedPos.y) or DEFAULT_Y

local function ApplyPanelAnchor()
    local scale = GetUIScaleFactor()
    bagPanel:RemoveAllAnchors()
    bagPanel:AddAnchor("TOPLEFT", "UIParent", savedPhysX / scale, savedPhysY / scale)
end

ApplyPanelAnchor()

bagPanel:EnableDrag(true)
bagPanel:SetHandler("OnDragStart", function(self)
    self:StartMoving()
end)
bagPanel:SetHandler("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local lx, ly = self:GetOffset()
    local scale = GetUIScaleFactor()
    savedPhysX, savedPhysY = lx * scale, ly * scale
    ADDON:SaveData(POS_SAVE_KEY, { x = savedPhysX, y = savedPhysY })
end)

local background = bagPanel:CreateDrawable("ui/common/default.dds", "main_bg", "background")
background:AddAnchor("TOPLEFT", bagPanel, -5, -5)
background:AddAnchor("BOTTOMRIGHT", bagPanel, 5, 5)

local decoration = bagPanel:CreateDrawable("ui/common/default.dds", "main_bg_deco", "background")
decoration:AddAnchor("TOPLEFT", bagPanel, 0, -5)
decoration:AddAnchor("TOPRIGHT", bagPanel, 0, -5)

local closeBtn = bagPanel:CreateChildWidget("button", "closeBtn", 0, true)
closeBtn:AddAnchor("TOPRIGHT", bagPanel, -2, 2)
closeBtn:SetStyle("btn_close_default")
closeBtn:Show(true)

local titleBar = bagPanel:CreateChildWidget("window", "titleBar", 0, true)
titleBar:AddAnchor("TOPLEFT",  bagPanel, 0, TITLE_Y - 14)
titleBar:AddAnchor("TOPRIGHT", bagPanel, 0, TITLE_Y - 14)
titleBar:SetHeight(28)
titleBar.titleStyle:SetAlign(ALIGN_CENTER)
titleBar.titleStyle:SetFontSize(15)
titleBar.titleStyle:SetColor(1.0, 0.95, 0.7, 1.0)
titleBar:SetTitleText("Auction Favorites")
titleBar:Show(true)

local LIST_BOTTOM_OFFSET = PANEL_HEIGHT - (LIST_TOP_Y + VISIBLE_ROWS * ROW_HEIGHT + 4)
local listBg = bagPanel:CreateDrawable("ui/common/default.dds", "window_color_texture_bg", "background")
listBg:AddAnchor("TOPLEFT",     bagPanel,  LIST_PAD_X - 4,            LIST_TOP_Y - 4)
listBg:AddAnchor("BOTTOMRIGHT", bagPanel, -(LIST_PAD_X + SLIDER_W),  -LIST_BOTTOM_OFFSET)
listBg:Show(true)

local rowWidth = PANEL_WIDTH - LIST_PAD_X * 2 - SLIDER_W - 4
local clickW   = rowWidth - DELETE_RESERVE
local rows     = {}

for i = 1, VISIBLE_ROWS do
    local rowY = LIST_TOP_Y + (i - 1) * ROW_HEIGHT

    local row = bagPanel:CreateChildWidget("window", "favRow_" .. i, 0, true)
    row:SetExtent(rowWidth, ROW_HEIGHT - ROW_GAP)
    row:AddAnchor("TOPLEFT", bagPanel, LIST_PAD_X, rowY)
    row:Show(false)

    local label = row:CreateChildWidget("label", "favLabel_" .. i, 0, true)
    label:SetExtent(clickW, ROW_HEIGHT - ROW_GAP)
    label:AddAnchor("TOPLEFT", row, 4, 0)
    label.style:SetFontSize(12)
    label.style:SetColor(unpack(ROW_TEXT_DEFAULT))
    label.style:SetAlign(ALIGN_LEFT)
    label:SetAutoResize(false)
    label:SetText("")
    label:Show(true)

    local clickArea = row:CreateChildWidget("button", "favClick_" .. i, 0, true)
    clickArea:SetExtent(clickW, ROW_HEIGHT - ROW_GAP)
    clickArea:AddAnchor("TOPLEFT", row, 0, 0)
    clickArea:Show(true)

    local delBtn = row:CreateChildWidget("button", "favDel_" .. i, 0, true)
    delBtn:AddAnchor("RIGHT", row, 0, 0)
    delBtn:SetStyle("btn_close_default")
    delBtn:Show(true)

    rows[i] = { row = row, label = label, clickArea = clickArea, delBtn = delBtn }
end

local scrollOffset = 0
local listAreaH    = VISIBLE_ROWS * ROW_HEIGHT

local sliderFrame = bagPanel:CreateChildWidget("emptywidget", "favSliderFrame", 0, true)
sliderFrame:SetExtent(SLIDER_W, listAreaH)
sliderFrame:AddAnchor("TOPRIGHT", bagPanel, -LIST_PAD_X, LIST_TOP_Y)

local upButton = sliderFrame:CreateChildWidget("button", "favUpBtn", 0, true)
upButton:SetExtent(SLIDER_W, 12)
upButton:AddAnchor("TOPRIGHT", sliderFrame, 0, 0)
upButton:SetStyle("slider_scroll_button_up")

local downButton = sliderFrame:CreateChildWidget("button", "favDownBtn", 0, true)
downButton:SetExtent(SLIDER_W, 12)
downButton:AddAnchor("BOTTOMRIGHT", sliderFrame, 0, 0)
downButton:SetStyle("slider_scroll_button_down")

local slider = sliderFrame:CreateChildWidget("slider", "favSlider", 0, true)
slider:AddAnchor("TOPLEFT",     upButton,   "BOTTOMLEFT", 0, 0)
slider:AddAnchor("BOTTOMRIGHT", downButton, "TOPRIGHT",   0, 0)
slider:SetOrientation(0)

local sliderBg = slider:CreateDrawable("ui/button/scroll_button.dds", "scroll_frame_bg", "background")
sliderBg:SetTextureColor("default")
sliderBg:AddAnchor("TOPLEFT",     slider,  3, -9)
sliderBg:AddAnchor("BOTTOMRIGHT", slider, -3,  9)

local thumb = slider:CreateChildWidget("button", "favSliderThumb", 0, true)
thumb:EnableDrag(true)
thumb:SetWidth(SLIDER_W)

local thumbNormal = thumb:CreateDrawable("ui/button/scroll_button.dds", "thumb_df", "background")
thumbNormal:AddAnchor("TOPLEFT",     thumb, 0, 0)
thumbNormal:AddAnchor("BOTTOMRIGHT", thumb, 0, 0)
thumb:SetNormalBackground(thumbNormal)

local thumbHi = thumb:CreateDrawable("ui/button/scroll_button.dds", "thumb_ov", "background")
thumbHi:AddAnchor("TOPLEFT",     thumb, 0, 0)
thumbHi:AddAnchor("BOTTOMRIGHT", thumb, 0, 0)
thumb:SetHighlightBackground(thumbHi)

local thumbPushed = thumb:CreateDrawable("ui/button/scroll_button.dds", "thumb_on", "background")
thumbPushed:AddAnchor("TOPLEFT",     thumb, 0, 0)
thumbPushed:AddAnchor("BOTTOMRIGHT", thumb, 0, 0)
thumb:SetPushedBackground(thumbPushed)

slider:SetThumbButtonWidget(thumb)
slider:SetMinMaxValues(0, 0)
slider:SetValueStep(1)
slider:SetValue(0, false)

local function DoSearch(keyword)
    keyword = trim(keyword)
    if keyword == "" then return end
    X2Auction:SearchAuctionArticle(1, 0, 55, 1, 0, false, keyword, "0", "99999999999")
end

local function RenderList(syncSlider)
    if syncSlider == nil then syncSlider = true end

    local maxOffset = math.max(0, #favorites - VISIBLE_ROWS)
    if scrollOffset > maxOffset then scrollOffset = maxOffset end
    if scrollOffset < 0           then scrollOffset = 0         end

    if syncSlider then
        slider:SetMinMaxValues(0, maxOffset)
        slider:SetValue(scrollOffset, false)
    end

    sliderFrame:Show(maxOffset > 0)

    for i = 1, VISIBLE_ROWS do
        local fav = favorites[i + scrollOffset]
        local r   = rows[i]
        if fav then
            r.label:SetText(fav.text)
            r.label.style:SetColor(unpack(ROW_TEXT_DEFAULT))
            r.row:Show(true)

            local idx = i + scrollOffset
            r.clickArea:SetHandler("OnClick", function()
                DoSearch(favorites[idx] and favorites[idx].text or "")
            end)
            r.clickArea:SetHandler("OnEnter", function()
                r.label.style:SetColor(unpack(ROW_TEXT_HOVER))
            end)
            r.clickArea:SetHandler("OnLeave", function()
                r.label.style:SetColor(unpack(ROW_TEXT_DEFAULT))
            end)
            r.delBtn:SetHandler("OnClick", function()
                table.remove(favorites, idx)
                SaveFavorites()
                RenderList(true)
            end)
        else
            r.label:SetText("")
            r.row:Show(false)
        end
    end
end

slider:SetHandler("OnSliderChanged", function(self, value)
    scrollOffset = math.floor(value or 0)
    RenderList(false)
end)

upButton:SetHandler("OnClick", function()
    if scrollOffset > 0 then
        scrollOffset = scrollOffset - 1
        RenderList(true)
    end
end)

downButton:SetHandler("OnClick", function()
    local maxOffset = math.max(0, #favorites - VISIBLE_ROWS)
    if scrollOffset < maxOffset then
        scrollOffset = scrollOffset + 1
        RenderList(true)
    end
end)

bagPanel:SetHandler("OnWheelUp", function()
    if scrollOffset > 0 then
        scrollOffset = scrollOffset - 1
        RenderList(true)
    end
end)

bagPanel:SetHandler("OnWheelDown", function()
    local maxOffset = math.max(0, #favorites - VISIBLE_ROWS)
    if scrollOffset < maxOffset then
        scrollOffset = scrollOffset + 1
        RenderList(true)
    end
end)

local addPopup

local function ShowAddPopup()
    if addPopup then
        addPopup.input:SetText("")
        addPopup:Show(true)
        return
    end

    addPopup = CreateEmptyWindow("auctionfavsaddpopup", "UIParent")
    addPopup:SetExtent(320, 140)
    addPopup:AddAnchor("CENTER", "UIParent", 0, 0)
    addPopup:SetCloseOnEscape(true)
    addPopup:Clickable(true)
    addPopup:EnableDrag(true)
    addPopup:SetHandler("OnDragStart", function(self) self:StartMoving() end)
    addPopup:SetHandler("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    local popBg = addPopup:CreateDrawable("ui/common/default.dds", "main_bg", "background")
    popBg:AddAnchor("TOPLEFT",     addPopup, -5, -5)
    popBg:AddAnchor("BOTTOMRIGHT", addPopup,  5,  5)

    local popDeco = addPopup:CreateDrawable("ui/common/default.dds", "main_bg_deco", "background")
    popDeco:AddAnchor("TOPLEFT",  addPopup, 0, -5)
    popDeco:AddAnchor("TOPRIGHT", addPopup, 0, -5)

    local title = addPopup:CreateChildWidget("label", "popTitle", 0, true)
    title.style:SetFontSize(14)
    title.style:SetColor(1, 0.95, 0.7, 1)
    title.style:SetOutline(true)
    title.style:SetAlign(ALIGN_CENTER)
    title:SetExtent(280, 20)
    title:AddAnchor("TOP", addPopup, 0, 14)
    title:SetText("Add Favorite Search")

    local input = addPopup:CreateChildWidget("editboxmultiline", "popInput", 0, true)
    input:SetExtent(260, 28)
    input:AddAnchor("CENTER", addPopup, 0, 0)
    input.style:SetFontSize(14)
    input:SetMaxTextLength(64)
    addPopup.input = input

    local inputBg = addPopup:CreateColorDrawable(1, 1, 1, 0.35, "background")
    inputBg:AddAnchor("TOPLEFT",     input, -4, -4)
    inputBg:AddAnchor("BOTTOMRIGHT", input,  4,  4)

    local saveBtn = addPopup:CreateChildWidget("button", "popSave", 0, true)
    saveBtn:SetText("Save")
    saveBtn:SetStyle("text_default")
    saveBtn:SetExtent(90, 28)
    saveBtn:AddAnchor("BOTTOMLEFT", addPopup, 30, -16)
    saveBtn:SetHandler("OnClick", function()
        local clean = trim(input:GetText())
        if clean ~= "" then
            table.insert(favorites, { text = clean })
            SaveFavorites()
            RenderList(true)
            addPopup:Show(false)
        end
    end)

    local cancelBtn = addPopup:CreateChildWidget("button", "popCancel", 0, true)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetStyle("text_default")
    cancelBtn:SetExtent(90, 28)
    cancelBtn:AddAnchor("BOTTOMRIGHT", addPopup, -30, -16)
    cancelBtn:SetHandler("OnClick", function() addPopup:Show(false) end)

    addPopup:Show(true)
end

local addBtn = bagPanel:CreateChildWidget("button", "favAddBtn", 0, true)
addBtn:SetExtent(140, 28)
addBtn:AddAnchor("BOTTOM", bagPanel, 0, -14)
addBtn:SetText("+ Add Favorite")
addBtn:SetStyle("text_default")
addBtn.style:SetFontSize(12)
addBtn:SetHandler("OnClick", ShowAddPopup)
addBtn:Show(true)

RenderList(true)

local panelVisible   = false
local closeJustFired = false

local function ShowPanel()
    if not panelVisible then
        bagPanel:Show(true)
        ApplyPanelAnchor()
        RenderList(true)
        panelVisible = true
    end
end

local function HidePanel()
    if panelVisible then
        bagPanel:Show(false)
        panelVisible = false
    end
end

closeBtn:SetHandler("OnClick", HidePanel)
bagPanel:SetHandler("OnCloseByEsc", function()
    panelVisible = false
end)

local AUCTION_EVENTS = {
    "AUCTION_ITEM_SEARCH",
    "AUCTION_ITEM_SEARCHED",
    "AUCTION_ITEM_PUT_UP",
    "AUCTION_BIDDED",
    "AUCTION_BIDDEN",
    "AUCTION_BOUGHT",
    "AUCTION_BOUGHT_BY_SOMEONE",
    "AUCTION_CANCELED",
    "AUCTION_LOWEST_PRICE",
    "AUCTION_PERMISSION_BY_CRAFT",
    "AUCTION_CHARACTER_LEVEL_TOO_LOW",
}
for _, ev in ipairs(AUCTION_EVENTS) do
    UIParent:SetEventHandler(ev, ShowPanel)
end

UIParent:SetEventHandler("AUCTION_ITEM_ATTACHMENT_STATE_CHANGED", function(attached)
    if attached then
        ShowPanel()
    else
        closeJustFired = true
        HidePanel()
    end
end)

local installedKey

local function FindAuctionKey()
    local k = X2Hotkey:GetBindingUiEvent("toggle_auction", 1)
    if k and k ~= "" then return k end
    k = X2Hotkey:GetBindingUiEvent(LISTENER_ACTION, 1)
    if k and k ~= "" then return k end
    return nil
end

local function InstallHotkeyMirror()
    local key = FindAuctionKey()
    if not key or installedKey == key then return end
    X2Hotkey:SetBindingUiEvent(LISTENER_ACTION, key)
    installedKey = key
end

InstallHotkeyMirror()

UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, function()
    InstallHotkeyMirror()
    ApplyPanelAnchor()
end)

bagPanel:SetHandler("OnEvent", function(self, event, actionName, keyUp)
    if event ~= "HOTKEY_ACTION" then return end
    if keyUp                    then return end
    if actionName ~= LISTENER_ACTION then return end

    closeJustFired = false
    ADDON:ToggleContent(UIC_AUCTION)

    if closeJustFired then
        closeJustFired = false
    else
        ShowPanel()
    end
end)
bagPanel:RegisterEvent("HOTKEY_ACTION")
