ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WEBBROWSER)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)
ADDON:ImportAPI(API_TYPE.STORE.id)
ADDON:ImportAPI(API_TYPE.ABILITY.id)
ADDON:ImportAPI(API_TYPE.AUCTION.id) 

local ADDON_VERSION = "1.6"

local localizedName = {}
local mainWindow = nil
local showButton = nil
local windowX = 800 
local windowY = 575 
local titleY = 10 
local titleFontSize = 25 
local subtitleFontSize = 15 
local savedPositions = {}
local filePath = "Foliot 1.5 Pos.txt"

local cooldownUpdater = CreateEmptyWindow("cooldownUpdater", "UIParent")
cooldownUpdater:Show(true)

local currentContinent = nil
local selectedFromZone = nil
local selectedToZone = nil
local fromZoneGroup = 22
local toZoneGroup = 8
local packRatio = {} 
local drawablePackNames = {}
local GOLD_ICON = "Addon/Folio105/Icones/gold.dds"
local SILVER_ICON = "Addon/Folio105/Icones/silver.dds"
local COPPER_ICON = "Addon/Folio105/Icones/copper.dds"

local drawablePackSalePriceComponents = {} 
local drawableResourceCostCurrencyComponents = {} 
local drawablePackCostCurrencyComponents = {} 
local drawableProfitCurrencyComponents = {} 

local drawableSeparatorLines = {}
local commerceSkill = 0
local buttonSize = 22
local maxFreshnessEnabled = false
local freshnessToggleButton = nil
local requestCooldown = 0
local cooldownDuration = 6
local cooldownStartTime = 0 
local refreshButton = nil
local countdownLabel = nil
local resourcePrices = {} 
local totalResourceCost = 0 
local profitLabel = nil 
local resourceCostLabel = nil 
local auctionRequestQueue = {} 
local auctionCooldown = 0 
local auctionCooldownDuration = 1.2 
local auctionStartTime = 0 
local isProcessingAuction = false 
local loadingLabel = nil 
local ellipsisState = 0 
local ellipsisTimer = 0 
local ELLIPSIS_INTERVAL = 500


local drawableResourceLabels = {} 

local freshnessMultipliers = {
    ["Luxury"] = 1.30,      
    ["Fine"] = 1.15,          
    ["Commercial"] = 1.05,   
    ["Preserved"] = 1.03,     
}

local comboBoxConfig = {
    triggerWidth = 160,
    triggerHeight = 30,
    maxVisibleOptions = 5,
    optionHeight = 30,
    fromZoneX = 370,          
    toZoneX = 610,           
    continentX = 105,     
    Y = -10      
}

local fromZoneComboBoxes = {}  
local toZoneComboBoxes = {}
local lastFromZoneForToZoneComboBox = {} 

local drawableNmyIcons = {}
local drawableNmyLabels = {}

local versionWindow = nil

local color = {
    normal = UIParent:GetFontColor("btn_df"),
    highlight = UIParent:GetFontColor("btn_ov"),
    pushed = UIParent:GetFontColor("btn_on"),
    disabled = UIParent:GetFontColor("btn_dis")
}

local buttonskin = {
    drawableType = "ninePart",
    path = "ui/common/default.dds",
    coordsKey = "btn",
    autoResize = true,
    fontColor = color,
    fontInset = {
        left = 11,
        right = 11,
        top = 0,
        bottom = 0,
    },
}

local function ApplyMouseHandlers(widget, handlers)
    for event, fn in pairs(handlers) do
        widget:SetHandler(event, fn)
    end
end

function CreateSkin(path, coordsKey, fontColor, inset)
    return {
        drawableType = "ninePart",
        path = path,
        coordsKey = coordsKey,
        autoResize = true,
        fontColor = fontColor or color,
        fontInset = inset or {left = 0, right = 0, top = 0, bottom = 0}
    }
end

function CreateActionButton(config)
    local btn = config.parent:CreateChildWidget("button", config.name, 1, true)
    btn:AddAnchor(config.anchor, config.anchorTarget, config.offsetX, config.offsetY)
    btn:SetText(config.text or "")
    if type(config.skin) == "string" then
        btn:SetStyle(config.skin)
    else
        ApplyButtonSkin(btn, config.skin)
    end
    ApplyMouseHandlers(btn, config.handlers or {})
    btn:SetExtent(config.width, config.height)
    return btn
end

local function SetButtonsEnabled(enabled)
    if freshnessToggleButton then
        freshnessToggleButton:Enable(enabled)
    end
    if refreshButton then
        refreshButton:Enable(enabled)
    end
    
    if Continent then
        Continent:Enable(enabled)
    end
    
    for _, comboBox in pairs(fromZoneComboBoxes) do
        if comboBox then
            comboBox:Enable(enabled)
        end
    end
    
    for _, comboBox in pairs(toZoneComboBoxes) do
        if comboBox then
            comboBox:Enable(enabled)
        end
    end
    
    if emptyFromZoneComboBox then
        emptyFromZoneComboBox:Enable(enabled)
    end
    if emptyToZoneComboBox then
        emptyToZoneComboBox:Enable(enabled)
    end
end

function cooldownUpdater:OnUpdate(dt)
    local currentTime = os.time()
    local elapsedTime = currentTime - cooldownStartTime
    local remainingTime = cooldownDuration - elapsedTime
        
    if remainingTime <= 0 then
        requestCooldown = 0
        SetButtonsEnabled(true)
        if countdownLabel then
            countdownLabel:Show(false)
        end
    end
        
    if countdownLabel then
        countdownLabel:SetText(tostring(math.ceil(remainingTime)))
    end
        
    if isProcessingAuction and #auctionRequestQueue > 0 then
        local auctionElapsed = currentTime - auctionStartTime
        if auctionElapsed >= auctionCooldownDuration then
            ProcessNextAuctionRequest()
        end
    end

    if loadingLabel then
        if isProcessingAuction and #auctionRequestQueue > 0 then
            if not loadingLabel:IsVisible() then
                loadingLabel:Show(true)
            end
            ellipsisTimer = ellipsisTimer + dt
            if ellipsisTimer >= ELLIPSIS_INTERVAL then
                ellipsisState = (ellipsisState % 3) + 1
                local ellipsisText = "Prices Are Loading"
                for i = 1, ellipsisState do
                    ellipsisText = ellipsisText .. "."
                end
                loadingLabel:SetText(ellipsisText)
                ellipsisTimer = 0
            end
        else
            if loadingLabel:IsVisible() then
                loadingLabel:Show(false)
            end
        end
    end
end

local function StartCooldown()
    requestCooldown = cooldownDuration 
    cooldownStartTime = os.time() 
    SetButtonsEnabled(false)
    
    if countdownLabel then
        countdownLabel:Show(true)
        countdownLabel:SetText(tostring(cooldownDuration)) 
    end
    
    cooldownUpdater:SetHandler("OnUpdate", cooldownUpdater.OnUpdate)
end

local function LoadSavedPositions()
    local file = io.open(filePath, "r")
    if file then
        for line in file:lines() do
            local name, x, y = line:match("([^,]+),(%d+),(%d+)")
            if name and x and y then
                savedPositions[name] = { x = tonumber(x), y = tonumber(y) }
            end
            
            local setting, value = line:match("([^,]+):([^,]+)")
            if setting == "maxFreshness" then
                maxFreshnessEnabled = (value == "true")
            end
        end
        file:close()
    end
end

local function SaveSettings()
    local file = io.open(filePath, "w")
    if file then
        for name, pos in pairs(savedPositions) do
            file:write(string.format("%s,%d,%d\n", name, pos.x, pos.y))
        end
        
        file:write(string.format("maxFreshness:%s\n", tostring(maxFreshnessEnabled)))
        
        file:close()
    end
end

local function SaveButtonPosition(name, x, y)
    savedPositions[name] = { x = x, y = y }
    SaveSettings()
end

local function GetUIScaleFactor()
    return UIParent:GetUIScale() or 1.0
end

local PROJECT = "FOLIO 2.0"
local CONTINENT_LABEL = "Continent:"
local ZONE_LABEL = "From Zone:"
local DESTINATION_LABEL = "To Zone:"

local function getLocalizedNames()
    localizedName.zoneGroupName = {}
    localizedName.continentName = {}

    local ProductionZoneGroups = X2Store:GetProductionZoneGroups()
    for k, v in pairs(ProductionZoneGroups) do
        local id = v.id or "unknown_id"
        localizedName.zoneGroupName[id] = v.zoneGroupName or "unknown"
        localizedName.continentName[id] = v.continentName or "unknown"
    end
end

local function getResourcesInfo(packName)
    local resourcesList = {} 
    
    if packName and string.find(packName, "Fertilizer Specialty") then
        local counts = Fertilizer_Specialty[1]
        local resources = Fertilizer_Specialty[2]
        
        for i=1, #counts do
            local resourceId = resources[i]
            for name, id in pairs(Resources) do
                if id[1] == resourceId then
                    table.insert(resourcesList, {count = counts[i], name = name, id = resourceId})
                    break
                end
            end
        end
        return resourcesList
    end
    
    local requiredResources = nil
    
    if Nuia_Specialty[packName] then 
        requiredResources = Nuia_Specialty[packName]
    elseif Haranya_Specialty[packName] then
        requiredResources = Haranya_Specialty[packName]
    elseif Auroria_Specialty[packName] then
        requiredResources = Auroria_Specialty[packName]
    end
    
    if requiredResources then
        local counts = requiredResources[1]
        local resourceIds = requiredResources[2]
        
        for i=1, #counts do
            local resourceId = resourceIds[i]
            for name, id in pairs(Resources) do
                if id[1] == resourceId then
                    table.insert(resourcesList, {count = counts[i], name = name, id = resourceId})
                    break
                end
            end
        end
    end
    return resourcesList
end

