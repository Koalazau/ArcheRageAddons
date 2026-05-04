-- keybindswaps/main.lua
-- Monitors player buffs for active glider profiles, swaps the mode action bar
-- slot keybind when a matching glider activates, then reverts when the
-- glider-end debuff appears.

if API_TYPE == nil then
    ADDON:ImportAPI(8)
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "[keybindswaps] Globals folder not found. Please install it.")
    return
end

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.HOTKEY.id)

ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)

-- ─── Addon table ──────────────────────────────────────────────────────────────

KeybindSwaps = {
    -- Set to true to see swap/revert messages in chat while testing.
    -- Set to false before distributing to other players.
    debugMode = false,
    profiles  = {},
}

-- ─── Constants ────────────────────────────────────────────────────────────────

local GLIDER_END_DEBUFF_NAME = "Preparing Glider"
local REVERT_COOLDOWN        = 1.0  -- seconds to ignore swap triggers after a revert

local function DebugMsg(msg)
    if KeybindSwaps.debugMode then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, msg)
    end
end

-- Load saved profiles; falls back to the empty table defined above
local saved = ADDON:LoadData("ks_profiles")
if saved then KeybindSwaps.profiles = saved end

-- ─── State ────────────────────────────────────────────────────────────────────

local activeProfile   = nil  -- matched profile while a swap is active, nil otherwise
local originalBinding = nil  -- binding captured just before the swap
local revertTime      = 0    -- os.clock() timestamp of the last revert

-- ─── Swap logic ───────────────────────────────────────────────────────────────

local function SwapForProfile(profile)
    -- BindingToOption MUST be called before any binding change or all hotkeys get erased
    X2Hotkey:BindingToOption()

    -- Store the raw value as-is so we can pass the exact same value back on revert.
    -- We need to know what string the engine uses for "no binding" — log it so we can see.
    originalBinding = X2Hotkey:GetOptionBinding("mode_action_bar_button", 1, false, profile.slot)
    DebugMsg(string.format("|cFF00FFFF[keybindswaps]|r Raw binding for slot %d before swap: [%s]",
        profile.slot, tostring(originalBinding)))

    -- Only fall back to defaultKey if the raw read was nil; keep "" if that's what the engine returned.
    if originalBinding == nil then
        originalBinding = profile.defaultKey
    end

    X2Hotkey:SetOptionBindingWithIndex("mode_action_bar_button", profile.swapKey, 1, profile.slot)
    X2Hotkey:SaveHotKey()

    activeProfile = profile
    DebugMsg(string.format("|cFF00FFFF[keybindswaps]|r Swapped [%s] slot %d: [%s] → %s",
        profile.name, profile.slot, tostring(originalBinding), profile.swapKey))
end

local function RevertActiveProfile()
    if not activeProfile then return end

    -- BindingToOption MUST be called before any binding change or all hotkeys get erased
    X2Hotkey:BindingToOption()

    -- Resolve the key to restore to.
    local restoreTo = originalBinding
    if (restoreTo == nil or restoreTo == "") and activeProfile.defaultKey ~= "" then
        restoreTo = activeProfile.defaultKey
    end

    if restoreTo and restoreTo ~= "" then
        X2Hotkey:SetOptionBindingWithIndex("mode_action_bar_button", restoreTo, 1, activeProfile.slot)
        X2Hotkey:SaveHotKey()
    else
        -- The engine has no API to clear a binding (SetOptionBindingWithIndex ignores "").
        -- Mode bar slots only fire during glider/mount mode, so the swap key staying
        -- bound to this slot is functionally harmless — it won't trigger outside of mode.
        DebugMsg(string.format(
            "|cFFFFFF00[keybindswaps]|r [%s] slot %d: cannot restore to unbound — no available API to clear a binding. Set a Default Key in the profile to avoid this.",
            activeProfile.name, activeProfile.slot))
    end

    local profileName = activeProfile.name
    local slot        = activeProfile.slot
    revertTime        = os.clock()
    activeProfile     = nil
    originalBinding   = nil

    DebugMsg(string.format("|cFF00FFFF[keybindswaps]|r Reverted [%s] slot %d back to [%s]",
        profileName, slot, restoreTo))
end

-- ─── Debuff check ─────────────────────────────────────────────────────────────

local function CheckForGliderEndDebuff()
    if not activeProfile then return end
    local count = tonumber(X2Unit:UnitDeBuffCount("player")) or 0
    for i = 1, count do
        local debuff = X2Unit:UnitDeBuffTooltip("player", i)
        if debuff and debuff.name == GLIDER_END_DEBUFF_NAME then
            RevertActiveProfile()
            return
        end
    end
end

-- ─── Event listener ───────────────────────────────────────────────────────────

local listener = CreateEmptyWindow("keybindswapsListener", "UIParent")
listener:Show(false)

listener:SetHandler("OnEvent", function(this, event, ...)
    if event == "MODE_ACTIONS_UPDATE" then
        if activeProfile then
            -- A swap is active. Scan for the glider buff — if it's gone the mode bar
            -- just disappeared, so revert RIGHT NOW while the runtime slots are clearing.
            local buffCount = tonumber(X2Unit:UnitBuffCount("player")) or 0
            for i = 1, buffCount do
                local buff = X2Unit:UnitBuff("player", i)
                if buff and buff.buff_id == activeProfile.buffId then
                    return  -- still on glider, ignore
                end
            end
            RevertActiveProfile()
            return
        end

        if (os.clock() - revertTime) < REVERT_COOLDOWN then return end

        local buffCount = tonumber(X2Unit:UnitBuffCount("player")) or 0
        for i = 1, buffCount do
            local buff = X2Unit:UnitBuff("player", i)
            if buff then
                for _, profile in ipairs(KeybindSwaps.profiles) do
                    if profile.enabled and profile.buffId == buff.buff_id then
                        SwapForProfile(profile)
                        return
                    end
                end
            end
        end

    elseif event == "DEBUFF_UPDATE" then
        -- Fallback revert path in case MODE_ACTIONS_UPDATE missed it.
        local action, target = ...
        if action == "create" and target == "character" then
            CheckForGliderEndDebuff()
        end
    end
end)

listener:RegisterEvent("MODE_ACTIONS_UPDATE")
listener:RegisterEvent("DEBUFF_UPDATE")

X2Chat:DispatchChatMessage(CMF_SYSTEM, "|cFF00FFFF[keybindswaps]|r Loaded. Glider swap active.")
