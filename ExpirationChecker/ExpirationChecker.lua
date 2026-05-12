ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)
ADDON:ImportAPI(API_TYPE.PLAYER.id)
ADDON:ImportAPI(API_TYPE.EQUIPMENT.id)
ADDON:ImportAPI(API_TYPE.BAG.id)
ADDON:ImportAPI(API_TYPE.TIME.id)
ADDON:ImportAPI(API_TYPE.MAP.id)

local iconChecker = CreateEmptyWindow("iconChecker", "UIParent")
iconChecker:Show(true)

local counter = 0
local trackers = {}
local iconSize = 70
local ExpiredTexture = "addon/ExpirationChecker/expired.dds"

local noBuffDetectedWindow = nil
local noBuffDetectedCooldown = 0
local notificationDisplayTime = 50
local notificationTimer = 0
local isNotificationVisible = false

local function CreateTracker(slotId, xOffset, yOffset)
    local tracker = {}
    tracker.window = UIParent:CreateWidget("window", "tracker_" .. slotId, "UIParent", "")
    tracker.window:SetExtent(iconSize, iconSize)
    tracker.window:Show(false)
    tracker.window:EnableDrag(false)

    tracker.icon = tracker.window:CreateIconDrawable("artwork")
    tracker.icon:SetExtent(iconSize, iconSize)
    tracker.icon:AddAnchor("CENTER", tracker.window, 0, 0)
    tracker.icon:SetVisible(true)

    tracker.gradeIcon = tracker.window:CreateIconDrawable("artwork")
    tracker.gradeIcon:SetExtent(iconSize, iconSize)
    tracker.gradeIcon:AddAnchor("CENTER", tracker.window, 0, 0)
    tracker.gradeIcon:SetVisible(true)

    tracker.expiredOverlay = tracker.window:CreateIconDrawable("artwork")
    tracker.expiredOverlay:SetExtent(iconSize, iconSize)
    tracker.expiredOverlay:AddAnchor("CENTER", tracker.window, 0, 0)
    tracker.expiredOverlay:SetVisible(true)
    tracker.expiredOverlay:AddTexture(ExpiredTexture)

    tracker.window:AddAnchor("CENTER", "UIParent", xOffset, yOffset)

    trackers[slotId] = tracker
    return tracker
end

local function InitializeTracker(tracker, slotId)
    local currentItem = X2Equipment:GetEquippedItemTooltipInfo(slotId, false)
    if currentItem then
        tracker.icon:ClearAllTextures()
        tracker.icon:AddTexture(currentItem.icon)
        tracker.currentIcon = currentItem.icon

        tracker.gradeIcon:ClearAllTextures()
        tracker.gradeIcon:AddTexture(currentItem.gradeIcon)
        tracker.currentGradeIcon = currentItem.gradeIcon

        tracker.expiredOverlay:ClearAllTextures()
        tracker.expiredOverlay:AddTexture(ExpiredTexture)
    else
        tracker.icon:ClearAllTextures()
        tracker.currentIcon = nil

        tracker.gradeIcon:ClearAllTextures()
        tracker.currentGradeIcon = nil

        tracker.expiredOverlay:ClearAllTextures()
    end
end

local function UpdateTracker(tracker, slotId)
    local currentItem = X2Equipment:GetEquippedItemTooltipInfo(slotId, false)
    if currentItem then
        if currentItem.icon ~= tracker.currentIcon then
            tracker.icon:ClearAllTextures()
            tracker.icon:AddTexture(currentItem.icon)
            tracker.currentIcon = currentItem.icon
        end

        if currentItem.gradeIcon ~= tracker.currentGradeIcon then
            tracker.gradeIcon:ClearAllTextures()
            tracker.gradeIcon:AddTexture(currentItem.gradeIcon)
            tracker.currentGradeIcon = currentItem.gradeIcon
        end

        tracker.expiredOverlay:ClearAllTextures()
        tracker.expiredOverlay:AddTexture(ExpiredTexture)
    else
        if tracker.currentIcon ~= nil then
            tracker.icon:ClearAllTextures()
            tracker.currentIcon = nil
        end

        if tracker.currentGradeIcon ~= nil then
            tracker.gradeIcon:ClearAllTextures()
            tracker.currentGradeIcon = nil
        end

        tracker.expiredOverlay:ClearAllTextures()
    end
