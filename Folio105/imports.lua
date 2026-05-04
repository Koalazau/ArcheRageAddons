
-- imports.lua
-- Universal import file for all API_TYPE and OBJECT_TYPE
-- This eliminates missing import errors by importing everything

-- Check if Globals folder is available
if API_TYPE == nil then
    ADDON:ImportAPI(8)
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "Globals folder not found. Please install it from the ArcheRage addon repository")
    return
end

-- ============================================
-- IMPORT ALL API_TYPE (Alphabetical Order)
-- ============================================
-- Note: ADDON (0) and UI (1) are auto-imported

ADDON:ImportAPI(API_TYPE.ABILITY.id)                   -- 3
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)               -- 67
ADDON:ImportAPI(API_TYPE.ACTION.id)                    -- 4
ADDON:ImportAPI(API_TYPE.ARCHE_PASS.id)                -- 81
ADDON:ImportAPI(API_TYPE.AUCTION.id)                   -- 51
ADDON:ImportAPI(API_TYPE.BAG.id)                       -- 5
ADDON:ImportAPI(API_TYPE.BANK.id)                      -- 47
ADDON:ImportAPI(API_TYPE.BATTLE_FIELD.id)              -- 6
ADDON:ImportAPI(API_TYPE.BLESS_UTHSTIN.id)             -- 72
ADDON:ImportAPI(API_TYPE.BOOK.id)                      -- 58
ADDON:ImportAPI(API_TYPE.BUFFSKILL.id)                 -- 53
ADDON:ImportAPI(API_TYPE.BUTLER.id)                    -- 82
ADDON:ImportAPI(API_TYPE.CAMERA.id)                    -- 7
ADDON:ImportAPI(API_TYPE.CASH_STORE.id)                -- 56
ADDON:ImportAPI(API_TYPE.CHAT.id)                      -- 8
ADDON:ImportAPI(API_TYPE.COFFER.id)                    -- 48
ADDON:ImportAPI(API_TYPE.COMBAT_RESOURCE.id)           -- 83
ADDON:ImportAPI(API_TYPE.CONSOLE.id)                   -- 2
ADDON:ImportAPI(API_TYPE.CRAFT.id)                     -- 9
ADDON:ImportAPI(API_TYPE.CURSOR.id)                    -- 10
ADDON:ImportAPI(API_TYPE.CUSTOMIZER.id)                -- 60
ADDON:ImportAPI(API_TYPE.CUSTOMIZING_UNIT.id)          -- 26
ADDON:ImportAPI(API_TYPE.DEBUG.id)                     -- 11
ADDON:ImportAPI(API_TYPE.DECAL.id)                     -- 12
ADDON:ImportAPI(API_TYPE.DIALOG_MANAGER.id)            -- 55
ADDON:ImportAPI(API_TYPE.DOMINION.id)                  -- 16
ADDON:ImportAPI(API_TYPE.DYEING.id)                    -- 78
ADDON:ImportAPI(API_TYPE.EQUIPMENT.id)                 -- 13
ADDON:ImportAPI(API_TYPE.EQUIP_SLOT_REINFORCE.id)      -- 75
ADDON:ImportAPI(API_TYPE.EVENT_CENTER.id)              -- 69
ADDON:ImportAPI(API_TYPE.FACTION.id)                   -- 14
ADDON:ImportAPI(API_TYPE.FAMILY.id)                    -- 17
ADDON:ImportAPI(API_TYPE.FRIEND.id)                    -- 15
ADDON:ImportAPI(API_TYPE.GOODS_MAIL.id)                -- 29
ADDON:ImportAPI(API_TYPE.GUILD_BANK.id)                -- 49
ADDON:ImportAPI(API_TYPE.HEIR_SKILL.id)                -- 74
ADDON:ImportAPI(API_TYPE.HELPER.id)                    -- 64
ADDON:ImportAPI(API_TYPE.HERO.id)                      -- 68
ADDON:ImportAPI(API_TYPE.HOTKEY.id)                    -- 19
ADDON:ImportAPI(API_TYPE.HOUSE.id)                     -- 20
ADDON:ImportAPI(API_TYPE.INDUN.id)                     -- 80
ADDON:ImportAPI(API_TYPE.INPUT.id)                     -- 21
ADDON:ImportAPI(API_TYPE.INTERACTION.id)               -- 22
ADDON:ImportAPI(API_TYPE.ITEM.id)                      -- 23
ADDON:ImportAPI(API_TYPE.ITEM_ENCHANT.id)              -- 66
ADDON:ImportAPI(API_TYPE.ITEM_GACHA.id)                -- 70
ADDON:ImportAPI(API_TYPE.ITEM_GUIDE.id)                -- 71
ADDON:ImportAPI(API_TYPE.ITEM_LOOK_CONVERTER.id)       -- 62
ADDON:ImportAPI(API_TYPE.LOCALE.id)                    -- 24
ADDON:ImportAPI(API_TYPE.LOGIN_CHARCTER.id)            -- 25
ADDON:ImportAPI(API_TYPE.LOOT.id)                      -- 27
ADDON:ImportAPI(API_TYPE.MAIL.id)                      -- 28
ADDON:ImportAPI(API_TYPE.MAP.id)                       -- 54
ADDON:ImportAPI(API_TYPE.MATE.id)                      -- 52
ADDON:ImportAPI(API_TYPE.MINI_SCOREBOARD.id)           -- 85
ADDON:ImportAPI(API_TYPE.NAMETAG.id)                   -- 30
ADDON:ImportAPI(API_TYPE.NATION.id)                    -- 59
ADDON:ImportAPI(API_TYPE.ONE_AND_ONE_CHAT.id)          -- 76
ADDON:ImportAPI(API_TYPE.OPTION.id)                    -- 31
ADDON:ImportAPI(API_TYPE.PLAYER.id)                    -- 32
ADDON:ImportAPI(API_TYPE.PREMIUM_SERVICE.id)           -- 65
ADDON:ImportAPI(API_TYPE.QUEST.id)                     -- 33
ADDON:ImportAPI(API_TYPE.RANK.id)                      -- 63
ADDON:ImportAPI(API_TYPE.RENEW_ITEM.id)                -- 50
ADDON:ImportAPI(API_TYPE.RESIDENT.id)                  -- 73
ADDON:ImportAPI(API_TYPE.ROSTER.id)                    -- 84
ADDON:ImportAPI(API_TYPE.SECURITY.id)                  -- 61
ADDON:ImportAPI(API_TYPE.SIEGE_WEAPON.id)              -- 34
ADDON:ImportAPI(API_TYPE.SKILL.id)                     -- 35
ADDON:ImportAPI(API_TYPE.SKILL_ALERT.id)               -- 79
ADDON:ImportAPI(API_TYPE.SOUND.id)                     -- 36
ADDON:ImportAPI(API_TYPE.SQUAD.id)                     -- 77
ADDON:ImportAPI(API_TYPE.STORE.id)                     -- 37
ADDON:ImportAPI(API_TYPE.SURVEY_FORM.id)               -- 86
ADDON:ImportAPI(API_TYPE.TEAM.id)                      -- 38
ADDON:ImportAPI(API_TYPE.TIME.id)                      -- 39
ADDON:ImportAPI(API_TYPE.TRADE.id)                     -- 40
ADDON:ImportAPI(API_TYPE.TRIAL.id)                     -- 18
ADDON:ImportAPI(API_TYPE.TUTORIAL.id)                  -- 41
ADDON:ImportAPI(API_TYPE.UCC.id)                       -- 46
ADDON:ImportAPI(API_TYPE.UNIT.id)                      -- 42
ADDON:ImportAPI(API_TYPE.USER_MUSIC.id)                -- 57
ADDON:ImportAPI(API_TYPE.UTIL.id)                      -- 43
ADDON:ImportAPI(API_TYPE.WARP.id)                      -- 44
ADDON:ImportAPI(API_TYPE.WORLD.id)                     -- 45

