-- Made by Koala

if API_TYPE == nil then
	ADDON:ImportAPI(8)
	X2Chat:DispatchChatMessage(CMF_SYSTEM, "[autoroleset] Globals folder not found. Please install it.")
	return
end

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.TEAM.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)

ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.CHECK_BUTTON)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.THREE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)

local ROLES_SAVE_KEY = "classRoles"

local PANEL_W = 430
local PANEL_H = 430

local BG_TEXTURE    = "ui/common/default.dds"
local CHECK_TEXTURE = "ui/button/check_button.dds"
local MAX_LIST_ROWS = 6

local ESC_MENU_ID = 4451

local ROLES = {
	{ id = 0, colour = "None",   rgb = { 0.45, 0.50, 0.58 } },
	{ id = 1, colour = "Green",  rgb = { 0.36, 0.80, 0.36 } },
	{ id = 2, colour = "Pink",   rgb = { 0.95, 0.56, 0.80 } },
	{ id = 3, colour = "Red",    rgb = { 0.90, 0.30, 0.30 } },
	{ id = 4, colour = "Purple", rgb = { 0.70, 0.45, 0.90 } },
}

local ROLE_LABEL = {}
local ROLE_RGB   = {}
for i = 1, #ROLES do
	ROLE_LABEL[ROLES[i].id] = ROLES[i].id .. " - " .. ROLES[i].colour
	ROLE_RGB[ROLES[i].id]   = ROLES[i].rgb
end

local function Chat(msg)
	X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF8FD6FF[autoroleset]|r " .. msg)
end

local DARK_THEME = {
	title = { 214 / 255, 226 / 255, 240 / 255, 1 },
	text  = { 184 / 255, 208 / 255, 229 / 255, 1 },
	dim   = { 132 / 255, 152 / 255, 170 / 255, 1 },
	good = { 120 / 255, 215 / 255, 120 / 255, 1 },
	bad  = { 235 / 255, 110 / 255, 110 / 255, 1 },
}

local LIGHT_THEME = {
	title = { 255 / 255, 242 / 255, 179 / 255, 1 },
	text  = { 102 / 255, 64 / 255, 11 / 255, 1 },
	dim   = { 140 / 255, 110 / 255, 70 / 255, 1 },
	good = { 24 / 255, 110 / 255, 34 / 255, 1 },
	bad  = { 160 / 255, 28 / 255, 28 / 255, 1 },
}

local theme = LIGHT_THEME

local function RefreshTheme()
	theme = isUserDarkMode() and DARK_THEME or LIGHT_THEME
end

local function Paint(lbl, key)
	local c = theme[key]
	lbl.style:SetColor(c[1], c[2], c[3], c[4])
end

local classRoles = {}
local pendingRole = nil
local lastSent    = nil
local panel

local function LoadRoles()
	local saved = ADDON:LoadData(ROLES_SAVE_KEY)
	classRoles = {}
	if type(saved) ~= "table" then
		return
	end
	for key, roleId in pairs(saved) do

		if type(key) == "string" and ROLE_LABEL[tonumber(roleId)] ~= nil then
			classRoles[key] = tonumber(roleId)
		end
	end
end

local function SaveRoles()
	ADDON:SaveData(ROLES_SAVE_KEY, classRoles)
end

local function GetClassKey()
	local templates = X2Unit:GetTargetAbilityTemplates("player")
	if templates == nil or templates[1] == nil or templates[2] == nil or templates[3] == nil then
		return nil
	end
	local indices = { templates[1].index, templates[2].index, templates[3].index }
	table.sort(indices)
	local key = string.format("name_%d_%d_%d", indices[1], indices[2], indices[3])
	if key == "name_30_30_30" then
		return nil
	end
	return key
end

local function CategoryOf(key)
	if key == nil or nameMappings == nil then
		return nil
	end
	return nameMappings[key]
end

local function ClassLabel(key)
	if key == nil then
		return nil
	end
	if AUTOROLESET_CLASSES ~= nil and AUTOROLESET_CLASSES[key] ~= nil then
		return AUTOROLESET_CLASSES[key].name
	end
	return CategoryOf(key) or key
end

local function InTeam()
	return X2Unit:UnitName("team1") ~= nil or X2Unit:UnitName("team01") ~= nil
end

local function ApplyRole(verbose)
	if not InTeam() then

		lastSent = nil
		if verbose then Chat("Not in a raid yet - it will apply when you join one.") end
		return
	end
	local key = GetClassKey()
	if key == nil then
		if verbose then Chat("Could not read your class yet.") end
		return
	end
	local want = classRoles[key]
	if want == nil then
		if verbose then Chat(ClassLabel(key) .. " has no saved role.") end
		return
	end

	if lastSent == want and not verbose then
		return
	end

	X2Team:SetRole(want)
	lastSent = want
	Chat(ClassLabel(key) .. " -> " .. ROLE_LABEL[want] .. ".")
end

local function MakeLabel(parent, id, idx, x, y, w, h, size, align)
	local lbl = parent:CreateChildWidget("label", id, idx, true)
	lbl:SetExtent(w, h)
	lbl:AddAnchor("TOPLEFT", parent, x, y)
	lbl.style:SetFontSize(size)
	lbl.style:SetAlign(align or ALIGN_LEFT)
	lbl:Show(true)
	return lbl