local function getFilteredSellNuiaOptions()
    local options = {}

    if selectedFromZone ~= 5 then 
        table.insert(options, { text = "Solzreed Peninsula", handler = function() 
            selectedToZone = 5
            toZoneGroup = 5
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end })
    end
    
    if selectedFromZone ~= 8 then 
        table.insert(options, { text = "Two Crowns", handler = function() 
            selectedToZone = 8
            toZoneGroup = 8
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end })
    end
    
    if selectedFromZone ~= 20 then 
        table.insert(options, { text = "Cinderstone Moor", handler = function() 
            selectedToZone = 20
            toZoneGroup = 20
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end })
    end
    
    return options
end

local function getFilteredSellHaranyaOptions()
    local options = {}
    
    if selectedFromZone ~= 4 then 
        table.insert(options, { text = "Solis Headlands", handler = function() 
            selectedToZone = 4
            toZoneGroup = 4
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end })
    end
    
    if selectedFromZone ~= 12 then 
        table.insert(options, { text = "Villanelle", handler = function() 
            selectedToZone = 12
            toZoneGroup = 12
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end })
    end
    
    if selectedFromZone ~= 17 then 
        table.insert(options, { text = "Ynystere", handler = function() 
            selectedToZone = 17
            toZoneGroup = 17
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end })
    end
    
    return options
end

local function getFilteredSellAuroriaOptions()
    local options = {}
    return options
end

local function GetCommerceSkill()
    local allAbilityInfos = X2Ability:GetAllMyActabilityInfos()
    if allAbilityInfos then
        for _, info in pairs(allAbilityInfos) do
            if info and info.name == "Commerce" then
                local points = info.point or 0
                local modifyPoints = info.modifyPoint or 0
                return points + modifyPoints
            end
        end
    end
    return 0
end

local function CalculatePrice(basePrice, demandRate, packName)
    local professionalBonus = 1 + (commerceSkill / 10000 * 0.05)
    local freshnessBonus = 1.0
    
    if maxFreshnessEnabled and packName then
        if toZoneGroup == 33 then 
            freshnessBonus = 1.30 
        else
            for packType, multiplier in pairs(freshnessMultipliers) do
                if string.find(packName, packType) then
                    freshnessBonus = multiplier
                    break
                end
            end
        end
    end
    
    local price = (basePrice * demandRate) * professionalBonus * freshnessBonus
    return math.floor(price)
end

local function ToggleMaxFreshness()
    maxFreshnessEnabled = not maxFreshnessEnabled
    
    if maxFreshnessEnabled then
        freshnessToggleButton:SetTextColor(0, 1, 0, 1) 
    else
        freshnessToggleButton:SetTextColor(color.normal[1], color.normal[2], color.normal[3], color.normal[4])
    end
    
    SaveSettings()
    
    if selectedFromZone and selectedToZone then
        checkPackRatio(fromZoneGroup, toZoneGroup)
    end
end

local function CopperToGSC(copper)
    local gold = math.floor(copper / 10000)
    copper = copper - gold * 10000
    local silver = math.floor(copper / 100)
    copper = copper - silver * 100
    return gold, silver, copper
end

local function GetPackPrice(toZoneGroup, packName)
    if toZoneGroup == 5 and SOLZREED_PRICE and SOLZREED_PRICE[packName] then
        return SOLZREED_PRICE[packName][1]
    elseif toZoneGroup == 8 and TWOCROWNS_PRICE and TWOCROWNS_PRICE[packName] then
        return TWOCROWNS_PRICE[packName][1]
    elseif toZoneGroup == 20 and CINDERSTONE_MOOR_PRICE and CINDERSTONE_MOOR_PRICE[packName] then
        return CINDERSTONE_MOOR_PRICE[packName][1]
    elseif toZoneGroup == 4 and SOLIS_HEADLANDS_PRICE and SOLIS_HEADLANDS_PRICE[packName] then
        return SOLIS_HEADLANDS_PRICE[packName][1]
    elseif toZoneGroup == 12 and VILLANELLE_PRICE and VILLANELLE_PRICE[packName] then
        return VILLANELLE_PRICE[packName][1]
    elseif toZoneGroup == 17 and YNYSTERE_PRICE and YNYSTERE_PRICE[packName] then
        return YNYSTERE_PRICE[packName][1]
    elseif toZoneGroup == 33 and HEEDMAR_PRICE and HEEDMAR_PRICE[packName] then
        return HEEDMAR_PRICE[packName][1]
    end
    return nil
end

local function createCurrencyDisplayWidgets(parent, baseName, idSuffix)
    local widgets = {}

    widgets.goldLabel = parent:CreateChildWidget("label", baseName .. "GoldLabel" .. idSuffix, 0, true)
    widgets.goldLabel:EnablePick(false)
    widgets.goldLabel.style:SetOutline(true)
    widgets.goldLabel.style:SetAlign(ALIGN_RIGHT)

    widgets.goldIcon = parent:CreateIconDrawable("artwork")
    widgets.goldIcon:SetExtent(16, 16)
    widgets.goldIcon:ClearAllTextures()
    widgets.goldIcon:AddTexture(GOLD_ICON)

    widgets.silverLabel = parent:CreateChildWidget("label", baseName .. "SilverLabel" .. idSuffix, 0, true)
    widgets.silverLabel:EnablePick(false)
    widgets.silverLabel.style:SetOutline(true)
    widgets.silverLabel.style:SetAlign(ALIGN_RIGHT)

    widgets.silverIcon = parent:CreateIconDrawable("artwork")
    widgets.silverIcon:SetExtent(16, 16)
    widgets.silverIcon:ClearAllTextures()
    widgets.silverIcon:AddTexture(SILVER_ICON)

    widgets.copperLabel = parent:CreateChildWidget("label", baseName .. "CopperLabel" .. idSuffix, 0, true)
    widgets.copperLabel:EnablePick(false)
    widgets.copperLabel.style:SetOutline(true)
    widgets.copperLabel.style:SetAlign(ALIGN_RIGHT)

    widgets.copperIcon = parent:CreateIconDrawable("artwork")
    widgets.copperIcon:SetExtent(16, 16)
    widgets.copperIcon:ClearAllTextures()
    widgets.copperIcon:AddTexture(COPPER_ICON)

    return widgets
end

local function positionAndDisplayCurrency(parent, displayWidgets, xOffset, yOffset, gold, silver, copper, rightAlign)
    local valueSpacing = 25 
    local iconSpacing = 5   
    local iconWidth = 16    
    local labelWidths = {}  

    displayWidgets.goldLabel:Show(false)
    displayWidgets.goldIcon:SetVisible(false)
    displayWidgets.silverLabel:Show(false)
    displayWidgets.silverIcon:SetVisible(false)
    displayWidgets.copperLabel:Show(false)
    displayWidgets.copperIcon:SetVisible(false)

    if gold == 0 and silver == 0 and copper == 0 then
        return
    end

    if gold > 0 then
        displayWidgets.goldLabel:SetText(string.format("%d", gold))
        labelWidths.gold = displayWidgets.goldLabel:GetWidth()
    end
    if silver > 0 then
        displayWidgets.silverLabel:SetText(string.format("%d", silver))
        labelWidths.silver = displayWidgets.silverLabel:GetWidth()
    end
    if copper > 0 then
        displayWidgets.copperLabel:SetText(string.format("%d", copper))
        labelWidths.copper = displayWidgets.copperLabel:GetWidth()
    end

    local currentX = xOffset
    if rightAlign then
        local totalVisibleWidth = 0
        if gold > 0 then totalVisibleWidth = totalVisibleWidth + (labelWidths.gold or 0) + iconWidth + iconSpacing end
        if silver > 0 then totalVisibleWidth = totalVisibleWidth + (labelWidths.silver or 0) + iconWidth + iconSpacing end
        if copper > 0 then totalVisibleWidth = totalVisibleWidth + (labelWidths.copper or 0) + iconWidth + iconSpacing end

        if gold > 0 and (silver > 0 or copper > 0) then totalVisibleWidth = totalVisibleWidth + valueSpacing end
        if silver > 0 and copper > 0 then totalVisibleWidth = totalVisibleWidth + valueSpacing end

        currentX = xOffset - totalVisibleWidth
    end

    if gold > 0 then
        displayWidgets.goldLabel:AddAnchor("TOPLEFT", parent, currentX, yOffset)
        displayWidgets.goldLabel:Show(true)
        displayWidgets.goldIcon:AddAnchor("LEFT", displayWidgets.goldLabel, iconSpacing, 0)
        displayWidgets.goldIcon:SetVisible(true)
        currentX = currentX + (labelWidths.gold or 0) + iconWidth + iconSpacing
        if silver > 0 or copper > 0 then currentX = currentX + valueSpacing end
    end

    if silver > 0 then
        displayWidgets.silverLabel:AddAnchor("TOPLEFT", parent, currentX, yOffset)
        displayWidgets.silverLabel:Show(true)
        displayWidgets.silverIcon:AddAnchor("LEFT", displayWidgets.silverLabel, iconSpacing, 0)
        displayWidgets.silverIcon:SetVisible(true)
        currentX = currentX + (labelWidths.silver or 0) + iconWidth + iconSpacing
        if copper > 0 then currentX = currentX + valueSpacing end
    end

    if copper > 0 then
        displayWidgets.copperLabel:AddAnchor("TOPLEFT", parent, currentX, yOffset)
        displayWidgets.copperLabel:Show(true)
        displayWidgets.copperIcon:AddAnchor("LEFT", displayWidgets.copperLabel, iconSpacing, 0)
        displayWidgets.copperIcon:SetVisible(true)
    end
end


local function createSeparatorLine(w, id, suffix, yPosition, thickness)
    thickness = thickness or 2
    local line = w:CreateColorDrawable(0.55, 0.55, 0.90, 1, "artwork")
    line:SetExtent(windowX - 20, thickness) 
    line:AddAnchor("TOPLEFT", w, 10, yPosition) 
    line:SetVisible(true)
    return line
end

