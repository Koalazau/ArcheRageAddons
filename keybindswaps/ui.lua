-- keybindswaps/ui.lua
-- Config editor window: view, create, edit, and delete keybind swap profiles.
-- Registered to the ESC menu under System tab.

ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COMBOBOX)
ADDON:ImportObject(OBJECT_TYPE.LISTBOX)

-- ─── Layout constants ─────────────────────────────────────────────────────────

local WIN_W         = 520
local WIN_H         = 400
local PANEL_LEFT_X  = 10
local PANEL_LEFT_W  = 150
local PANEL_RIGHT_X = 175
local PANEL_RIGHT_W = 330
local ROW_H         = 30
local MAX_ROWS      = 8    -- visible rows per page
local MAX_PROFILES  = 24   -- 3 pages × 8
local LABEL_COL_W   = 100
local FIELD_COL_W   = 180
local FIELD_H       = 18
local BTN_H         = 25
local BTN_W         = 80

-- ─── State ────────────────────────────────────────────────────────────────────

local selectedIndex = nil  -- 1-based index into KeybindSwaps.profiles, or nil
local enabledToggle = true -- mirrors the "Enabled" toggle state while editing
local currentPage   = 1    -- which page of the profile list is visible
local rowProfileMap = {}   -- rowProfileMap[i] = profile index shown in row i this render

-- ─── Helper: title bar ────────────────────────────────────────────────────────

-- Creates a coloured title bar, a divider line, and a draggable label on `window`.
-- The label drives window movement via StartMoving/StopMovingOrSizing.
-- Creates a title bar (bg, divider, label) on `window` and returns the label.
-- Drag setup is left to the caller — attach OnDragStart/OnDragStop as needed.
local function MakeTitleBar(window, id, title, w)
    local titleBg = window:CreateColorDrawable(0.12, 0.12, 0.20, 1.0, "background")
    titleBg:SetExtent(w, 28)
    titleBg:AddAnchor("TOPLEFT", window, 0, 0)
    titleBg:Show(true)

    local divider = window:CreateColorDrawable(0.25, 0.35, 0.55, 1.0, "background")
    divider:SetExtent(w, 1)
    divider:AddAnchor("TOPLEFT", window, 0, 28)
    divider:Show(true)

    local lbl = window:CreateChildWidget("label", id, 0, true)
    lbl.style:SetFontSize(13)
    lbl.style:SetColor(0.8, 0.9, 1.0, 1)
    lbl.style:SetOutline(true)
    lbl.style:SetAlign(ALIGN_LEFT)
    lbl:SetExtent(w - 20, 24)
    lbl:AddAnchor("TOPLEFT", window, 10, 4)
    lbl:SetText(title)
    lbl:Show(true)
    return lbl
end

-- ─── Helper: label ────────────────────────────────────────────────────────────

local function MakeLabel(parent, id, text, fontSize, x, y, w, h)
    local lbl = parent:CreateChildWidget("label", id, 0, true)
    lbl.style:SetFontSize(fontSize or 12)
    lbl.style:SetColor(1, 1, 1, 1)
    lbl.style:SetOutline(true)
    lbl.style:SetAlign(ALIGN_LEFT)
    lbl:SetExtent(w or 200, h or 18)
    lbl:AddAnchor("TOPLEFT", parent, x or 0, y or 0)
    if text then lbl:SetText(text) end
    lbl:Show(true)
    return lbl
end

-- ─── Helper: editbox ──────────────────────────────────────────────────────────

local function MakeEditbox(parent, id, x, y, w, h)
    local W = w or FIELD_COL_W
    local H = h or FIELD_H

    local bg = parent:CreateColorDrawable(0.12, 0.12, 0.18, 1.0, "background")
    bg:SetExtent(W + 4, H + 4)
    bg:AddAnchor("TOPLEFT", parent, x - 2, y - 2)
    bg:Show(true)

    local eb = parent:CreateChildWidget("x2editbox", id, 0, true)
    eb:SetExtent(W, H)
    eb:AddAnchor("TOPLEFT", parent, x, y)
    eb:SetText("")
    eb.style:SetColor(1, 1, 1, 1)
    eb:SetCursorColor(0.6, 0.6, 0.6, 1)
    eb:Show(true)
    return eb
end

-- ─── Helper: combobox ─────────────────────────────────────────────────────────

local MOD_W = 110
local KEY_W = 95

local MOD_ITEMS = (function()
    local t = { "(none)", "CTRL", "SHIFT", "ALT", "CTRL-SHIFT", "CTRL-ALT", "SHIFT-ALT" }
    local items = {}
    for i, v in ipairs(t) do items[i] = { text = v, value = i } end
    return items
end)()