end

local function MakeButton(parent, id, text, x, y, w, h)
	local b = parent:CreateChildWidget("button", id, 0, true)
	b:SetText(text)
	b:SetStyle("text_default")
	b:SetExtent(w, h)
	b:AddAnchor("TOPLEFT", parent, x, y)
	b:Show(true)
	return b
end

local function MakeCheck(parent, idx, text, rgb, x, y)
	local cb = parent:CreateChildWidget("checkbutton", "roleCheck", idx, true)
	cb:SetExtent(20, 20)
	cb:AddAnchor("TOPLEFT", parent, x, y)

	local box = cb:CreateDrawable(CHECK_TEXTURE, "btn_df", "background")
	box:SetExtent(20, 20)
	box:AddAnchor("CENTER", cb, 0, 0)

	local tick = cb:CreateDrawable(CHECK_TEXTURE, "btn_chk_df", "background")
	tick:SetExtent(20, 20)
	tick:AddAnchor("CENTER", cb, 0, 0)
	tick:SetVisible(false)
	cb.tick = tick

	local swatch = parent:CreateColorDrawable(rgb[1], rgb[2], rgb[3], 1, "overlay")
	swatch:SetExtent(14, 14)
	swatch:AddAnchor("LEFT", cb, "RIGHT", 7, 0)

	local lbl = parent:CreateChildWidget("label", "roleCheckLbl", idx, true)
	lbl:SetExtent(120, 20)
	lbl:AddAnchor("LEFT", cb, "RIGHT", 28, 0)
	lbl.style:SetFontSize(13)
	lbl.style:SetAlign(ALIGN_LEFT)
	lbl:SetText(text)
	lbl:Show(true)
	cb.label = lbl

	cb:Show(true)
	return cb
end

local function BuildPanel()
	local win = CreateEmptyWindow("autorolesetPanel", "UIParent")
	win:SetExtent(PANEL_W, PANEL_H)
	win:AddAnchor("CENTER", "UIParent", 0, 0)
	win:SetCloseOnEscape(true)
	win:Clickable(true)

	local bg = win:CreateDrawable(BG_TEXTURE, "main_bg", "background")
	bg:AddAnchor("TOPLEFT", win, -5, -5)
	bg:AddAnchor("BOTTOMRIGHT", win, 5, 5)

	local deco = win:CreateDrawable(BG_TEXTURE, "main_bg_deco", "background")
	deco:AddAnchor("TOPLEFT", win, 0, -5)
	deco:AddAnchor("TOPRIGHT", win, 0, -5)

	local titleBar = win:CreateChildWidget("window", "titleBar", 0, true)
	titleBar:AddAnchor("TOPLEFT", win, 0, 10)
	titleBar:AddAnchor("TOPRIGHT", win, 0, 10)
	titleBar:SetHeight(28)
	titleBar.titleStyle:SetAlign(ALIGN_CENTER)
	titleBar.titleStyle:SetFontSize(17)
	titleBar:SetTitleText("Auto Roles")
	titleBar:Show(true)
	win.titleWidget = titleBar

	titleBar:EnableDrag(true)
	function titleBar:OnDragStart() win:StartMoving() end
	titleBar:SetHandler("OnDragStart", titleBar.OnDragStart)
	function titleBar:OnDragStop() win:StopMovingOrSizing() end
	titleBar:SetHandler("OnDragStop", titleBar.OnDragStop)

	local closeBtn = titleBar:CreateChildWidget("button", "closeBtn", 0, true)
	closeBtn:SetStyle("btn_close_default")
	closeBtn:AddAnchor("TOPRIGHT", titleBar, 2, -2)
	closeBtn:Show(true)
	closeBtn:SetHandler("OnClick", function() win:Show(false) end)

	win.classHdr  = MakeLabel(win, "classHdr", 0, 24, 60, 382, 18, 12)
	win.classLbl  = MakeLabel(win, "classLbl", 0, 24, 78, 382, 24, 18)
	win.statusLbl = MakeLabel(win, "statusLbl", 0, 24, 104, 382, 20, 13)
	win.pickHdr   = MakeLabel(win, "pickHdr", 0, 24, 132, 382, 18, 12)

	win.classHdr:SetText("Class you are playing now")
	win.pickHdr:SetText("Join raids as")

	local COLS = { 28, 228 }
	local checks = {}
	for i = 1, #ROLES do
		local col = ((i - 1) % 2) + 1
		local row = math.floor((i - 1) / 2)
		local cb = MakeCheck(win, i, ROLE_LABEL[ROLES[i].id], ROLES[i].rgb,
			COLS[col], 154 + row * 26)
		cb.roleId = ROLES[i].id
		checks[i] = cb
	end
	win.checks = checks

	win.saveBtn   = MakeButton(win, "saveBtn", "Save this class", 24, 238, 170, 28)
	win.forgetBtn = MakeButton(win, "forgetBtn", "Forget", 202, 238, 110, 28)

	win.listHdr = MakeLabel(win, "listHdr", 0, 24, 278, 382, 18, 12)

	local rows = {}
	for i = 1, MAX_LIST_ROWS do
		local r = MakeLabel(win, "row", i, 24, 298 + (i - 1) * 18, 382, 18, 12)
		r:Show(false)
		rows[i] = r
	end
	win.rows = rows

	win:Show(false)
	return win