end

local function OnEquipmentChanged(...)
    UpdateTracker(trackers[ES_COSPLAY], ES_COSPLAY)
    UpdateTracker(trackers[ES_UNDERPANTS], ES_UNDERPANTS)
end

local function CheckEquipmentTime(slotId)
    local tooltipInfo = X2Equipment:GetEquippedItemTooltipInfo(slotId, false)
    if tooltipInfo and tooltipInfo.evolvingInfo and tooltipInfo.evolvingInfo.remainTime then
        local remainTime = tooltipInfo.evolvingInfo.remainTime
        if remainTime.year == 0 and remainTime.month == 0 and remainTime.day == 0 and
            remainTime.minute == 0 and remainTime.hour == 0 and remainTime.second == 0 then
            trackers[slotId].window:Show(true)
        else
            trackers[slotId].window:Show(false)
        end
    else
        trackers[slotId].window:Show(false)
    end
end

local function CreateNoBuffDetectedWindow()
    local window = CreateEmptyWindow("NoBlessingDetected", "UIParent")   
    window:AddAnchor("CENTER", "UIParent", 0, -400)    

    local text = window:CreateChildWidget("label", "noBuffText", 0, false)
    text:SetHeight(20)
    text.style:SetFontSize(40)
    text:AddAnchor("CENTER", window, 0, -15)
    text.style:SetAlign(ALIGN_CENTER)
    text.style:SetColor(255, 0, 0, 255)
    text:SetText("No Statue Buff Detected") 
    return window
end

local function CheckBlessingStatus()
    if noBuffDetectedCooldown <= 0 then
        local player = "player"
        local buffCount = X2Unit:UnitBuffCount(player)
        local hasBlessing = false
        for i = 1, buffCount do
            local buff = X2Unit:UnitBuffTooltip(player, i)
            if buff and buff.name and (string.find(buff.name, "Intense Blessing") or string.find(buff.name, "Steadfast Blessing")) then
                hasBlessing = true
                break
            end
        end

        if not hasBlessing then
            if not noBuffDetectedWindow then
                noBuffDetectedWindow = CreateNoBuffDetectedWindow()
            end
            if not noBuffDetectedWindow:IsVisible() then
                noBuffDetectedWindow:Show(true)
                isNotificationVisible = true
                notificationTimer = 0
            end
        elseif noBuffDetectedWindow and noBuffDetectedWindow:IsVisible() then
            noBuffDetectedWindow:Show(false)
            isNotificationVisible = false
            notificationTimer = 0
        end
    else
        noBuffDetectedCooldown = noBuffDetectedCooldown - 1
    end

    if isNotificationVisible then
        notificationTimer = notificationTimer + 1
        if notificationTimer >= notificationDisplayTime then
            if noBuffDetectedWindow and noBuffDetectedWindow:IsVisible() then
                noBuffDetectedWindow:Show(false)
                noBuffDetectedCooldown = 50
                isNotificationVisible = false
                notificationTimer = 0
            end
        end
    end
end

function iconChecker:OnUpdate(dt)
    counter = counter + dt
    if counter >= 1 then
        CheckEquipmentTime(ES_COSPLAY)
        CheckEquipmentTime(ES_UNDERPANTS)
        CheckBlessingStatus()
        counter = 0
    end
end

iconChecker:SetHandler("OnUpdate", iconChecker.OnUpdate)

local function EnteredWorld()
    trackers[ES_COSPLAY] = CreateTracker(ES_COSPLAY, -30, -300)
    trackers[ES_UNDERPANTS] = CreateTracker(ES_UNDERPANTS, 30, -300)
    InitializeTracker(trackers[ES_COSPLAY], ES_COSPLAY)
    InitializeTracker(trackers[ES_UNDERPANTS], ES_UNDERPANTS)
    iconChecker:SetHandler("OnUpdate", iconChecker.OnUpdate)
end

UIParent:SetEventHandler(UIEVENT_TYPE.UNIT_EQUIPMENT_CHANGED, OnEquipmentChanged)
UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)