-- ============================================
-- IMPORT ALL OBJECT_TYPE (Alphabetical Order)
-- ============================================

ADDON:ImportObject(OBJECT_TYPE.AVI)                    -- 52
ADDON:ImportObject(OBJECT_TYPE.BUTTON)                 -- 2
ADDON:ImportObject(OBJECT_TYPE.CHAT_EDIT)              -- 43
ADDON:ImportObject(OBJECT_TYPE.CHAT_MESSAGE)           -- 42
ADDON:ImportObject(OBJECT_TYPE.CHAT_TAB)               -- 38
ADDON:ImportObject(OBJECT_TYPE.CHECK_BUTTON)           -- 23
ADDON:ImportObject(OBJECT_TYPE.CIRCLE_DIAGRAM)         -- 31
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)         -- 7
ADDON:ImportObject(OBJECT_TYPE.COLOR_PICKER)           -- 32
ADDON:ImportObject(OBJECT_TYPE.COMBO_LIST_BUTTON)      -- 41
ADDON:ImportObject(OBJECT_TYPE.COMBOBOX)               -- 40
ADDON:ImportObject(OBJECT_TYPE.COOLDOWN_BUTTON)        -- 20
ADDON:ImportObject(OBJECT_TYPE.COOLDOWN_CONSTANT_BUTTON) -- 22
ADDON:ImportObject(OBJECT_TYPE.COOLDOWN_INVENTORY_BUTTON) -- 21
ADDON:ImportObject(OBJECT_TYPE.DAMAGE_DISPLAY)         -- 35
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)               -- 6
ADDON:ImportObject(OBJECT_TYPE.DYNAMIC_LIST)           -- 54
ADDON:ImportObject(OBJECT_TYPE.EDITBOX)                -- 3
ADDON:ImportObject(OBJECT_TYPE.EDITBOX_MULTILINE)      -- 4
ADDON:ImportObject(OBJECT_TYPE.EFFECT_DRAWABLE)        -- 15
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)           -- 46
ADDON:ImportObject(OBJECT_TYPE.FOLDER)                 -- 34
ADDON:ImportObject(OBJECT_TYPE.GAME_TOOLTIP)           -- 18
ADDON:ImportObject(OBJECT_TYPE.GRID)                   -- 28
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)          -- 11
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)         -- 10
ADDON:ImportObject(OBJECT_TYPE.LABEL)                  -- 1
ADDON:ImportObject(OBJECT_TYPE.LINE)                   -- 48
ADDON:ImportObject(OBJECT_TYPE.LISTBOX)                -- 5
ADDON:ImportObject(OBJECT_TYPE.LIST_CTRL)              -- 45
ADDON:ImportObject(OBJECT_TYPE.MEGAPHONE_CHAT_EDIT)    -- 44
ADDON:ImportObject(OBJECT_TYPE.MESSAGE)                -- 16
ADDON:ImportObject(OBJECT_TYPE.MODEL_VIEW)             -- 29
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)     -- 8
ADDON:ImportObject(OBJECT_TYPE.PAGEABLE)               -- 25
ADDON:ImportObject(OBJECT_TYPE.PAINT_COLOR_PICKER)     -- 33
ADDON:ImportObject(OBJECT_TYPE.RADIO)                  -- 55
ADDON:ImportObject(OBJECT_TYPE.ROAD_MAP)               -- 27
ADDON:ImportObject(OBJECT_TYPE.ROOT)                   -- 49
ADDON:ImportObject(OBJECT_TYPE.SLIDER)                 -- 24
ADDON:ImportObject(OBJECT_TYPE.SLIDER_TAB)             -- 37
ADDON:ImportObject(OBJECT_TYPE.SLOT)                   -- 47
ADDON:ImportObject(OBJECT_TYPE.STATUS_BAR)             -- 17
ADDON:ImportObject(OBJECT_TYPE.TAB)                    -- 36
ADDON:ImportObject(OBJECT_TYPE.TEXTBOX)                -- 39
ADDON:ImportObject(OBJECT_TYPE.TEXT_DRAWABLE)          -- 12
ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)             -- 13
ADDON:ImportObject(OBJECT_TYPE.TEXTURE_DRAWABLE)       -- 50
ADDON:ImportObject(OBJECT_TYPE.THREE_COLOR_DRAWABLE)   -- 14
ADDON:ImportObject(OBJECT_TYPE.THREE_PART_DRAWABLE)    -- 9
ADDON:ImportObject(OBJECT_TYPE.UNITFRAME_TOOLTIP)      -- 19
ADDON:ImportObject(OBJECT_TYPE.WEBBROWSER)             -- 30
ADDON:ImportObject(OBJECT_TYPE.WEBVIEW)                -- 51
ADDON:ImportObject(OBJECT_TYPE.WINDOW)                 -- 0
ADDON:ImportObject(OBJECT_TYPE.WORLD_MAP)              -- 26
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)             -- 53