end

local function Refresh()
	if panel == nil then
		return
	end

	local key   = GetClassKey()
	local saved = key ~= nil and classRoles[key] or nil

	Paint(panel.classHdr, "dim")
	Paint(panel.pickHdr, "dim")
	Paint(panel.listHdr, "dim")
	Paint(panel.classLbl, "text")

	local tc = theme.title
	panel.titleWidget.titleStyle:SetColor(tc[1], tc[2], tc[3], tc[4])

	if key == nil then
		panel.classLbl:SetText("Class unknown")
		Paint(panel.statusLbl, "bad")
		panel.statusLbl:SetText("Could not read your ability set yet.")
	else
		local cat = CategoryOf(key)
		local name = ClassLabel(key)

		panel.classLbl:SetText(cat ~= nil and cat ~= name and (name .. "  (" .. cat .. ")") or name)
		if saved ~= nil then
			Paint(panel.statusLbl, "good")
			panel.statusLbl:SetText("SAVED - joins as role " .. ROLE_LABEL[saved])
		else
			Paint(panel.statusLbl, "bad")
			panel.statusLbl:SetText("NOT SAVED - tick a role number below, then Save")
		end
	end

	if pendingRole == nil then
		pendingRole = saved
	end

	for i = 1, #panel.checks do
		local cb = panel.checks[i]
		local on = pendingRole ~= nil and cb.roleId == pendingRole
		cb:SetChecked(on, false)
		cb.tick:SetVisible(on)
		Paint(cb.label, on and "text" or "dim")
	end

	local n = 0
	for _ in pairs(classRoles) do n = n + 1 end
	panel.listHdr:SetText(n == 0 and "Nothing saved yet" or ("Saved classes (" .. n .. ")"))

	local ordered = {}
	for k, v in pairs(classRoles) do
		table.insert(ordered, { key = k, role = v, name = ClassLabel(k) })
	end
	table.sort(ordered, function(a, b) return a.name < b.name end)

	for i = 1, MAX_LIST_ROWS do
		local row, entry = panel.rows[i], ordered[i]
		if entry == nil then
			row:Show(false)
		else
			local isCurrent = entry.key == key
			Paint(row, isCurrent and "good" or "text")
			row:SetText((isCurrent and "> " or "    ") .. entry.name .. "   ->   " .. ROLE_LABEL[entry.role])
			row:Show(true)
		end
	end
	if #ordered > MAX_LIST_ROWS then
		local row = panel.rows[MAX_LIST_ROWS]
		Paint(row, "dim")
		row:SetText("    ... and " .. (#ordered - MAX_LIST_ROWS + 1) .. " more")
		row:Show(true)
	end
end

local function AttachHandlers()
	for i = 1, #panel.checks do
		local cb = panel.checks[i]
		cb:SetHandler("OnCheckChanged", function(self)

			pendingRole = self.roleId
			Refresh()
		end)
	end

	panel.saveBtn:SetHandler("OnClick", function()
		local key = GetClassKey()
		if key == nil then
			Chat("Could not read your class. Open your skill sets once, then retry.")
			return
		end
		if pendingRole == nil then
			Chat("Tick a role number first.")
			return
		end
		classRoles[key] = pendingRole
		lastSent = nil
		SaveRoles()
		Chat("Saved " .. ClassLabel(key) .. " as " .. ROLE_LABEL[pendingRole] .. ".")
		Refresh()
		ApplyRole(true)
	end)

	panel.forgetBtn:SetHandler("OnClick", function()
		local key = GetClassKey()
		if key == nil or classRoles[key] == nil then
			Chat("Nothing saved for your current class.")
			return
		end
		classRoles[key] = nil
		pendingRole = nil
		SaveRoles()
		Chat("Forgot " .. ClassLabel(key) .. ".")
		Refresh()
	end)
end

local function TogglePanel()
	if panel:IsVisible() then
		panel:Show(false)
		return
	end
	RefreshTheme()
	pendingRole = nil
	Refresh()
	panel:Show(true)
end


RefreshTheme()
LoadRoles()
panel = BuildPanel()
AttachHandlers()
X2:AddEscMenuButton(2, ESC_MENU_ID, "tgos", "Auto Roles")
ADDON:RegisterContentTriggerFunc(ESC_MENU_ID, TogglePanel)

UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, function()
	lastSent = nil
	RefreshTheme()
	LoadRoles()
	ApplyRole(false)
	Refresh()
end)

UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_MEMBERS_CHANGED, function()
	ApplyRole(false)
	Refresh()
end)

UIParent:SetEventHandler(UIEVENT_TYPE.ABILITY_CHANGED, function()
	pendingRole = nil
	lastSent    = nil
	ApplyRole(false)
	Refresh()
end)