local function drawIcon(w, iconPath, id, xOffset, yOffset, ratio, packName)
    local displayedRatio = 0
    local isSpecialty = packName and string.find(packName, "Specialty") ~= nil
    local resourceLinesHeight = 0 
    local verticalAdjustOffset = 0

    if not selectedFromZone or not selectedToZone then
        if drawableNmyIcons[id] then drawableNmyIcons[id]:SetVisible(false) end
        if drawableNmyLabels[id] then drawableNmyLabels[id]:Show(false) end
        if drawablePackNames[id] then drawablePackNames[id]:Show(false) end
        
        if drawableResourceLabels[id] then
            for _, lbl in pairs(drawableResourceLabels[id]) do
                if lbl then lbl:Show(false) end
            end
        end
        
        if drawablePackSalePriceComponents[id] then
            drawablePackSalePriceComponents[id].goldLabel:Show(false)
            drawablePackSalePriceComponents[id].goldIcon:SetVisible(false)
            drawablePackSalePriceComponents[id].silverLabel:Show(false)
            drawablePackSalePriceComponents[id].silverIcon:SetVisible(false)
            drawablePackSalePriceComponents[id].copperLabel:Show(false)
            drawablePackSalePriceComponents[id].copperIcon:SetVisible(false)
        end
        if drawableResourceCostCurrencyComponents[id] then
            for i = 1, #drawableResourceCostCurrencyComponents[id] do
                local components = drawableResourceCostCurrencyComponents[id][i]
                if components then
                    components.goldLabel:Show(false)
                    components.goldIcon:SetVisible(false)
                    components.silverLabel:Show(false)
                    components.silverIcon:SetVisible(false)
                    components.copperLabel:Show(false)
                    components.copperIcon:SetVisible(false)
                end
            end
        end
        if drawablePackCostCurrencyComponents[id] then
            drawablePackCostCurrencyComponents[id].goldLabel:Show(false)
            drawablePackCostCurrencyComponents[id].goldIcon:SetVisible(false)
            drawablePackCostCurrencyComponents[id].silverLabel:Show(false)
            drawablePackCostCurrencyComponents[id].silverIcon:SetVisible(false)
            drawablePackCostCurrencyComponents[id].copperLabel:Show(false)
            drawablePackCostCurrencyComponents[id].copperIcon:SetVisible(false)
        end
        if drawableProfitCurrencyComponents[id] then
            drawableProfitCurrencyComponents[id].goldLabel:Show(false)
            drawableProfitCurrencyComponents[id].goldIcon:SetVisible(false)
            drawableProfitCurrencyComponents[id].silverLabel:Show(false)
            drawableProfitCurrencyComponents[id].silverIcon:SetVisible(false)
            drawableProfitCurrencyComponents[id].copperLabel:Show(false)
            drawableProfitCurrencyComponents[id].copperIcon:SetVisible(false)
        end

        if drawableSeparatorLines[id] then
            if drawableSeparatorLines[id].top then drawableSeparatorLines[id].top:SetVisible(false) end
            if drawableSeparatorLines[id].bottom then drawableSeparatorLines[id].bottom:SetVisible(false) end
        end
        return 0 
    end
    
    local basePrice = GetPackPrice(toZoneGroup, packName)
    local calculatedPrice = nil
    
    if basePrice then
        calculatedPrice = CalculatePrice(basePrice, ratio, packName) 
    end
    
    local function applyRatioColor(label, ratio)
        if ratio >= 130 then
            label.style:SetColor(0, 1, 0, 1.0)
        elseif ratio >= 125 then
            label.style:SetColor(0.4, 1, 0, 1.0)
        elseif ratio >= 120 then
            label.style:SetColor(0.7, 1, 0, 1.0)
        elseif ratio >= 115 then
            label.style:SetColor(1, 1, 0, 1.0)
        elseif ratio >= 110 then
            label.style:SetColor(1, 0.7, 0, 1.0)
        elseif ratio >= 105 then
            label.style:SetColor(1, 0.5, 0, 1.0)
        else
            label.style:SetColor(1, 0, 0, 1.0)
        end
        
        return string.format("%s%%", ratio)
    end
    
    local totalResourceCostPerPack = 0
    local resourcesList = getResourcesInfo(packName)
    local individualResourceCosts = {}

    if isSpecialty then
        verticalAdjustOffset = -10 
        if resourcesList then 
            for _, resource in ipairs(resourcesList) do
                local price = resourcePrices[resource.name] or 0 
                local cost = resource.count * price
                totalResourceCostPerPack = totalResourceCostPerPack + cost
                table.insert(individualResourceCosts, {name = resource.name, count = resource.count, cost = cost})
            end
        end
    end

    local profitPerPack = calculatedPrice - totalResourceCostPerPack

    if drawableNmyIcons[id] ~= nil then
        drawableNmyIcons[id]:SetVisible(true)
        drawableNmyLabels[id]:Show(true)
        
        if drawablePackNames[id] then drawablePackNames[id]:Show(true) end
        
        if isSpecialty then 
            if drawableResourceLabels[id] then
                for i = #resourcesList + 1, #drawableResourceLabels[id] do
                    if drawableResourceLabels[id][i] then drawableResourceLabels[id][i]:Show(false) end
                end
            end
            drawableResourceLabels[id] = drawableResourceLabels[id] or {}
            
            if drawableResourceCostCurrencyComponents[id] then
                for i = #resourcesList + 1, #drawableResourceCostCurrencyComponents[id] do
                    local components = drawableResourceCostCurrencyComponents[id][i]
                    if components then
                        components.goldLabel:Show(false)
                        components.goldIcon:SetVisible(false)
                        components.silverLabel:Show(false)
                        components.silverIcon:SetVisible(false)
                        components.copperLabel:Show(false)
                        components.copperIcon:SetVisible(false)
                    end
                end
            end

            drawableResourceCostCurrencyComponents[id] = drawableResourceCostCurrencyComponents[id] or {}
            for i, resource in ipairs(resourcesList) do
                if not drawableResourceCostCurrencyComponents[id][i] then
                    drawableResourceCostCurrencyComponents[id][i] = createCurrencyDisplayWidgets(w, "resourceCost", id .. "_" .. i)
                    drawableResourceCostCurrencyComponents[id][i].goldLabel.style:SetFontSize(12)
                    drawableResourceCostCurrencyComponents[id][i].silverLabel.style:SetFontSize(12)
                    drawableResourceCostCurrencyComponents[id][i].copperLabel.style:SetFontSize(12)
                    drawableResourceCostCurrencyComponents[id][i].goldLabel.style:SetColor(1, 0.5, 0, 1.0) 
                    drawableResourceCostCurrencyComponents[id][i].silverLabel.style:SetColor(1, 0.5, 0, 1.0)
                    drawableResourceCostCurrencyComponents[id][i].copperLabel.style:SetColor(1, 0.5, 0, 1.0)
                end
            end
        else
            if drawableResourceLabels[id] then
                for _, lbl in pairs(drawableResourceLabels[id]) do
                    if lbl then lbl:Show(false) end
                end
            end
            if drawableResourceCostCurrencyComponents[id] then
                for _, components in pairs(drawableResourceCostCurrencyComponents[id]) do
                    if components then
                        components.goldLabel:Show(false)
                        components.goldIcon:SetVisible(false)
                        components.silverLabel:Show(false)
                        components.silverIcon:SetVisible(false)
                        components.copperLabel:Show(false)
                        components.copperIcon:SetVisible(false)
                    end
                end
            end
        end
        
        if drawablePackSalePriceComponents[id] and calculatedPrice then
            drawablePackSalePriceComponents[id].goldLabel:Show(true)
            drawablePackSalePriceComponents[id].goldIcon:SetVisible(true)
            drawablePackSalePriceComponents[id].silverLabel:Show(true)
            drawablePackSalePriceComponents[id].silverIcon:SetVisible(true)
            drawablePackSalePriceComponents[id].copperLabel:Show(true)
            drawablePackSalePriceComponents[id].copperIcon:SetVisible(true)
        else
            if drawablePackSalePriceComponents[id] then
                drawablePackSalePriceComponents[id].goldLabel:Show(false)
                drawablePackSalePriceComponents[id].goldIcon:SetVisible(false)
                drawablePackSalePriceComponents[id].silverLabel:Show(false)
                drawablePackSalePriceComponents[id].silverIcon:SetVisible(false)
                drawablePackSalePriceComponents[id].copperLabel:Show(false)
                drawablePackSalePriceComponents[id].copperIcon:SetVisible(false)
            end
        end

        if isSpecialty then
            if drawablePackCostCurrencyComponents[id] then
                drawablePackCostCurrencyComponents[id].goldLabel:Show(false)
                drawablePackCostCurrencyComponents[id].goldIcon:SetVisible(false)
                drawablePackCostCurrencyComponents[id].silverLabel:Show(false)
                drawablePackCostCurrencyComponents[id].silverIcon:SetVisible(false)
                drawablePackCostCurrencyComponents[id].copperLabel:Show(false)
                drawablePackCostCurrencyComponents[id].copperIcon:SetVisible(false)
            end
            if drawableProfitCurrencyComponents[id] then
                drawableProfitCurrencyComponents[id].goldLabel:Show(false)
                drawableProfitCurrencyComponents[id].goldIcon:SetVisible(false)
                drawableProfitCurrencyComponents[id].silverLabel:Show(false)
                drawableProfitCurrencyComponents[id].silverIcon:SetVisible(false)
                drawableProfitCurrencyComponents[id].copperLabel:Show(false)
                drawableProfitCurrencyComponents[id].copperIcon:SetVisible(false)
            end
        end
        
        if drawableSeparatorLines[id] then
            if drawableSeparatorLines[id].top then 
                drawableSeparatorLines[id].top:SetVisible(true) 
            end
            if drawableSeparatorLines[id].bottom then 
                drawableSeparatorLines[id].bottom:SetVisible(true) 
            end
        end
    else
        local drawableIcon = w:CreateIconDrawable("artwork")
        drawableIcon:SetExtent(35, 35)
        drawableIcon:ClearAllTextures()
        drawableIcon:AddTexture(iconPath)
        drawableIcon:SetVisible(true)
        drawableNmyIcons[id] = drawableIcon
        
        local lblRatio = w:CreateChildWidget("label", "lblRatio"..id, 0, true)
        lblRatio:Show(true)
        lblRatio:EnablePick(false)
        lblRatio.style:SetOutline(true)
        lblRatio.style:SetAlign(ALIGN_RIGHT)
        drawableNmyLabels[id] = lblRatio
        
        local lblPackName = w:CreateChildWidget("label", "lblPackName"..id, 0, true)
        lblPackName:Show(true)
        lblPackName:EnablePick(false)
        lblPackName.style:SetOutline(true)
        lblPackName.style:SetAlign(ALIGN_LEFT)
        lblPackName:SetText(packName or "")
        lblPackName.style:SetFontSize(15) 
        drawablePackNames[id] = lblPackName
        
        drawablePackSalePriceComponents[id] = createCurrencyDisplayWidgets(w, "packSalePrice", id)
        drawablePackSalePriceComponents[id].goldLabel.style:SetFontSize(15)
        drawablePackSalePriceComponents[id].silverLabel.style:SetFontSize(15)
        drawablePackSalePriceComponents[id].copperLabel.style:SetFontSize(15)
        
        if isSpecialty then 
            drawableResourceLabels[id] = {} 
            drawableResourceCostCurrencyComponents[id] = {}
            for i, resource in ipairs(resourcesList) do
                local lblResources = w:CreateChildWidget("label", "lblResources"..id.."_"..i, 0, true)
                lblResources:Show(true)
                lblResources:EnablePick(false)
                lblResources.style:SetOutline(true)
                lblResources.style:SetAlign(ALIGN_LEFT)
                lblResources.style:SetFontSize(12)
                lblResources.style:SetColor(0.7, 0.7, 1.0, 1.0)
                lblResources:SetText(resource.count .. "x " .. resource.name)
                drawableResourceLabels[id][i] = lblResources

                drawableResourceCostCurrencyComponents[id][i] = createCurrencyDisplayWidgets(w, "resourceCost", id .. "_" .. i)
                drawableResourceCostCurrencyComponents[id][i].goldLabel.style:SetFontSize(12)
                drawableResourceCostCurrencyComponents[id][i].silverLabel.style:SetFontSize(12)
                drawableResourceCostCurrencyComponents[id][i].copperLabel.style:SetFontSize(12)
                drawableResourceCostCurrencyComponents[id][i].goldLabel.style:SetColor(1, 0.5, 0, 1.0)
                drawableResourceCostCurrencyComponents[id][i].silverLabel.style:SetColor(1, 0.5, 0, 1.0)
                drawableResourceCostCurrencyComponents[id][i].copperLabel.style:SetColor(1, 0.5, 0, 1.0)
            end

            drawablePackCostCurrencyComponents[id] = createCurrencyDisplayWidgets(w, "totalPackCost", id)
            drawablePackCostCurrencyComponents[id].goldLabel.style:SetFontSize(12)
            drawablePackCostCurrencyComponents[id].silverLabel.style:SetFontSize(12)
            drawablePackCostCurrencyComponents[id].copperLabel.style:SetFontSize(12)
            drawablePackCostCurrencyComponents[id].goldLabel.style:SetColor(1, 0.5, 0, 1.0) 
            drawablePackCostCurrencyComponents[id].silverLabel.style:SetColor(1, 0.5, 0, 1.0)
            drawablePackCostCurrencyComponents[id].copperLabel.style:SetColor(1, 0.5, 0, 1.0)

            drawableProfitCurrencyComponents[id] = createCurrencyDisplayWidgets(w, "profit", id)
            drawableProfitCurrencyComponents[id].goldLabel.style:SetFontSize(12)
            drawableProfitCurrencyComponents[id].silverLabel.style:SetFontSize(12)
            drawableProfitCurrencyComponents[id].copperLabel.style:SetFontSize(12)
        end

        drawableSeparatorLines[id] = {}
        
        if id == 1 then
            drawableSeparatorLines[id].top = createSeparatorLine(w, id, "_top", yOffset - 10, 3)
        end
    end
    
    drawableNmyIcons[id]:AddAnchor("TOPLEFT", w, xOffset, yOffset)
    
    drawablePackNames[id]:AddAnchor("TOPLEFT", w, xOffset + 50, yOffset + 7)
    drawableNmyLabels[id]:AddAnchor("TOPRIGHT", w, -50, yOffset + 10)
    
    local currentResourceY = yOffset + 30 
    
    packRatio[id].resourceLineYPositions = {}

    if isSpecialty and resourcesList then
        for i, resource in ipairs(resourcesList) do
            drawableResourceLabels[id][i]:AddAnchor("TOPLEFT", w, xOffset + 50, currentResourceY)
            drawableResourceLabels[id][i]:SetText(resource.count .. "x " .. resource.name)
            drawableResourceLabels[id][i]:Show(true)

            if drawableResourceCostCurrencyComponents[id] and drawableResourceCostCurrencyComponents[id][i] then
                local resGold, resSilver, resCopper = CopperToGSC(individualResourceCosts[i].cost)
                positionAndDisplayCurrency(w, drawableResourceCostCurrencyComponents[id][i], 450, currentResourceY, resGold, resSilver, resCopper, true)
            end
            packRatio[id].resourceLineYPositions[i] = currentResourceY 
            currentResourceY = currentResourceY + 15 
        end
        resourceLinesHeight = (#resourcesList * 15) 
    end
    
    displayedRatio = applyRatioColor(drawableNmyLabels[id], ratio)
    drawableNmyLabels[id]:SetText(displayedRatio)
    
    if calculatedPrice and drawablePackSalePriceComponents[id] then
        local packGold, packSilver, packCopper = CopperToGSC(calculatedPrice)
        local targetX = w:GetWidth() - 120 
        local targetY = yOffset + 10      
        positionAndDisplayCurrency(w, drawablePackSalePriceComponents[id], targetX, targetY, packGold, packSilver, packCopper, true)
    end

    if isSpecialty then
        local packCostGold, packCostSilver, packCostCopper = CopperToGSC(totalResourceCostPerPack)
        if drawablePackCostCurrencyComponents[id] then
            positionAndDisplayCurrency(w, drawablePackCostCurrencyComponents[id], 680, currentResourceY + verticalAdjustOffset, packCostGold, packCostSilver, packCostCopper, true)
        end
        packRatio[id].packCostYPosition = currentResourceY + verticalAdjustOffset 
        currentResourceY = currentResourceY + 15

        local profitGold, profitSilver, profitCopper = CopperToGSC(profitPerPack)
        if drawableProfitCurrencyComponents[id] then

            if profitPerPack >= 0 then
                drawableProfitCurrencyComponents[id].goldLabel.style:SetColor(0, 1, 0, 1.0) 
                drawableProfitCurrencyComponents[id].silverLabel.style:SetColor(0, 1, 0, 1.0)
                drawableProfitCurrencyComponents[id].copperLabel.style:SetColor(0, 1, 0, 1.0)
            else
                drawableProfitCurrencyComponents[id].goldLabel.style:SetColor(1, 0, 0, 1.0) 
                drawableProfitCurrencyComponents[id].silverLabel.style:SetColor(1, 0, 0, 1.0)
                drawableProfitCurrencyComponents[id].copperLabel.style:SetColor(1, 0, 0, 1.0)
            end
            positionAndDisplayCurrency(w, drawableProfitCurrencyComponents[id], 680, currentResourceY + verticalAdjustOffset, math.abs(profitGold), math.abs(profitSilver), math.abs(profitCopper), true)
        end
        packRatio[id].profitYPosition = currentResourceY + verticalAdjustOffset 
        currentResourceY = currentResourceY + 15
    end
    
    local bottomY = yOffset + 40 + resourceLinesHeight + (isSpecialty and 10 or 0) 
    if drawableSeparatorLines[id].bottom then
        drawableSeparatorLines[id].bottom:SetVisible(true)
        drawableSeparatorLines[id].bottom:AddAnchor("TOPLEFT", w, 10, bottomY - 5)
    else
        drawableSeparatorLines[id].bottom = createSeparatorLine(w, id, "_bottom", bottomY - 5)
    end
    
    return resourceLinesHeight + (isSpecialty and 10 or 0) 
end

local function resetZoneSelectionsAndDisplays()
    selectedFromZone = nil
    selectedToZone = nil
    fromZoneGroup = nil
    toZoneGroup = nil
    lastFromZoneForToZoneComboBox = {} 

    packRatio = {}
    for k, v in pairs(drawableNmyIcons) do if v then v:SetVisible(false) end drawableNmyIcons[k] = nil end
    for k, v in pairs(drawableNmyLabels) do if v then v:Show(false) end drawableNmyLabels[k] = nil end
    for k, v in pairs(drawablePackNames) do if v then v:Show(false) end drawablePackNames[k] = nil end
    
    for k, v in pairs(drawableResourceLabels) do
        if v then
            for _, lbl in pairs(v) do
                if lbl then lbl:Show(false) end 
            end
        end
        drawableResourceLabels[k] = nil 
    end
    
    for k, components in pairs(drawablePackSalePriceComponents) do
        if components then
            components.goldLabel:Show(false) components.goldIcon:SetVisible(false)
            components.silverLabel:Show(false) components.silverIcon:SetVisible(false)
            components.copperLabel:Show(false) components.copperIcon:SetVisible(false)
        end
        drawablePackSalePriceComponents[k] = nil
    end

    for k, resourceComps in pairs(drawableResourceCostCurrencyComponents) do
        if resourceComps then
            for _, components in pairs(resourceComps) do
                if components then
                    components.goldLabel:Show(false) components.goldIcon:SetVisible(false)
                    components.silverLabel:Show(false) components.silverIcon:SetVisible(false)
                    components.copperLabel:Show(false) components.copperIcon:SetVisible(false)
                end
            end
        end
        drawableResourceCostCurrencyComponents[k] = nil
    end

    for k, components in pairs(drawablePackCostCurrencyComponents) do
        if components then
            components.goldLabel:Show(false) components.goldIcon:SetVisible(false)
            components.silverLabel:Show(false) components.silverIcon:SetVisible(false)
            components.copperLabel:Show(false) components.copperIcon:SetVisible(false)
        end
        drawablePackCostCurrencyComponents[k] = nil
    end

    for k, components in pairs(drawableProfitCurrencyComponents) do
        if components then
            components.goldLabel:Show(false) components.goldIcon:SetVisible(false)
            components.silverLabel:Show(false) components.silverIcon:SetVisible(false)
            components.copperLabel:Show(false) components.copperIcon:SetVisible(false)
        end
        drawableProfitCurrencyComponents[k] = nil
    end

    for k, v in pairs(drawableSeparatorLines) do 
        if v then 
            if v.top then v.top:SetVisible(false) end
            if v.bottom then v.bottom:SetVisible(false) end
        end 
        drawableSeparatorLines[k] = nil 
    end

    if emptyFromZoneComboBox then
        emptyFromZoneComboBox:SetText("") 
        emptyFromZoneComboBox:Show(true) 
    end
    if emptyToZoneComboBox then
        emptyToZoneComboBox:SetText("") 
        emptyToZoneComboBox:Show(true) 
    end

    for _, cb in pairs(fromZoneComboBoxes) do
        if cb then
            cb:SetText("")  
        end
    end
    for _, cb in pairs(toZoneComboBoxes) do
        if cb then
            cb:SetText("")  
        end
    end

    if resourceCostLabel then resourceCostLabel:Show(false) end
    if profitLabel then profitLabel:Show(false) end
end

function ProcessNextAuctionRequest()
    if #auctionRequestQueue == 0 then
        isProcessingAuction = false
        if loadingLabel then loadingLabel:Show(false) end 
        return
    end
    local request = table.remove(auctionRequestQueue, 1)
    X2Auction:SearchAuctionArticle(request.grade, 0, 999, 1, 0, false, request.name, "0", "0")
    auctionStartTime = os.time()
end

function StartAuctionRequests(resourceList)
    auctionRequestQueue = {}
    resourcePrices = {} 
        
    for _, resource in ipairs(resourceList) do
        table.insert(auctionRequestQueue, {name = resource.name, grade = 1}) 
    end
        
    if #auctionRequestQueue > 0 then
        isProcessingAuction = true
        if loadingLabel then loadingLabel:Show(true) end 
        ProcessNextAuctionRequest()
    else
        isProcessingAuction = false
        if loadingLabel then loadingLabel:Show(false) end
    end
end

function OnAuctionItemSearched()
    local count = X2Auction:GetSearchedItemCount()
        
    if count > 0 then
        local itemInfo = X2Auction:GetSearchedItemInfo(1)
        local unitPrice = tonumber(itemInfo.bidPriceStr) or 0 
        resourcePrices[itemInfo.name] = unitPrice

        if mainWindow and mainWindow:IsVisible() then
            for k, packData in pairs(packRatio) do
                local packName = packData.itemInfo.name
                local isSpecialty = packName and string.find(packName, "Specialty") ~= nil
                local verticalAdjustOffset = isSpecialty and -10 or 0 

                if isSpecialty then
                    local resourcesList = getResourcesInfo(packName)
                    local foundResourceInPack = false
                    for _, resource in ipairs(resourcesList) do
                        if resource.name == itemInfo.name then
                            foundResourceInPack = true
                            break
                        end
                    end

                    if foundResourceInPack then
                        local totalResourceCostPerPack = 0
                        local individualResourceCosts = {}
                        
                        for _, resource in ipairs(resourcesList) do
                            local price = resourcePrices[resource.name] or 0
                            local cost = resource.count * price
                            totalResourceCostPerPack = totalResourceCostPerPack + cost
                            table.insert(individualResourceCosts, {name = resource.name, count = resource.count, cost = cost})
                        end
                        
                        local basePrice = GetPackPrice(toZoneGroup, packName)
                        local calculatedPrice = nil
                        if basePrice then
                            calculatedPrice = CalculatePrice(basePrice, packData.ratio, packName)
                        end
                        local profitPerPack = calculatedPrice - totalResourceCostPerPack
                        
                        if drawableResourceCostCurrencyComponents[k] then
                            for i, resource in ipairs(resourcesList) do
                                if drawableResourceCostCurrencyComponents[k][i] and packData.resourceLineYPositions and packData.resourceLineYPositions[i] then
                                    local resGold, resSilver, resCopper = CopperToGSC(individualResourceCosts[i].cost)
                                    positionAndDisplayCurrency(mainWindow, drawableResourceCostCurrencyComponents[k][i], 450, packData.resourceLineYPositions[i], resGold, resSilver, resCopper, true)
                                end
                            end
                        end
                        
                        if drawablePackCostCurrencyComponents[k] and packData.packCostYPosition then
                            local packCostGold, packCostSilver, packCostCopper = CopperToGSC(totalResourceCostPerPack)
                            positionAndDisplayCurrency(mainWindow, drawablePackCostCurrencyComponents[k], 680, packData.packCostYPosition, packCostGold, packCostSilver, packCostCopper, true)
                        end
                        
                        if drawableProfitCurrencyComponents[k] and packData.profitYPosition then
                            local profitGold, profitSilver, profitCopper = CopperToGSC(profitPerPack)

                            if profitPerPack >= 0 then
                                drawableProfitCurrencyComponents[k].goldLabel.style:SetColor(0, 1, 0, 1.0)
                                drawableProfitCurrencyComponents[k].silverLabel.style:SetColor(0, 1, 0, 1.0)
                                drawableProfitCurrencyComponents[k].copperLabel.style:SetColor(0, 1, 0, 1.0)
                            else
                                drawableProfitCurrencyComponents[k].goldLabel.style:SetColor(1, 0, 0, 1.0)
                                drawableProfitCurrencyComponents[k].silverLabel.style:SetColor(1, 0, 0, 1.0)
                                drawableProfitCurrencyComponents[k].copperLabel.style:SetColor(1, 0, 0, 1.0)
                            end
                            positionAndDisplayCurrency(mainWindow, drawableProfitCurrencyComponents[k], 680, packData.profitYPosition, math.abs(profitGold), math.abs(profitSilver), math.abs(profitCopper), true)
                        end
                    end
                end
            end
        end
    end
end

function UpdateWindowHeight()
    local packCount = 0
    local totalExtraHeight = 0 
    local basePackHeight = 40 
    local resourceLineHeight = 15 
    local perPackExtraHeight = 10 

    for k, v in pairs(packRatio) do
        packCount = packCount + 1
        local packName = v.itemInfo.name
        local isSpecialty = packName and string.find(packName, "Specialty") ~= nil

        if isSpecialty then
            local resourcesList = getResourcesInfo(packName)
            totalExtraHeight = totalExtraHeight + (#resourcesList * resourceLineHeight) 
            totalExtraHeight = totalExtraHeight + perPackExtraHeight 
        end
    end

    local newHeight = 150 + (packCount * basePackHeight) + totalExtraHeight 
    mainWindow:SetExtent(windowX, newHeight)
end

local function CreateVersionWindow()
    if versionWindow then
        return versionWindow
    end

    versionWindow = CreateEmptyWindow("folio105VersionWindow", "UIParent")
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
    
    local webbrowser = UIParent:CreateWidget("webbrowser", "folio105_webbrowser", versionWindow)
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
        local addonName = "Folio%202.0"
        local url = string.format("https://archerageaddonmanager.github.io/addon-version-checker/?addon=%s&version=%s", 
                                 addonName, ADDON_VERSION)
        
        window.webbrowser:RequestExternalPage("about:blank")
        window.webbrowser:RequestExternalPage(url)
        window:Show(true)
    end
end

function CreateMainWindow()
    if mainWindow then return end
    
    mainWindow = CreateEmptyWindow("packRateWindow", "UIParent")
    mainWindow:SetExtent(windowX, windowY)
    mainWindow:AddAnchor("CENTER", "UIParent", 0, 0)
    mainWindow:EnableDrag(true)
    mainWindow:SetCloseOnEscape(true)

    function mainWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    mainWindow:SetHandler("OnDragStart", mainWindow.OnDragStart)

    function mainWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
    end
    mainWindow:SetHandler("OnDragStop", mainWindow.OnDragStop)

    local title = mainWindow:CreateChildWidget("label", "title", 0, false)
    title:SetHeight(30)
    title:SetText(PROJECT)
    title.style:SetFontSize(titleFontSize)
    title:AddAnchor("TOP", mainWindow, 0, titleY)
    title.style:SetAlign(ALIGN_CENTER)
    title.style:SetColorByKey("brown")

    local versionButton = CreateActionButton({
        parent = mainWindow,
        name = "version_button",
        anchor = "TOPRIGHT",
        anchorTarget = mainWindow,
        offsetX = -280,
        offsetY = 12,
        width = 25,
        height = 25,
        text = "?",
        skin = "text_default",
        handlers = {
            OnClick = function()
                CheckAddonVersion()
            end,
        },
    })
    versionButton:Show(true)

    loadingLabel = mainWindow:CreateChildWidget("label", "loadingLabel", 0, true)
    loadingLabel:AddAnchor("TOPLEFT", mainWindow, 20, 25)
    loadingLabel:SetText("Prices Are Loading")
    loadingLabel.style:SetFontSize(16)
    loadingLabel.style:SetColor(0, 1, 0, 1)
    loadingLabel.style:SetAlign(ALIGN_LEFT)
    loadingLabel.style:SetOutline(true)
    loadingLabel:Show(false) 

    local continentLabel = mainWindow:CreateChildWidget("label", "continentLabel", 0, false)
    continentLabel:SetText(CONTINENT_LABEL)
    continentLabel.style:SetFontSize(subtitleFontSize)
    continentLabel:AddAnchor("BOTTOMLEFT", mainWindow, 20, -25)
    continentLabel.style:SetAlign(ALIGN_LEFT)
    continentLabel.style:SetColorByKey("brown")
    local zoneLabel = mainWindow:CreateChildWidget("label", "zoneLabel", 0, false)
    zoneLabel:SetText(ZONE_LABEL)
    zoneLabel.style:SetFontSize(subtitleFontSize)
    zoneLabel:AddAnchor("BOTTOMLEFT", mainWindow, 280, -25)
    zoneLabel.style:SetAlign(ALIGN_LEFT)
    zoneLabel.style:SetColorByKey("brown")
    local destinationLabel = mainWindow:CreateChildWidget("label", "destinationLabel", 0, false)
    destinationLabel:SetText(DESTINATION_LABEL)
    destinationLabel.style:SetFontSize(subtitleFontSize)
    destinationLabel:AddAnchor("BOTTOMLEFT", mainWindow, 540, -25)
    destinationLabel.style:SetAlign(ALIGN_LEFT)
    destinationLabel.style:SetColorByKey("brown")

    resourceCostLabel = mainWindow:CreateChildWidget("label", "resourceCostLabel", 0, true)
    resourceCostLabel:Show(false)
    resourceCostLabel:EnablePick(false)
    resourceCostLabel.style:SetOutline(true)
    resourceCostLabel.style:SetAlign(ALIGN_LEFT)
    resourceCostLabel.style:SetFontSize(12)
    resourceCostLabel.style:SetColor(1, 0.5, 0, 1.0)
    resourceCostLabel:AddAnchor("TOPLEFT", mainWindow, 20, 40)
    
    profitLabel = mainWindow:CreateChildWidget("label", "profitLabel", 0, true)
    profitLabel:Show(false)
    profitLabel:EnablePick(false)
    profitLabel.style:SetOutline(true)
    profitLabel.style:SetAlign(ALIGN_LEFT)
    profitLabel.style:SetFontSize(12)
    profitLabel.style:SetColor(0, 1, 0, 1.0)
    profitLabel:AddAnchor("TOPLEFT", mainWindow, 20, 55)

    local closeButton = mainWindow:CreateChildWidget("button", "closeButton", 0, true)
    closeButton:SetStyle("text_default")
    closeButton:AddAnchor("TOPRIGHT", mainWindow, -10, 10)
    closeButton:Show(true)
    closeButton:SetText("X")
    closeButton:SetExtent(45, 30)
    
    function closeButton:OnClick()
        mainWindow:Show(false)
    end
    closeButton:SetHandler("OnClick", closeButton.OnClick)

    local resetskin = CreateSkin("ui/button/common/reset.dds", "reset")
    refreshButton = CreateActionButton({
        parent = mainWindow,
        name = "refresh",
        anchor = "TOPRIGHT",
        anchorTarget = mainWindow,
        offsetX = -190, 
        offsetY = 11, 
        skin = resetskin,
        width = 28,
        height = 28,
        handlers = {
            OnClick = function()
                if selectedFromZone and selectedToZone and requestCooldown <= 0 then
                    checkPackRatio(fromZoneGroup, toZoneGroup)
                end
            end
        }
    })
    
    countdownLabel = mainWindow:CreateChildWidget("label", "countdownLabel", 0, true)
    countdownLabel:AddAnchor("RIGHT", refreshButton, -35, 0) 
    countdownLabel:Show(false)
    countdownLabel:SetText("5")
    countdownLabel.style:SetFontSize(16)
    countdownLabel.style:SetColor(1, 0, 0, 1) 
    countdownLabel.style:SetAlign(ALIGN_CENTER)
    countdownLabel.style:SetOutline(true)    

    freshnessToggleButton = mainWindow:CreateChildWidget("button", "freshnessToggleButton", 0, true)
    freshnessToggleButton:SetStyle("text_default")
    freshnessToggleButton:AddAnchor("TOPRIGHT", mainWindow, -60, 10)  
    freshnessToggleButton:Show(true)
    freshnessToggleButton:SetText("Max Freshness")
    freshnessToggleButton:SetExtent(120, 30)  
    
    function freshnessToggleButton:OnClick()
        ToggleMaxFreshness()
    end
    freshnessToggleButton:SetHandler("OnClick", freshnessToggleButton.OnClick)
    
    if maxFreshnessEnabled then
        freshnessToggleButton:SetTextColor(0, 1, 0, 1)
    else
        freshnessToggleButton:SetTextColor(color.normal[1], color.normal[2], color.normal[3], color.normal[4])
    end

    local function ShowComboBoxes(continent)
        for _, cb in pairs(fromZoneComboBoxes) do
            cb:Show(false)
            cb:SetText("") 
        end
        for _, cb in pairs(toZoneComboBoxes) do
            cb:Show(false)
            cb:SetText("") 
        end
        
        emptyFromZoneComboBox:Show(true)
        emptyFromZoneComboBox:SetText("") 
        emptyToZoneComboBox:Show(true)
        emptyToZoneComboBox:SetText("") 

        if fromZoneComboBoxes[continent] then
            fromZoneComboBoxes[continent]:AddAnchor("BOTTOMLEFT", mainWindow, comboBoxConfig.fromZoneX, comboBoxConfig.Y) 
            fromZoneComboBoxes[continent]:Show(true) 
            emptyFromZoneComboBox:Show(false) 

            if selectedFromZone then
                fromZoneComboBoxes[continent]:SetText(localizedName.zoneGroupName[selectedFromZone])
            else
                fromZoneComboBoxes[continent]:SetText("") 
            end
            
            if selectedFromZone then 
                local filteredOptions = {}
                local previousSelectedToZone = selectedToZone 

                if continent == "Nuia" then
                    filteredOptions = getFilteredSellNuiaOptions()
                elseif continent == "Haranya" then
                    filteredOptions = getFilteredSellHaranyaOptions()
                elseif continent == "Auroria" then
                    filteredOptions = getFilteredSellAuroriaOptions() 
                    selectedToZone = 33 
                    toZoneGroup = 33
                end
                
                if continent ~= "Auroria" then
                    if selectedFromZone == previousSelectedToZone then
                        selectedToZone = nil
                        toZoneGroup = nil
                    else
                        local isValidOldToZone = false
                        if previousSelectedToZone then
                            local oldToZoneName = localizedName.zoneGroupName[previousSelectedToZone]
                            for _, option in ipairs(filteredOptions) do
                                if option.text == oldToZoneName then
                                    isValidOldToZone = true
                                    break
                                end
                            end
                        end
                        if isValidOldToZone then
                            selectedToZone = previousSelectedToZone
                            toZoneGroup = previousSelectedToZone
                        else
                            selectedToZone = nil
                            toZoneGroup = nil
                        end
                    end
                end

                if not toZoneComboBoxes[continent] or lastFromZoneForToZoneComboBox[continent] ~= selectedFromZone then
                    if toZoneComboBoxes[continent] and toZoneComboBoxes[continent].Destroy then
                        toZoneComboBoxes[continent]:Destroy()
                    end
                    
                    toZoneComboBoxes[continent] = CreateComboBox(
                        mainWindow, 
                        comboBoxConfig.triggerWidth, 
                        comboBoxConfig.triggerHeight, 
                        comboBoxConfig.maxVisibleOptions, 
                        filteredOptions, 
                        comboBoxConfig.optionHeight,
                        "BOTTOMLEFT", 
                        mainWindow, 
                        comboBoxConfig.toZoneX, 
                        comboBoxConfig.Y 
                    )
                    lastFromZoneForToZoneComboBox[continent] = selectedFromZone 
                end
                
                toZoneComboBoxes[continent]:Show(true)
                toZoneComboBoxes[continent]:AddAnchor("BOTTOMLEFT", mainWindow, comboBoxConfig.toZoneX, comboBoxConfig.Y) 
                
                if continent == "Auroria" then
                    toZoneComboBoxes[continent]:SetText("Heedmar")
                elseif selectedToZone then
                    toZoneComboBoxes[continent]:SetText(localizedName.zoneGroupName[selectedToZone])
                else
                    toZoneComboBoxes[continent]:SetText("")
                end
                emptyToZoneComboBox:Show(false) 

                if selectedFromZone and selectedToZone then
                    checkPackRatio(fromZoneGroup, toZoneGroup)
                end
            else 
                if toZoneComboBoxes[continent] then toZoneComboBoxes[continent]:Show(false) end
            end
        end
    end

    local emptyOptions = {}

    local comboBox1Options = {
        { text = "Nuia", handler = function()
                if currentContinent ~= "Nuia" then
                    resetZoneSelectionsAndDisplays() 
                    currentContinent = "Nuia"
                    ShowComboBoxes("Nuia")
                end
            end },
        { text = "Haranya", handler = function()
                if currentContinent ~= "Haranya" then
                    resetZoneSelectionsAndDisplays() 
                    currentContinent = "Haranya"
                    ShowComboBoxes("Haranya")
                end
            end },
        { text = "Auroria", handler = function()
                if currentContinent ~= "Auroria" then
                    resetZoneSelectionsAndDisplays() 
                    currentContinent = "Auroria"
                    ShowComboBoxes("Auroria")
                end
            end }
    }

    local comboBox2Options = {
        { text = "Gweonid Forest", handler = function() 
            selectedFromZone = 1
            fromZoneGroup = 1
            ShowComboBoxes("Nuia")
        end },
        { text = "Marianople", handler = function() 
            selectedFromZone = 2
            fromZoneGroup = 2
            ShowComboBoxes("Nuia")
        end },
        { text = "Dewstone Plains", handler = function() 
            selectedFromZone = 3
            fromZoneGroup = 3
            ShowComboBoxes("Nuia")
        end },
        { text = "Solzreed Peninsula", handler = function() 
            selectedFromZone = 5
            fromZoneGroup = 5
            ShowComboBoxes("Nuia")
        end },
        { text = "Lilyut Hills", handler = function() 
            selectedFromZone = 6
            fromZoneGroup = 6
            ShowComboBoxes("Nuia")
        end },
        { text = "Two Crowns", handler = function() 
            selectedFromZone = 8
            fromZoneGroup = 8
            ShowComboBoxes("Nuia")
        end },
        { text = "Airain Rock", handler = function() 
            selectedFromZone = 10
            fromZoneGroup = 10
            ShowComboBoxes("Nuia")
        end },
        { text = "White Arden", handler = function() 
            selectedFromZone = 18
            fromZoneGroup = 18
            ShowComboBoxes("Nuia")
        end },
        { text = "Karkasse Ridgelands", handler = function() 
            selectedFromZone = 19
            fromZoneGroup = 19
            ShowComboBoxes("Nuia")
        end },
        { text = "Cinderstone Moor", handler = function() 
            selectedFromZone = 20
            fromZoneGroup = 20
            ShowComboBoxes("Nuia")
        end },
        { text = "Aubre Cradle", handler = function() 
            selectedFromZone = 21
            fromZoneGroup = 21
            ShowComboBoxes("Nuia")
        end },
        { text = "Halcyona", handler = function() 
            selectedFromZone = 22
            fromZoneGroup = 22
            ShowComboBoxes("Nuia")
        end },
        { text = "Hellswamp", handler = function() 
            selectedFromZone = 26
            fromZoneGroup = 26
            ShowComboBoxes("Nuia")
        end },
        { text = "Sanddeep", handler = function() 
            selectedFromZone = 27
            fromZoneGroup = 27
            ShowComboBoxes("Nuia")
        end },
        { text = "Ahnimar", handler = function() 
            selectedFromZone = 93
            fromZoneGroup = 93
            ShowComboBoxes("Nuia")
        end }
    }

    local comboBox3Options = {
        { text = "Solis Headlands", handler = function() 
            selectedFromZone = 4
            fromZoneGroup = 4
            ShowComboBoxes("Haranya")
        end },
        { text = "Arcum Iris", handler = function() 
            selectedFromZone = 7
            fromZoneGroup = 7
            ShowComboBoxes("Haranya")
        end },
        { text = "Mahadevi", handler = function() 
            selectedFromZone = 9
            fromZoneGroup = 9
            ShowComboBoxes("Haranya")
        end },
        { text = "Falcorth Plains", handler = function() 
            selectedFromZone = 11
            fromZoneGroup = 11
            ShowComboBoxes("Haranya")
        end },
        { text = "Villanelle", handler = function() 
            selectedFromZone = 12
            fromZoneGroup = 12
            ShowComboBoxes("Haranya")
        end },
        { text = "Sunbite Wilds", handler = function() 
            selectedFromZone = 13
            fromZoneGroup = 13
            ShowComboBoxes("Haranya")
        end },
        { text = "Windscour Savanna", handler = function() 
            selectedFromZone = 14
            fromZoneGroup = 14
            ShowComboBoxes("Haranya")
        end },
        { text = "Perinoor Ruins", handler = function() 
            selectedFromZone = 15
            fromZoneGroup = 15
            ShowComboBoxes("Haranya")
        end },
        { text = "Rookborne Basin", handler = function() 
            selectedFromZone = 16
            fromZoneGroup = 16
            ShowComboBoxes("Haranya")
        end },
        { text = "Ynystere", handler = function() 
            selectedFromZone = 17
            fromZoneGroup = 17
            ShowComboBoxes("Haranya")
        end },
        { text = "Hasla", handler = function() 
            selectedFromZone = 23
            fromZoneGroup = 23
            ShowComboBoxes("Haranya")
        end },
        { text = "Tigerspine Mountains", handler = function() 
            selectedFromZone = 24
            fromZoneGroup = 24
            ShowComboBoxes("Haranya")
        end },
        { text = "Silent Forest", handler = function() 
            selectedFromZone = 25
            fromZoneGroup = 25
            ShowComboBoxes("Haranya")
        end },
        { text = "Rokhala Mountains", handler = function() 
            selectedFromZone = 99
            fromZoneGroup = 99
            ShowComboBoxes("Haranya")
        end }
    }

    local comboBox4Options = {
        { text = "Exeloch", handler = function() 
            selectedFromZone = 54
            fromZoneGroup = 54
            ShowComboBoxes("Auroria")
        end },
        { text = "Sungold Fields", handler = function() 
            selectedFromZone = 56
            fromZoneGroup = 56
            ShowComboBoxes("Auroria")
        end },
        { text = "Golden Ruins", handler = function() 
            selectedFromZone = 57
            fromZoneGroup = 57
            ShowComboBoxes("Auroria")
        end },
        { text = "Aegis Island", handler = function() 
            selectedFromZone = 102
            fromZoneGroup = 102
            ShowComboBoxes("Auroria")
        end },
        { text = "Whalesong Harbor", handler = function() 
            selectedFromZone = 103
            fromZoneGroup = 103
            ShowComboBoxes("Auroria")
        end }
    }

    local sellNuiaOptions = {
        { text = "Solzreed Peninsula", handler = function() 
            selectedToZone = 5
            toZoneGroup = 5
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end },
        { text = "Two Crowns", handler = function() 
            selectedToZone = 8
            toZoneGroup = 8
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end },
        { text = "Cinderstone Moor", handler = function() 
            selectedToZone = 20
            toZoneGroup = 20
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end }
    }

    local sellHaranyaOptions = {
        { text = "Solis Headlands", handler = function() 
            selectedToZone = 4
            toZoneGroup = 4
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end },
        { text = "Villanelle", handler = function() 
            selectedToZone = 12
            toZoneGroup = 12
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end },
        { text = "Ynystere", handler = function() 
            selectedToZone = 17
            toZoneGroup = 17
            if selectedFromZone then
                checkPackRatio(fromZoneGroup, toZoneGroup)
            end
        end }
    }

    Continent = CreateComboBox(
        mainWindow, 
        comboBoxConfig.triggerWidth, 
        comboBoxConfig.triggerHeight, 
        comboBoxConfig.maxVisibleOptions, 
        comboBox1Options, 
        comboBoxConfig.optionHeight,
        "BOTTOMLEFT", 
        mainWindow, 
        comboBoxConfig.continentX, 
        comboBoxConfig.Y 
    )

    emptyFromZoneComboBox = CreateComboBox(
        mainWindow, 
        comboBoxConfig.triggerWidth, 
        comboBoxConfig.triggerHeight, 
        comboBoxConfig.maxVisibleOptions, 
        emptyOptions, 
        comboBoxConfig.optionHeight,
        "BOTTOMLEFT", 
        mainWindow, 
        comboBoxConfig.fromZoneX, 
        comboBoxConfig.Y
    )

    emptyToZoneComboBox = CreateComboBox(
        mainWindow, 
        comboBoxConfig.triggerWidth, 
        comboBoxConfig.triggerHeight, 
        comboBoxConfig.maxVisibleOptions, 
        emptyOptions, 
        comboBoxConfig.optionHeight,
        "BOTTOMLEFT", 
        mainWindow, 
        comboBoxConfig.toZoneX, 
        comboBoxConfig.Y
    )

    fromZoneComboBoxes["Nuia"] = CreateComboBox(
        mainWindow, 
        comboBoxConfig.triggerWidth, 
        comboBoxConfig.triggerHeight, 
        comboBoxConfig.maxVisibleOptions, 
        comboBox2Options, 
        comboBoxConfig.optionHeight,
        "BOTTOMLEFT", 
        mainWindow, 
        0, 0  
    )
    fromZoneComboBoxes["Nuia"]:Show(false)

    fromZoneComboBoxes["Haranya"] = CreateComboBox(
        mainWindow, 
        comboBoxConfig.triggerWidth, 
        comboBoxConfig.triggerHeight, 
        comboBoxConfig.maxVisibleOptions, 
        comboBox3Options, 
        comboBoxConfig.optionHeight,
        "BOTTOMLEFT", 
        mainWindow, 
        0, 0 
    )
    fromZoneComboBoxes["Haranya"]:Show(false)

    fromZoneComboBoxes["Auroria"] = CreateComboBox(
        mainWindow, 
        comboBoxConfig.triggerWidth, 
        comboBoxConfig.triggerHeight, 
        comboBoxConfig.maxVisibleOptions, 
        comboBox4Options, 
        comboBoxConfig.optionHeight,
        "BOTTOMLEFT", 
        mainWindow, 
        0, 0
    )
    fromZoneComboBoxes["Auroria"]:Show(false)

    toZoneComboBoxes["Nuia"] = CreateComboBox(
        mainWindow, 
        comboBoxConfig.triggerWidth, 
        comboBoxConfig.triggerHeight, 
        comboBoxConfig.maxVisibleOptions, 
        sellNuiaOptions, 
        comboBoxConfig.optionHeight,
        "BOTTOMLEFT", 
        mainWindow, 
        0, 0
    )
    toZoneComboBoxes["Nuia"]:Show(false)

    toZoneComboBoxes["Haranya"] = CreateComboBox(
        mainWindow, 
        comboBoxConfig.triggerWidth, 
        comboBoxConfig.triggerHeight, 
        comboBoxConfig.maxVisibleOptions, 
        sellHaranyaOptions, 
        comboBoxConfig.optionHeight,
        "BOTTOMLEFT", 
        mainWindow, 
        0, 0
    )
    toZoneComboBoxes["Haranya"]:Show(false)

    Nuia = fromZoneComboBoxes["Nuia"]
    Haranya = fromZoneComboBoxes["Haranya"]
    Auroria = fromZoneComboBoxes["Auroria"]
    Sell_Nuia = toZoneComboBoxes["Nuia"]
    Sell_Haranya = toZoneComboBoxes["Haranya"]

    function mainWindow:OnShow()
        if self:IsVisible() then
            Continent:Show(true)
            if currentContinent then
                ShowComboBoxes(currentContinent)
            end
        end
        SettingWindowSkin(mainWindow)
        mainWindow:SetStartAnimation(true, true)        
    end
    mainWindow:SetHandler("OnShow", mainWindow.OnShow)
 
    return mainWindow
end

local function CreateToggleButton()
    if showButton then return end

    showButton = UIParent:CreateWidget("button", "packRateToggle", "UIParent")
    showButton:SetExtent(buttonSize, buttonSize)
    showButton:SetText("")
    showButton:Show(true)
    showButton:EnableDrag(true)

    local iconOverlay = showButton:CreateIconDrawable("artwork")
    iconOverlay:SetExtent(buttonSize, buttonSize)
    iconOverlay:AddAnchor("CENTER", showButton, 0, 0)
    iconOverlay:SetVisible(true)
    iconOverlay:AddTexture("Addon/Folio105/Icones/Main.dds")
    showButton.iconOverlay = iconOverlay    

    local hoverOverlay = showButton:CreateIconDrawable("artwork")
    hoverOverlay:AddTexture("Addon/Folio105/Icones/Main hoverOverlay.dds")
    hoverOverlay:SetExtent(buttonSize, buttonSize)
    hoverOverlay:AddAnchor("CENTER", showButton, 0, 0) 
    hoverOverlay:SetVisible(false) 
    showButton.hoverOverlay = hoverOverlay

    local OnClicOverlay = showButton:CreateIconDrawable("artwork")
    OnClicOverlay:AddTexture("Addon/Folio105/Icones/Main OnClic.dds")
    OnClicOverlay:SetExtent(buttonSize, buttonSize)
    OnClicOverlay:AddAnchor("CENTER", showButton, 0, 0) 
    OnClicOverlay:SetVisible(false) 
    showButton.OnClicOverlay = OnClicOverlay

    local Tooltip = showButton:CreateChildWidget("label", "Tooltip", 0, true)
    Tooltip:SetHeight(30)
    Tooltip:SetAutoResize(true)
    local Tooltipbackground = Tooltip:CreateNinePartDrawable("ui/common/hud.dds", "background")
    Tooltipbackground:SetCoords(733, 169, 14, 15) 
    Tooltipbackground:SetInset(7, 7, 6, 7)
    Tooltipbackground:AddAnchor("TOPLEFT", Tooltip, -10, 0)
    Tooltipbackground:AddAnchor("BOTTOMRIGHT", Tooltip, 10, 0)
    Tooltip:SetText(PROJECT)
    Tooltip.style:SetAlign(ALIGN_CENTER)
    Tooltip.style:SetColorByKey("brown")
    Tooltip.style:SetFontSize(12) 
    Tooltip:AddAnchor("TOPLEFT", showButton, -70, -30)
    Tooltip:Show(false)
    showButton.Tooltip = Tooltip    

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
                self.OnClicOverlay:SetVisible(false) 
            end    
            if self.Tooltip then 
                self.Tooltip:Show(false)
            end                            
        end,
    }

    ApplyMouseHandlers(showButton, mouseHandlers) 
    if savedPositions["packRateToggle"] then
        local uiScale = GetUIScaleFactor()
        local scaledX = savedPositions["packRateToggle"].x / uiScale
        local scaledY = savedPositions["packRateToggle"].y / uiScale
        showButton:AddAnchor("TOPLEFT", "UIParent", scaledX, scaledY)
    else
        showButton:AddAnchor("CENTER", "UIParent", 0, 0)
    end

    function showButton:OnClick()
        if not mainWindow then
            CreateMainWindow()
        else
            mainWindow:Show(not mainWindow:IsVisible())
        end
    end
    showButton:SetHandler("OnClick", showButton.OnClick)

    function showButton:OnMouseDown()
        if self.OnClicOverlay then
            self.OnClicOverlay:SetVisible(true) 
        end    
    end
    showButton:SetHandler("OnMouseDown", showButton.OnMouseDown)

    function showButton:OnMouseUp()
        if self.OnClicOverlay then
            self.OnClicOverlay:SetVisible(false) 
        end    
    end
    showButton:SetHandler("OnMouseUp", showButton.OnMouseUp)    

    function showButton:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    showButton:SetHandler("OnDragStart", showButton.OnDragStart)

    function showButton:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
        local correctedX, correctedY = self:CorrectOffsetByScreen()
        SaveButtonPosition("packRateToggle", correctedX, correctedY)
    end
    showButton:SetHandler("OnDragStop", showButton.OnDragStop)
end

function checkPackRatio(fromZoneGroup, toZoneGroup)
    if not selectedFromZone or not selectedToZone then
        return
    end
    
    if requestCooldown > 0 then
        return
    end
    
    commerceSkill = GetCommerceSkill()
    
    packRatio = {}  
    for k, v in pairs(drawableNmyIcons) do
        if v then
            v:SetVisible(false)
        end
        drawableNmyIcons[k] = nil
    end
    for k, v in pairs(drawableNmyLabels) do
        if v then
            v:Show(false)
        end
        drawableNmyLabels[k] = nil
    end
    for k, v in pairs(drawablePackNames) do
        if v then
            v:Show(false)
        end
        drawablePackNames[k] = nil
    end
    
    for k, v in pairs(drawableResourceLabels) do
        if v then
            for _, lbl in pairs(v) do
                if lbl then lbl:Show(false) end
            end
        end
        drawableResourceLabels[k] = nil
    end
    
    for k, components in pairs(drawablePackSalePriceComponents) do
        if components then
            components.goldLabel:Show(false) components.goldIcon:SetVisible(false)
            components.silverLabel:Show(false) components.silverIcon:SetVisible(false)
            components.copperLabel:Show(false) components.copperIcon:SetVisible(false)
        end
        drawablePackSalePriceComponents[k] = nil
    end

    for k, resourceComps in pairs(drawableResourceCostCurrencyComponents) do
        if resourceComps then
            for _, components in pairs(resourceComps) do
                if components then
                    components.goldLabel:Show(false) components.goldIcon:SetVisible(false)
                    components.silverLabel:Show(false) components.silverIcon:SetVisible(false)
                    components.copperLabel:Show(false) components.copperIcon:SetVisible(false)
                end
            end
        end
        drawableResourceCostCurrencyComponents[k] = nil
    end

    for k, components in pairs(drawablePackCostCurrencyComponents) do
        if components then
            components.goldLabel:Show(false) components.goldIcon:SetVisible(false)
            components.silverLabel:Show(false) components.silverIcon:SetVisible(false)
            components.copperLabel:Show(false) components.copperIcon:SetVisible(false)
        end
        drawablePackCostCurrencyComponents[k] = nil
    end

    for k, components in pairs(drawableProfitCurrencyComponents) do
        if components then
            components.goldLabel:Show(false) components.goldIcon:SetVisible(false)
            components.silverLabel:Show(false) components.silverIcon:SetVisible(false)
            components.copperLabel:Show(false) components.copperIcon:SetVisible(false)
        end
        drawableProfitCurrencyComponents[k] = nil
    end
    
    for k, v in pairs(drawableSeparatorLines) do
        if v then
            if v.top then
                v.top:SetVisible(false)
            end
            if v.bottom then
                v.bottom:SetVisible(false)
            end
        end
        drawableSeparatorLines[k] = nil
    end

    if resourceCostLabel then resourceCostLabel:Show(false) end
    if profitLabel then profitLabel:Show(false) end
    
    StartCooldown()
    
    local success = X2Store:GetSpecialtyRatioBetween(fromZoneGroup, toZoneGroup)
    if not success then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "Request not sent successfully")
        requestCooldown = 0
        SetButtonsEnabled(true)
        if countdownLabel then
            countdownLabel:Show(false)
        end
    end