local BASE_KEY_ITEMS = (function()
    local items, idx = {}, 1
    items[#items+1] = { text = "(none)", value = idx }; idx = idx+1
    for i = 0, 28 do items[#items+1] = { text = string.char(65+i), value = idx }; idx = idx+1 end
    for _, k in ipairs({ "TILDA","1","2","3","4","5","6","7","8","9","0","MINUS","EQUALS","SPACE" }) do
        items[#items+1] = { text = k, value = idx }; idx = idx+1
    end
    for _, k in ipairs({ "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12" }) do
        items[#items+1] = { text = k, value = idx }; idx = idx+1
    end
    return items
end)()

local function MakeCombobox(parent, id, x, y, w, items)
    local bg = parent:CreateColorDrawable(0.12, 0.12, 0.18, 1.0, "background")
    bg:SetExtent(w + 4, FIELD_H + 12)
    bg:AddAnchor("TOPLEFT", parent, x - 2, y - 2)
    bg:Show(true)

    local cb = parent:CreateChildWidget("combobox", id, 0, true)
    cb:SetExtent(w, FIELD_H + 8)
    cb:AddAnchor("TOPLEFT", parent, x, y)
    cb:SetEditable(false)
    cb:SetDropdownVisibleLimit(10)
    cb:Insert(items)

    local dropBg = cb.dropdown:CreateColorDrawable(0.08, 0.08, 0.14, 0.97, "background")
    dropBg:AddAnchor("TOPLEFT",     cb.dropdown, 0, 0)
    dropBg:AddAnchor("BOTTOMRIGHT", cb.dropdown, 0, 0)

    cb.dropdown:SetDefaultItemTextColor(0.85, 0.85, 0.85, 1)
    cb.dropdown:SetSelectedItemColor(0.20, 0.35, 0.65, 0.5)
    cb.dropdown:SetSelectedItemTextColor(1, 1, 1, 1)
    cb.dropdown:SetOveredItemColor(0.15, 0.25, 0.45, 0.3)
    cb.dropdown:SetHandler("OnWheelUp",   function(self) self:ScrollUp()  end)
    cb.dropdown:SetHandler("OnWheelDown", function(self) self:ScrollDown() end)

    cb:Show(true)
    return cb
end

-- ─── Key helpers ──────────────────────────────────────────────────────────────

-- Splits a full key string (e.g. "CTRL-MINUS") into modifier + base key.
local function ParseKey(fullKey)
    if not fullKey or fullKey == "" then return "(none)", "" end
    for _, mod in ipairs({ "CTRL-SHIFT", "CTRL-ALT", "SHIFT-ALT", "CTRL", "SHIFT", "ALT" }) do
        if string.sub(fullKey, 1, #mod + 1) == mod .. "-" then
            return mod, string.sub(fullKey, #mod + 2)
        end
    end
    return "(none)", fullKey
end

-- Combines modifier + base key into a single key string.
-- Returns "" if no key is selected.
local function CombineKey(mod, key)
    if key == "" or key == "(none)" then return "" end
    if mod == "" or mod == "(none)" then return key end
    return mod .. "-" .. key
end

-- Sets a combobox selection by matching item text.
-- Must drive both selectorBtn (display) and dropdown (internal state) because
-- the engine's combobox uses 0-indexed dropdown:Select(i-1, false).
local function SetComboboxByText(cb, items, targetText)
    if targetText and targetText ~= "" then
        for i, item in ipairs(items) do
            if item.text == targetText then
                cb.selectorBtn:SetText(item.text)
                cb.dropdown:Select(i - 1, false)
                return
            end
        end
    end
    cb.selectorBtn:SetText("")
    cb.dropdown:Select(-1, false)
end

-- ─── Main window ──────────────────────────────────────────────────────────────

local win = CreateEmptyWindow("ksConfigWindow", "UIParent")
win:SetExtent(WIN_W, WIN_H)
win:AddAnchor("CENTER", "UIParent", 0, 0)
win:Clickable(true)
win:Show(false)
win:SetCloseOnEscape(true)

local winBg = win:CreateColorDrawable(0.08, 0.08, 0.12, 0.95, "background")
winBg:SetExtent(WIN_W, WIN_H)
winBg:AddAnchor("TOPLEFT", win, 0, 0)
winBg:Show(true)

local titleLbl = MakeTitleBar(win, "ksTitleLbl", "KeybindSwaps - Profile Manager", WIN_W)
titleLbl:Clickable(true)
titleLbl:EnableDrag(true)
titleLbl:SetHandler("OnDragStart", function(self) win:StartMoving(); return true end)
titleLbl:SetHandler("OnDragStop",  function(self) win:StopMovingOrSizing() end)

local panelDiv = win:CreateColorDrawable(0.22, 0.22, 0.32, 1.0, "background")
panelDiv:SetExtent(1, WIN_H - 30 - 40)
panelDiv:AddAnchor("TOPLEFT", win, PANEL_RIGHT_X - 8, 35)
panelDiv:Show(true)

-- ─── Left panel: profile list ─────────────────────────────────────────────────

MakeLabel(win, "ksListHdr", "Profiles", 12, PANEL_LEFT_X, 33, PANEL_LEFT_W, 18)

local rowHighlight = win:CreateColorDrawable(0.20, 0.35, 0.65, 0.50, "background")
rowHighlight:SetExtent(PANEL_LEFT_W, ROW_H - 2)
rowHighlight:AddAnchor("TOPLEFT", win, PANEL_LEFT_X, 52)
rowHighlight:Show(false)

local rowLabels = {}
for i = 1, MAX_ROWS do
    local yOff = 52 + (i - 1) * ROW_H

    local rowBg = win:CreateColorDrawable(0.13, 0.13, 0.18, 0.0, "background")
    rowBg:SetExtent(PANEL_LEFT_W, ROW_H - 2)
    rowBg:AddAnchor("TOPLEFT", win, PANEL_LEFT_X, yOff)
    rowBg:Show(true)

    local lbl = win:CreateChildWidget("label", "ksRow" .. i, 0, true)
    lbl.style:SetFontSize(11)
    lbl.style:SetColor(0.85, 0.85, 0.85, 1)
    lbl.style:SetOutline(false)
    lbl.style:SetAlign(ALIGN_LEFT)
    lbl:SetExtent(PANEL_LEFT_W - 4, ROW_H - 4)
    lbl:AddAnchor("TOPLEFT", win, PANEL_LEFT_X + 4, yOff + 4)
    lbl:SetText("")
    lbl:Show(true)

    rowLabels[i] = { label = lbl, bg = rowBg, y = yOff }
end

-- ─── Page navigation (below profile list) ─────────────────────────────────────

local LIST_BOTTOM = 52 + MAX_ROWS * ROW_H

local prevPageBtn = win:CreateChildWidget("button", "ksPrevPageBtn", 0, true)
prevPageBtn:SetExtent(25, BTN_H)
prevPageBtn:AddAnchor("TOPLEFT", win, PANEL_LEFT_X, LIST_BOTTOM + 3)
prevPageBtn:SetText("<")
prevPageBtn:Show(false)

local pageLbl = win:CreateChildWidget("label", "ksPageLbl", 0, true)
pageLbl.style:SetFontSize(10)
pageLbl.style:SetColor(0.7, 0.7, 0.7, 1)
pageLbl.style:SetOutline(false)
pageLbl.style:SetAlign(ALIGN_CENTER)
pageLbl:SetExtent(PANEL_LEFT_W - 50, BTN_H)
pageLbl:AddAnchor("TOPLEFT", win, PANEL_LEFT_X + 25, LIST_BOTTOM + 3)
pageLbl:SetText("")
pageLbl:Show(false)

local nextPageBtn = win:CreateChildWidget("button", "ksNextPageBtn", 0, true)
nextPageBtn:SetExtent(25, BTN_H)
nextPageBtn:AddAnchor("TOPLEFT", win, PANEL_LEFT_X + PANEL_LEFT_W - 25, LIST_BOTTOM + 3)
nextPageBtn:SetText(">")
nextPageBtn:Show(false)

-- ─── Left panel bottom buttons ────────────────────────────────────────────────

local newBtn = win:CreateChildWidget("button", "ksNewBtn", 0, true)
newBtn:SetExtent(BTN_W, BTN_H)
newBtn:AddAnchor("BOTTOMLEFT", win, PANEL_LEFT_X, -10)
newBtn:SetText("New")
newBtn:Show(true)

local toggleAllBtn = win:CreateChildWidget("button", "ksToggleAllBtn", 0, true)
toggleAllBtn:SetExtent(PANEL_LEFT_W, BTN_H)
toggleAllBtn:AddAnchor("BOTTOMLEFT", win, PANEL_LEFT_X, -(10 + BTN_H + 5))
toggleAllBtn:SetText("Enable All")
toggleAllBtn:Show(true)

-- ─── Right panel: edit form ───────────────────────────────────────────────────

local FORM_TOP = 50
local FORM_GAP = 34
local LABEL_X  = PANEL_RIGHT_X
local FIELD_X  = PANEL_RIGHT_X + LABEL_COL_W + 5

MakeLabel(win, "ksFormHdr", "Edit Profile", 12, PANEL_RIGHT_X, 33, PANEL_RIGHT_W, 18)

MakeLabel(win, "ksLblName",    "Name:",        11, LABEL_X, FORM_TOP,              LABEL_COL_W, FIELD_H)
MakeLabel(win, "ksLblBuffId",  "Buff ID:",     11, LABEL_X, FORM_TOP + FORM_GAP,   LABEL_COL_W, FIELD_H)
MakeLabel(win, "ksLblSlot",    "Slot (1-8):",  11, LABEL_X, FORM_TOP + FORM_GAP*2, LABEL_COL_W, FIELD_H)
MakeLabel(win, "ksLblSwapKey", "Swap Key:",    11, LABEL_X, FORM_TOP + FORM_GAP*3, LABEL_COL_W, FIELD_H)
MakeLabel(win, "ksLblDefKey",  "Default Key:", 11, LABEL_X, FORM_TOP + FORM_GAP*4, LABEL_COL_W, FIELD_H)
MakeLabel(win, "ksLblEnabled", "Enabled:",     11, LABEL_X, FORM_TOP + FORM_GAP*5, LABEL_COL_W, FIELD_H)

local ebName   = MakeEditbox(win, "ksEbName",   FIELD_X, FORM_TOP              - 2, FIELD_COL_W, FIELD_H)
local ebBuffId = MakeEditbox(win, "ksEbBuffId", FIELD_X, FORM_TOP + FORM_GAP   - 2, FIELD_COL_W, FIELD_H)
local ebSlot   = MakeEditbox(win, "ksEbSlot",   FIELD_X, FORM_TOP + FORM_GAP*2 - 2, FIELD_COL_W, FIELD_H)

local cbSwapMod = MakeCombobox(win, "ksCbSwapMod", FIELD_X,             FORM_TOP + FORM_GAP*3 - 2, MOD_W, MOD_ITEMS)
local cbSwapKey = MakeCombobox(win, "ksCbSwapKey", FIELD_X + MOD_W + 6, FORM_TOP + FORM_GAP*3 - 2, KEY_W, BASE_KEY_ITEMS)
local cbDefMod  = MakeCombobox(win, "ksCbDefMod",  FIELD_X,             FORM_TOP + FORM_GAP*4 - 2, MOD_W, MOD_ITEMS)
local cbDefKey  = MakeCombobox(win, "ksCbDefKey",  FIELD_X + MOD_W + 6, FORM_TOP + FORM_GAP*4 - 2, KEY_W, BASE_KEY_ITEMS)

local toggleBtn = win:CreateChildWidget("button", "ksToggleBtn", 0, true)
toggleBtn:SetExtent(60, BTN_H)
toggleBtn:AddAnchor("TOPLEFT", win, FIELD_X, FORM_TOP + FORM_GAP*5 - 2)
toggleBtn:SetText("Yes")
toggleBtn:Show(true)

-- Default Key warning (shown when Default Key base = "(none)")
local WARN_Y = FORM_TOP + FORM_GAP*5 + BTN_H + 4   -- just below Enabled button

local warnLbl1 = win:CreateChildWidget("label", "ksWarnLbl1", 0, true)
warnLbl1.style:SetFontSize(12)
warnLbl1.style:SetColor(1, 0.65, 0.1, 1)
warnLbl1.style:SetOutline(false)
warnLbl1.style:SetAlign(ALIGN_LEFT)
warnLbl1:SetExtent(PANEL_RIGHT_W, 18)
warnLbl1:AddAnchor("TOPLEFT", win, PANEL_RIGHT_X, WARN_Y)
warnLbl1:SetText("No Default Key: swap key won't clear on revert.")
warnLbl1:Show(false)

local warnLbl2 = win:CreateChildWidget("label", "ksWarnLbl2", 0, true)
warnLbl2.style:SetFontSize(12)
warnLbl2.style:SetColor(1, 0.65, 0.1, 1)
warnLbl2.style:SetOutline(false)
warnLbl2.style:SetAlign(ALIGN_LEFT)
warnLbl2:SetExtent(PANEL_RIGHT_W, 18)
warnLbl2:AddAnchor("TOPLEFT", win, PANEL_RIGHT_X, WARN_Y + 20)
warnLbl2:SetText("Outside glider mode this is harmless.")
warnLbl2:Show(false)

local warnLbl3 = win:CreateChildWidget("label", "ksWarnLbl3", 0, true)
warnLbl3.style:SetFontSize(12)
warnLbl3.style:SetColor(0.9, 0.55, 0.1, 1)
warnLbl3.style:SetOutline(false)
warnLbl3.style:SetAlign(ALIGN_LEFT)
warnLbl3:SetExtent(PANEL_RIGHT_W, 18)
warnLbl3:AddAnchor("TOPLEFT", win, PANEL_RIGHT_X, WARN_Y + 40)
warnLbl3:SetText("Tip: set any unused key (e.g. F12) as Default Key.")
warnLbl3:Show(false)

local hintLbl = win:CreateChildWidget("label", "ksHintLbl", 0, true)
hintLbl.style:SetFontSize(11)
hintLbl.style:SetColor(0.55, 0.55, 0.55, 1)
hintLbl.style:SetOutline(false)
hintLbl.style:SetAlign(ALIGN_LEFT)
hintLbl:SetExtent(PANEL_RIGHT_W, 18)
hintLbl:AddAnchor("TOPLEFT", win, PANEL_RIGHT_X, WARN_Y + 64)
hintLbl:SetText("Select a profile from the list to edit.")
hintLbl:Show(true)

local errorLbl = win:CreateChildWidget("label", "ksErrorLbl", 0, true)
errorLbl.style:SetFontSize(11)
errorLbl.style:SetColor(1, 0.3, 0.3, 1)
errorLbl.style:SetOutline(true)
errorLbl.style:SetAlign(ALIGN_LEFT)
errorLbl:SetExtent(PANEL_RIGHT_W, 18)
errorLbl:AddAnchor("TOPLEFT", win, PANEL_RIGHT_X, WARN_Y + 86)
errorLbl:SetText("")
errorLbl:Show(true)

-- ─── Bottom buttons: Save / Delete ────────────────────────────────────────────

local saveBtn = win:CreateChildWidget("button", "ksSaveBtn", 0, true)
saveBtn:SetExtent(BTN_W, BTN_H)
saveBtn:AddAnchor("BOTTOMLEFT", win, PANEL_RIGHT_X, -10)
saveBtn:SetText("Save")
saveBtn:Show(true)

local deleteBtn = win:CreateChildWidget("button", "ksDeleteBtn", 0, true)
deleteBtn:SetExtent(BTN_W, BTN_H)
deleteBtn:AddAnchor("BOTTOMLEFT", win, PANEL_RIGHT_X + BTN_W + 10, -10)
deleteBtn:SetText("Delete")
deleteBtn:Show(true)

-- ─── Buff Scanner window ──────────────────────────────────────────────────────

local SCAN_W       = 320
local SCAN_H       = 280
local scanWinShown = false

local scanWin = CreateEmptyWindow("ksScanWindow", "UIParent")
scanWin:SetExtent(SCAN_W, SCAN_H)
scanWin:AddAnchor("TOPLEFT", win, "TOPRIGHT", 5, 0)
scanWin:Clickable(true)
scanWin:Show(false)
scanWin:SetCloseOnEscape(true)

local scanBg = scanWin:CreateColorDrawable(0.08, 0.08, 0.12, 0.95, "background")
scanBg:SetExtent(SCAN_W, SCAN_H)
scanBg:AddAnchor("TOPLEFT", scanWin, 0, 0)
scanBg:Show(true)

-- Scan window follows the main window — title is static (not a drag handle)
MakeTitleBar(scanWin, "ksScanTitle", "Buff Scanner", SCAN_W)

local scanStatusLbl = scanWin:CreateChildWidget("label", "ksScanStatus", 0, true)
scanStatusLbl.style:SetFontSize(11)
scanStatusLbl.style:SetColor(0.55, 0.75, 0.55, 1)
scanStatusLbl.style:SetOutline(false)
scanStatusLbl.style:SetAlign(ALIGN_LEFT)
scanStatusLbl:SetExtent(SCAN_W - 16, 16)
scanStatusLbl:AddAnchor("TOPLEFT", scanWin, 8, 32)
scanStatusLbl:SetText("Waiting...")
scanStatusLbl:Show(true)

local scanList = scanWin:CreateChildWidget("listbox", "ksScanList", 0, true)
scanList:SetExtent(SCAN_W - 16, SCAN_H - 82)
scanList:AddAnchor("TOPLEFT", scanWin, 8, 52)
scanList:SetDefaultItemTextColor(0.85, 0.85, 0.85, 1)
scanList:SetSelectedItemColor(0.20, 0.35, 0.65, 0.5)
scanList:SetSelectedItemTextColor(1, 1, 1, 1)
scanList:SetOveredItemColor(0.15, 0.25, 0.45, 0.3)
scanList:SetHandler("OnWheelUp",   function(self) self:ScrollUp()  end)
scanList:SetHandler("OnWheelDown", function(self) self:ScrollDown() end)
scanList:Show(true)

local scanClearBtn = scanWin:CreateChildWidget("button", "ksScanClearBtn", 0, true)
scanClearBtn:SetExtent(BTN_W, BTN_H)
scanClearBtn:AddAnchor("BOTTOMLEFT", scanWin, 8, -8)
scanClearBtn:SetText("Reset")
scanClearBtn:Show(true)

local scanOpenBtn = win:CreateChildWidget("button", "ksScanOpenBtn", 0, true)
scanOpenBtn:SetExtent(55, BTN_H)
scanOpenBtn:AddAnchor("TOPLEFT", win, FIELD_X + FIELD_COL_W + 8, FORM_TOP + FORM_GAP - 2)
scanOpenBtn:SetText("Scan")
scanOpenBtn:Show(true)

-- ─── Functions ────────────────────────────────────────────────────────────────

local function UpdateDefaultKeyWarning()
    local key = cbDefKey.selectorBtn:GetText()
    local show = selectedIndex ~= nil and (key == "" or key == "(none)")
    warnLbl1:Show(show)
    warnLbl2:Show(show)
    warnLbl3:Show(show)
end

local function ApplyToggleColor(enabled)
    toggleBtn:SetText(enabled and "Yes" or "No")
    toggleBtn.style:SetColor(enabled and 0.3 or 1.0,
                             enabled and 1.0 or 0.3,
                             0.3, 1)
end

local function ShowError(msg)
    errorLbl:SetText(msg or "")
end

local function UpdateToggleAllBtn()
    for _, p in ipairs(KeybindSwaps.profiles) do
        if not p.enabled then
            toggleAllBtn:SetText("Enable All")
            return
        end
    end
    toggleAllBtn:SetText("Disable All")
end

local function ClearForm()
    ebName:SetText("")
    ebBuffId:SetText("")
    ebSlot:SetText("")
    SetComboboxByText(cbSwapMod, MOD_ITEMS,     "")
    SetComboboxByText(cbSwapKey, BASE_KEY_ITEMS, "")
    SetComboboxByText(cbDefMod,  MOD_ITEMS,     "")
    SetComboboxByText(cbDefKey,  BASE_KEY_ITEMS, "")
    enabledToggle = true
    ApplyToggleColor(true)
    ShowError("")
    UpdateDefaultKeyWarning()
end

local function PopulateForm(profile)
    ebName:SetText(profile.name or "")
    ebBuffId:SetText(tostring(profile.buffId or 0))
    ebSlot:SetText(tostring(profile.slot or 1))

    local swapMod, swapBase = ParseKey(profile.swapKey or "")
    SetComboboxByText(cbSwapMod, MOD_ITEMS,      swapMod == "(none)" and "" or swapMod)
    SetComboboxByText(cbSwapKey, BASE_KEY_ITEMS,  swapBase ~= "" and swapBase or "(none)")

    local defMod, defBase = ParseKey(profile.defaultKey or "")
    SetComboboxByText(cbDefMod, MOD_ITEMS,       defMod == "(none)" and "" or defMod)
    SetComboboxByText(cbDefKey, BASE_KEY_ITEMS,   defBase ~= "" and defBase or "(none)")

    enabledToggle = (profile.enabled == true)
    ApplyToggleColor(enabledToggle)
    ShowError("")
    UpdateDefaultKeyWarning()
end

local function RefreshProfileList()
    local profiles   = KeybindSwaps.profiles
    local totalPages = math.max(1, math.ceil(#profiles / MAX_ROWS))

    if currentPage > totalPages then currentPage = totalPages end

    local pageStart = (currentPage - 1) * MAX_ROWS + 1

    for i = 1, MAX_ROWS do
        local profileIdx = pageStart + i - 1
        local profile    = profiles[profileIdx]
        rowProfileMap[i] = profile and profileIdx or nil

        if profile then
            local prefix = profile.enabled and "[ON] " or "[OFF] "
            rowLabels[i].label:SetText(prefix .. (profile.name or "?"))
            rowLabels[i].label.style:SetColor(
                profile.enabled and 0.4 or 0.6,
                profile.enabled and 1.0 or 0.6,
                profile.enabled and 0.4 or 0.6, 1)
            rowLabels[i].label:Show(true)
            rowLabels[i].bg:Show(true)
        else
            rowLabels[i].label:SetText("")
            rowLabels[i].label:Show(false)
            rowLabels[i].bg:Show(false)
        end
    end

    -- Page navigation
    local showNav = totalPages > 1
    prevPageBtn:Show(showNav and currentPage > 1)
    nextPageBtn:Show(showNav and currentPage < totalPages)
    pageLbl:SetText(currentPage .. " / " .. totalPages)
    pageLbl:Show(showNav)

    -- Selection highlight
    if selectedIndex then
        local selPage = math.ceil(selectedIndex / MAX_ROWS)
        if selPage == currentPage then
            local rowI = selectedIndex - (currentPage - 1) * MAX_ROWS
            rowHighlight:RemoveAllAnchors()
            rowHighlight:AddAnchor("TOPLEFT", win, PANEL_LEFT_X, rowLabels[rowI].y)
            rowHighlight:Show(true)
        else
            rowHighlight:Show(false)
        end
    else
        rowHighlight:Show(false)
    end

    UpdateToggleAllBtn()
end

local function SelectProfile(index)
    local profiles = KeybindSwaps.profiles
    if not profiles[index] then return end

    local targetPage = math.ceil(index / MAX_ROWS)
    if targetPage ~= currentPage then
        currentPage = targetPage
        RefreshProfileList()
    end

    selectedIndex = index
    PopulateForm(profiles[index])
    hintLbl:Show(false)

    local rowI = index - (currentPage - 1) * MAX_ROWS
    rowHighlight:RemoveAllAnchors()
    rowHighlight:AddAnchor("TOPLEFT", win, PANEL_LEFT_X, rowLabels[rowI].y)
    rowHighlight:Show(true)
end

local function GetFormValues()
    local name       = ebName:GetText()
    local buffIdStr  = ebBuffId:GetText()
    local slotStr    = ebSlot:GetText()
    local swapKey    = CombineKey(cbSwapMod.selectorBtn:GetText(), cbSwapKey.selectorBtn:GetText())
    local defaultKey = CombineKey(cbDefMod.selectorBtn:GetText(),  cbDefKey.selectorBtn:GetText())

    if name == nil or name:match("^%s*$") then
        return nil, "Name cannot be empty."
    end

    local buffId = tonumber(buffIdStr)
    local slot   = tonumber(slotStr)

    if not buffId then return nil, "Buff ID must be a number." end
    if not slot   then return nil, "Slot must be a number."   end
    if slot < 1 or slot > 8 then return nil, "Slot must be between 1 and 8." end

    return {
        name       = name,
        enabled    = enabledToggle,
        buffId     = buffId,
        slot       = slot,
        swapKey    = swapKey,
        defaultKey = defaultKey,
    }
end

-- ─── Row click handlers ───────────────────────────────────────────────────────

for i = 1, MAX_ROWS do
    local idx = i
    local lbl = rowLabels[i].label
    lbl:SetHandler("OnClick", function(self)
        local profileIdx = rowProfileMap[idx]
        if profileIdx and KeybindSwaps.profiles[profileIdx] then
            SelectProfile(profileIdx)
        end
    end)
end

-- Update warning live when the Default Key dropdown selection changes.
cbDefKey.dropdown:SetHandler("OnSelChanged", function(self)
    UpdateDefaultKeyWarning()
end)

-- ─── Toggle button ────────────────────────────────────────────────────────────

toggleBtn:SetHandler("OnClick", function(self)
    enabledToggle = not enabledToggle
    ApplyToggleColor(enabledToggle)
end)
toggleBtn:SetHandler("OnLeave", function(self)
    ApplyToggleColor(enabledToggle)
end)

-- ─── Toggle All button ────────────────────────────────────────────────────────

toggleAllBtn:SetHandler("OnClick", function(self)
    local profiles = KeybindSwaps.profiles
    if #profiles == 0 then return end

    local allEnabled = true
    for _, p in ipairs(profiles) do
        if not p.enabled then allEnabled = false; break end
    end

    local newState = not allEnabled
    for _, p in ipairs(profiles) do p.enabled = newState end
    ADDON:SaveData("ks_profiles", profiles)

    if selectedIndex and profiles[selectedIndex] then
        enabledToggle = newState
        ApplyToggleColor(newState)
    end

    RefreshProfileList()
end)

-- ─── Page buttons ─────────────────────────────────────────────────────────────

prevPageBtn:SetHandler("OnClick", function(self)
    if currentPage > 1 then
        currentPage = currentPage - 1
        RefreshProfileList()
    end
end)

nextPageBtn:SetHandler("OnClick", function(self)
    local totalPages = math.max(1, math.ceil(#KeybindSwaps.profiles / MAX_ROWS))
    if currentPage < totalPages then
        currentPage = currentPage + 1
        RefreshProfileList()
    end
end)

-- ─── New button ───────────────────────────────────────────────────────────────

newBtn:SetHandler("OnClick", function(self)
    local profiles = KeybindSwaps.profiles
    if #profiles >= MAX_PROFILES then
        X2Chat:DispatchChatMessage(CMF_SYSTEM,
            "|cFFFFFF00[keybindswaps]|r Maximum of " .. MAX_PROFILES .. " profiles reached.")
        return
    end

    local newProfile = { name = "New Profile", enabled = true, buffId = 0, slot = 1, swapKey = "", defaultKey = "" }
    table.insert(profiles, newProfile)
    ADDON:SaveData("ks_profiles", profiles)

    selectedIndex = #profiles
    currentPage   = math.ceil(selectedIndex / MAX_ROWS)
    RefreshProfileList()
    PopulateForm(newProfile)
    hintLbl:Show(false)
end)

-- ─── Save button ──────────────────────────────────────────────────────────────

saveBtn:SetHandler("OnClick", function(self)
    ShowError("")

    if not selectedIndex then ShowError("No profile selected."); return end

    local profiles = KeybindSwaps.profiles
    if not profiles[selectedIndex] then ShowError("Selected profile no longer exists."); return end

    local values, err = GetFormValues()
    if not values then ShowError(err); return end

    profiles[selectedIndex] = values
    ADDON:SaveData("ks_profiles", profiles)
    RefreshProfileList()

    X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format(
        "|cFF00FFFF[keybindswaps]|r Profile [%s] saved.", values.name))
end)

-- ─── Delete button ────────────────────────────────────────────────────────────

deleteBtn:SetHandler("OnClick", function(self)
    ShowError("")

    if not selectedIndex then ShowError("No profile selected."); return end

    local profiles = KeybindSwaps.profiles
    if not profiles[selectedIndex] then ShowError("Selected profile no longer exists."); return end

    local removedName = profiles[selectedIndex].name
    table.remove(profiles, selectedIndex)
    ADDON:SaveData("ks_profiles", profiles)

    selectedIndex = nil
    ClearForm()
    RefreshProfileList()
    hintLbl:Show(true)

    X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format(
        "|cFF00FFFF[keybindswaps]|r Profile [%s] deleted.", removedName))
end)

-- ─── Window OnShow / OnHide / OnUpdate ───────────────────────────────────────

win:SetHandler("OnShow", function(self)
    selectedIndex = nil
    currentPage   = 1
    ClearForm()
    RefreshProfileList()
    hintLbl:Show(true)
end)

win:SetHandler("OnHide", function(self)
    scanWinShown = false
    scanWin:Show(false)
end)

-- Keep the scan window pinned to the right of the main window while dragging.
win:SetHandler("OnUpdate", function(self, dt)
    if scanWinShown then
        scanWin:RemoveAllAnchors()
        scanWin:AddAnchor("TOPLEFT", win, "TOPRIGHT", 5, 0)
    end
end)

-- ─── Scanner logic ────────────────────────────────────────────────────────────

local baselineBuffs = {}
local foundBuffs    = {}
local scanTimer     = 0
local scanListIdx   = 1

local function TakeBaseline()
    baselineBuffs = {}
    foundBuffs    = {}
    scanList:ClearItem()
    scanListIdx = 1
    local count = tonumber(X2Unit:UnitBuffCount("player")) or 0
    for i = 1, count do
        local buff = X2Unit:UnitBuff("player", i)
        if buff then baselineBuffs[buff.buff_id] = true end
    end
    scanStatusLbl:SetText(string.format(
        "Baseline: %d buffs. Glide then click a result to use it.", count))
end

scanList:SetHandler("OnSelChanged", function(self)
    local text = self:GetSelectedText()
    if not text then return end
    local id = text:match("%(ID: (%d+)%)")
    if id then
        ebBuffId:SetText(id)
        scanWinShown = false
        scanWin:Show(false)
    end
end)

scanClearBtn:SetHandler("OnClick", function(self)
    TakeBaseline()
end)

scanOpenBtn:SetHandler("OnClick", function(self)
    scanWinShown = not scanWinShown
    scanWin:Show(scanWinShown)
end)

scanWin:SetHandler("OnShow", function(self)
    scanTimer = 0
    TakeBaseline()
end)

scanWin:SetHandler("OnUpdate", function(self, dt)
    scanTimer = scanTimer + dt
    if scanTimer < 500 then return end
    scanTimer = 0

    local count = tonumber(X2Unit:UnitBuffCount("player")) or 0
    for i = 1, count do
        local buff = X2Unit:UnitBuffTooltip("player", i)
        if buff and buff.buff_id
            and not baselineBuffs[buff.buff_id]
            and not foundBuffs[buff.buff_id] then

            foundBuffs[buff.buff_id] = true
            local name = (buff.name and buff.name ~= "") and buff.name or "Unknown"
            scanList:AppendItem(
                string.format("%s  (ID: %d)", name, buff.buff_id),
                scanListIdx, 0.4, 1.0, 0.6, 1)
            scanListIdx = scanListIdx + 1
        end
    end
end)

-- ─── ESC menu integration ─────────────────────────────────────────────────────

ADDON:AddEscMenuButton(5, 1200, "achievement", "KeybindSwaps")
ADDON:RegisterContentWidget(1200, win, function(show)
    win:Show(show or false)
end)