end

local function SendRatioToChat(RatioTable)
    if not RatioTable or type(RatioTable) ~= "table" then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "Return data is missing")
        return 
    end
    packRatio = RatioTable
    PriceUpdate()
end
UIParent:SetEventHandler(UIEVENT_TYPE.SPECIALTY_RATIO_BETWEEN_INFO, SendRatioToChat)

function PriceUpdate()
    if mainWindow and mainWindow:IsVisible() then
        local packCounter = 0
        local verticalSpacing = 40                   
        local startY = 80  
        local startX = 20                  
        
        for k, v in pairs(packRatio) do
            local yPos = startY + (verticalSpacing * packCounter)
            v.currentYPos = yPos 

            local extraSpace = drawIcon(mainWindow, v.itemInfo.icon, k, startX, yPos, v.ratio, v.itemInfo.name)
            packCounter = packCounter + 1
                        
            if extraSpace > 0 then
                packCounter = packCounter + (extraSpace / verticalSpacing)
            end
        end
                
        UpdateWindowHeight()
                
        StartAuctionRequestsForCurrentPacks()    
    end
end

function StartAuctionRequestsForCurrentPacks()
    local resourceList = {}
        
    for k, v in pairs(packRatio) do 
        local packName = v.itemInfo.name 
        local isSpecialty = packName and string.find(packName, "Specialty") ~= nil
        if isSpecialty then 
            local resourcesInfoList = getResourcesInfo(packName) 
            if resourcesInfoList and #resourcesInfoList > 0 then
                for _, resource in ipairs(resourcesInfoList) do
                    local found = false
                    for _, existing in ipairs(resourceList) do
                        if existing.name == resource.name then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(resourceList, {name = resource.name, grade = 1}) 
                    end
                end
            end
        end
    end
        
    if #resourceList > 0 then
        StartAuctionRequests(resourceList)
    else
        isProcessingAuction = false
        if loadingLabel then loadingLabel:Show(false) end
    end
end

local function EnteredWorld()
    LoadSavedPositions()  
    getLocalizedNames()
    commerceSkill = GetCommerceSkill() 
    CreateToggleButton()
    CreateMainWindow()
    cooldownUpdater:SetHandler("OnUpdate", cooldownUpdater.OnUpdate)
end

UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)

UIParent:SetEventHandler(UIEVENT_TYPE.AUCTION_ITEM_SEARCHED, OnAuctionItemSearched)