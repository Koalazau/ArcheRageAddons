ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)
ADDON:ImportAPI(API_TYPE.RESIDENT.id)
ADDON:ImportAPI(API_TYPE.MAP.id)

local toggleButton = nil
local tradeListWindow = nil
local windowX = 800
local windowY = 475
local titleY = 10
local titleFontSize = 25
local pageNumFontSize = 15
local subtitleFontSize = 15
local subtitleDist = 80
local KINDX = 250
local NAMEX = 20
local PEICEX = 680

local savedPositions = {}
local filePath = "tradelistbuttonpos.txt"

local SELLERNAME = "出售人"
local TRADELIST = "房屋出售清单"
local SELLPRICE = "出售价格"
local HOUSETYPE = "房屋类型(房屋大小)"
local SEARCHTRADELIST = "查询房价"
local LOADED = "成功加载房价查询插件,作者：奈奈呀\n点击按钮以开始查询房价 拖动按钮保存位置"
local NO_HOUSES_AVAILABLE = "此区域无可出售的房屋"
local SELECT_ZONE_MESSAGE = "选择大陆和区域开始"
local SELECT_ZONE_CONTINUE = "选择区域以继续"
local CONTINENT_LABEL = "大陆:"
local ZONE_LABEL = "区域:"
local HOUSETYPE_LABEL = "户型"
local REFRESH_COUNTDOWN_LABEL = "刷新时间：%d 秒"
local REFRESHING_LABEL = "清爽..."
local INITIALIZING_LABEL = "正在初始化..."
local CONTINENT_NUIA = "诺伊大陆"
local CONTINENT_HARANYA = "哈里拉特大陆"
local CONTINENT_AURORIA = "原大陆"
local ALL_SIZES = "全部"
local TIMEOUT_MESSAGE = "区域 %d 超时，第 %d/%d 次尝试"
local REFRESH_FAILED_MESSAGE = "列表刷新失败"


local language = X2Locale:GetLocale() or "en_us"
if language ~= "zh_cn" and language ~= "ru" then
    SELLERNAME = "Seller Name"
    TRADELIST = "Housing Trade List"
    SELLPRICE = "Price"
    HOUSETYPE = "House type(House Size)"
    SEARCHTRADELIST = "House List"
    LOADED = "Loaded Housing Tradelist Finder. Author:Nevermore"
    NO_HOUSES_AVAILABLE = "No Sellable house Available on this zone"
    SELECT_ZONE_MESSAGE = "Select Continent and Zone to start"
    SELECT_ZONE_CONTINUE = "Select Zone to continue"
    CONTINENT_LABEL = "Continent:"
    ZONE_LABEL = "Zone:"
    HOUSETYPE_LABEL = "House Type:"
    REFRESH_COUNTDOWN_LABEL = "Refreshing in: %d s"
    REFRESHING_LABEL = "Refreshing..."
    INITIALIZING_LABEL = "Initializing..."  
    CONTINENT_NUIA = "Nuia"
    CONTINENT_HARANYA = "Haranya"
    CONTINENT_AURORIA = "Auroria" 
    ALL_SIZES = "All"   
    TIMEOUT_MESSAGE = "Timeout zone %d, attempt %d/%d"
    REFRESH_FAILED_MESSAGE = "Failed to refresh the list"       
elseif language == "ru" then
    SELLERNAME = "Имя продавца"
    TRADELIST = "Список домов для продажи"
    SELLPRICE = "Цена продажи"
    HOUSETYPE = "Тип дома (размер дома)"
    SEARCHTRADELIST = "Цены на жилье"
    LOADED = "Плагин Цены на жилье успешно загружен. Автор: Nevermore"
    NO_HOUSES_AVAILABLE = "Нет доступных для продажи домов в этой зоне"
    SELECT_ZONE_MESSAGE = "Выберите континент и зону для начала"
    SELECT_ZONE_CONTINUE = "Выберите зону для продолжения"
    CONTINENT_LABEL = "Континент:"
    ZONE_LABEL = "Зона:"
    HOUSETYPE_LABEL = "Тип дома:"
    REFRESH_COUNTDOWN_LABEL = "Обновление через: %d с"
    REFRESHING_LABEL = "Обновление..."
    INITIALIZING_LABEL = "Инициализация..."
    CONTINENT_NUIA = "Западный материк"
    CONTINENT_HARANYA = "Восточный материк"
    CONTINENT_AURORIA = "Изначальный материк"     
    ALL_SIZES = "Все"
    TIMEOUT_MESSAGE = "Тайм-аут зоны %d, попытка %d/%d"
    REFRESH_FAILED_MESSAGE = "Не удалось обновить список"       
end

local currentPageNum = 1
local maxPageNum = 1
local index = 0
local hasSearched = false
local list = {}

local cachedTradeLists = {}
local allZoneIds = {
    1, 2, 3, 5, 6, 8, 10, 18, 19, 20, 21, 22, 26, 27, 93,
    4, 7, 9, 11, 12, 13, 14, 15, 16, 17, 23, 24, 25, 99, 
    54, 56, 57, 102, 103, 61 
}
local lastHousingDataRefreshTime = 0
local HOUSING_DATA_REFRESH_INTERVAL = 90
local housingRequestQueue = {}
local isRequestingHousingData = false
local currentRequestingZoneId = nil

local selectedZoneId = nil

local tradeInfoName = {}
local tradeInfoKind = {}
local tradeInfoPrice = {}
local goldIcon = {}
local noHousesMessage = nil
local selectZoneMessage = nil
local isFirstContinentSelection = true
local page = nil
local countdownLabelHousing = nil
local isFirstRefresh = true 
local houseSizeFilter = nil

local REQUEST_TIMEOUT = 10 
local MAX_RETRY_ATTEMPTS = 3
local currentRetryCount = 0
local requestStartTime = 0
local isWaitingForResponse = false
local hasFailedToRefresh = false

local color = {}
    color.normal    = UIParent:GetFontColor("btn_df")
    color.highlight = UIParent:GetFontColor("btn_ov")
    color.pushed    = UIParent:GetFontColor("btn_on")
    color.disabled  = UIParent:GetFontColor("btn_dis")

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

local function GetUIScaleFactor()
    return UIParent:GetUIScale() or 1
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

local function ApplyMouseHandlers(widget, handlers)
    for event, fn in pairs(handlers) do
        widget:SetHandler(event, fn)
    end
end

local function UpdateNavigationVisibility()
    if not tradeListWindow then return end

    local showNav = (maxPageNum > 1)

    if tradeListWindow.firstPageButton then
        tradeListWindow.firstPageButton:Show(showNav)
    end

    if tradeListWindow.prePageButton then
        tradeListWindow.prePageButton:Show(showNav)
    end

    if tradeListWindow.nextPageButton then
        tradeListWindow.nextPageButton:Show(showNav)
    end

    if tradeListWindow.lastPageButton then
        tradeListWindow.lastPageButton:Show(showNav)
    end

    if tradeListWindow.firstPageButton then
        tradeListWindow.firstPageButton:Enable(currentPageNum > 1)
    end

    if tradeListWindow.prePageButton then
        tradeListWindow.prePageButton:Enable(currentPageNum > 1)
    end

    if tradeListWindow.nextPageButton then
        tradeListWindow.nextPageButton:Enable(currentPageNum < maxPageNum)
    end

    if tradeListWindow.lastPageButton then
        tradeListWindow.lastPageButton:Enable(currentPageNum < maxPageNum)
    end
end

local refreshtimer = CreateEmptyWindow("refreshtimer", "UIParent")
refreshtimer:Show(true)
refreshtimer:Enable(true)

local function formatPrice(price)
    local priceStr = tostring(price)
    local formatted = ""
    local len = string.len(priceStr)
    
    for i = 1, len do
        formatted = formatted .. string.sub(priceStr, i, i)
        if (len - i) % 3 == 0 and i ~= len then
            formatted = formatted .. " "
        end
    end
    
    return formatted
end

local function getZoneNameById(zoneId)
    local stateInfo = {X2Map:GetZoneStateInfoByZoneId(zoneId)}
    if type(stateInfo[1]) == "table" and stateInfo[1].zoneName then
        return stateInfo[1].zoneName
    else
        return "Unknown Zone"
    end
end

local function getHouseSizeFilteredList(size)
    local filteredList = {}
    
    for zoneId, tradeList in pairs(cachedTradeLists) do
        for _, item in pairs(tradeList) do
            if size == "All" or (item.division and item.division:match("(%d+)") == size) then
                local newItem = {}
                for k, v in pairs(item) do
                    newItem[k] = v
                end
                newItem.zoneName = getZoneNameById(zoneId) 
                table.insert(filteredList, newItem)
            end
        end
    end
    
    table.sort(filteredList, function(a, b)
        if not a.price or not b.price then return false end
        return a.price < b.price
    end)
    
    return filteredList
end

local function adjustLayoutForHouseSizeFilter()
    if not tradeListWindow then return end
    
    local offset = houseSizeFilter and 80 or 0
    
    if tradeListWindow.kindLable then
        tradeListWindow.kindLable:RemoveAllAnchors()
        tradeListWindow.kindLable:AddAnchor("TOPLEFT", tradeListWindow, KINDX + offset, subtitleDist)
    end
    
    for i = 1, 10 do
        if tradeInfoKind[i] then
            tradeInfoKind[i]:RemoveAllAnchors()
            tradeInfoKind[i]:AddAnchor("TOPLEFT", tradeListWindow, KINDX + offset, 100+(i - 1) * 25)
        end
    end
end

local function displayCachedTradeList()
    currentPageNum = 1
    index = 0
    
    local currentList = nil
    
    if houseSizeFilter then
        currentList = getHouseSizeFilteredList(houseSizeFilter)
        hasSearched = true
    elseif selectedZoneId and cachedTradeLists[selectedZoneId] then
        currentList = cachedTradeLists[selectedZoneId]
        hasSearched = true
    else
        hasSearched = false
        if tradeListWindow then
            if selectZoneMessage then selectZoneMessage:Show(true); end
            if noHousesMessage then noHousesMessage:Show(false); end
            if page then page:Show(false); end
            for i = 1, 10 do
                if tradeInfoName[i] then
                    tradeInfoName[i]:SetText("")
                    tradeInfoKind[i]:SetText("")
                    tradeInfoPrice[i]:SetText("")
                    goldIcon[i]:SetVisible(false)
                end
            end
        end
        UpdateNavigationVisibility()
        return
    end

    list = currentList
    maxPageNum = math.ceil(#list / 10)

    if tradeListWindow then
        if selectZoneMessage then
            selectZoneMessage:Show(false)
        end

        if #list > 0 then
            if page then
                page:Show(true)
            end
            if noHousesMessage then
                noHousesMessage:Show(false)
            end
        else
            if page then
                page:Show(false)
            end
            if noHousesMessage then
                noHousesMessage:Show(true)
            end
        end
        UpdateNavigationVisibility()
    end
    refreshtimer:OnUpdate(0)
    adjustLayoutForHouseSizeFilter()
end

local function processNextHousingRequest()
    if #housingRequestQueue > 0 then
        currentRequestingZoneId = table.remove(housingRequestQueue, 1)
        requestStartTime = os.time()
        isWaitingForResponse = true
        X2Resident:RequestHousingTradeList(currentRequestingZoneId, 1, "")
    else
        isRequestingHousingData = false
        currentRequestingZoneId = nil
        isWaitingForResponse = false
        currentRetryCount = 0
        hasFailedToRefresh = false
        if tradeListWindow and tradeListWindow:IsVisible() and selectedZoneId then
            displayCachedTradeList()
        end
    end
end

local function requestAllHousingData()
    if isRequestingHousingData then
        return
    end

    lastHousingDataRefreshTime = os.time()
    cachedTradeLists = {}
    housingRequestQueue = {}
    currentRetryCount = 0
    hasFailedToRefresh = false

    for _, zoneId in ipairs(allZoneIds) do
        table.insert(housingRequestQueue, zoneId)
    end

    isRequestingHousingData = true
    processNextHousingRequest()
end

local function tradeList(receivedTradeList)
    local zoneIdHandled = currentRequestingZoneId
    isWaitingForResponse = false

    if not receivedTradeList or type(receivedTradeList) ~= "table" then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "aucune table trouvée pour la zone " .. tostring(zoneIdHandled or "N/A"))
        processNextHousingRequest()
        return
    end

    if zoneIdHandled then
        local validList = {}
        for _, v in pairs(receivedTradeList) do
            if v.price then
                v.price = tonumber(v.price)
            end
            if type(v.price) == "number" and v.kind and v.sellername then
                table.insert(validList, v)
            end
        end
        table.sort(validList, function(a, b)
            if not a.price or not b.price then return false end
            return a.price < b.price
        end)
        cachedTradeLists[zoneIdHandled] = validList

        if selectedZoneId == zoneIdHandled then
            displayCachedTradeList()
        end
    end

    processNextHousingRequest()
end

UIParent:SetEventHandler(UIEVENT_TYPE.RESIDENT_HOUSING_TRADE_LIST, tradeList)

local currentContinent = nil

local function resetSearchState()
    hasSearched = false
    currentPageNum = 0
    maxPageNum = 0
    index = 0
    selectedZoneId = nil

    if page then page:Show(false); end

    if tradeListWindow then
        if selectZoneMessage then
            selectZoneMessage:Show(true)
            if isFirstContinentSelection then
                selectZoneMessage:SetText(SELECT_ZONE_MESSAGE)
            else
                selectZoneMessage:SetText(SELECT_ZONE_CONTINUE)
            end
        end
        if noHousesMessage then noHousesMessage:Show(false); end
        if tradeListWindow.page then tradeListWindow.page:Show(false); end
        UpdateNavigationVisibility()
    end
end

local function ToggleTradeListWindow()
    if tradeListWindow then return end

    tradeListWindow = CreateEmptyWindow("tradeListWindow", "UIParent")
    tradeListWindow:SetExtent(windowX, windowY)
    tradeListWindow:AddAnchor("CENTER", "UIParent", 0,0)
    tradeListWindow:EnableDrag(true)
    tradeListWindow:SetCloseOnEscape(true)
    local function OnShow()
        if tradeListWindow.ShowProc ~= nil then
            tradeListWindow:ShowProc()
        end
        SettingWindowSkin(tradeListWindow)
        tradeListWindow:SetStartAnimation(true, true)
    end
    tradeListWindow:SetHandler("OnShow", OnShow)

    function tradeListWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    tradeListWindow:SetHandler("OnDragStart", tradeListWindow.OnDragStart)

    function tradeListWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
    end
    tradeListWindow:SetHandler("OnDragStop", tradeListWindow.OnDragStop)

    local someTitle = tradeListWindow:CreateChildWidget("label", "someTitle", 0, false)
    someTitle:SetHeight(30)
    someTitle:SetText(TRADELIST)
    someTitle.style:SetFontSize(titleFontSize)
    someTitle:AddAnchor("TOP", tradeListWindow,0,titleY)
    someTitle.style:SetAlign(ALIGN_CENTER)
    someTitle.style:SetColorByKey("brown")

    local continentLabel = tradeListWindow:CreateChildWidget("label", "continentLabel", 0, false)
    continentLabel:SetText(CONTINENT_LABEL)
    continentLabel.style:SetFontSize(subtitleFontSize)
    continentLabel:AddAnchor("BOTTOMLEFT", tradeListWindow, 10, -35)
    continentLabel.style:SetAlign(ALIGN_LEFT)
    continentLabel.style:SetColorByKey("brown")

    local zoneLabel = tradeListWindow:CreateChildWidget("label", "zoneLabel", 0, false)
    zoneLabel:SetText(ZONE_LABEL)
    zoneLabel.style:SetFontSize(subtitleFontSize)
    zoneLabel:AddAnchor("BOTTOMRIGHT", tradeListWindow, -235, -35)
    zoneLabel.style:SetAlign(ALIGN_LEFT)
    zoneLabel.style:SetColorByKey("brown")

    local nameLable = tradeListWindow:CreateChildWidget("label", "nameLable", 0, false)
    nameLable:SetText(SELLERNAME)
    nameLable:AddAnchor("TOPLEFT", tradeListWindow,NAMEX, subtitleDist)
    nameLable.style:SetFontSize(subtitleFontSize)
    nameLable.style:SetAlign(ALIGN_LEFT)
    nameLable.style:SetColorByKey("brown")

    local kindLable = tradeListWindow:CreateChildWidget("label", "kindLable", 0, false)
    kindLable:SetText(HOUSETYPE)
    kindLable:AddAnchor("TOPLEFT", tradeListWindow, KINDX, subtitleDist)
    kindLable.style:SetFontSize(subtitleFontSize)
    kindLable.style:SetAlign(ALIGN_LEFT)
    kindLable.style:SetColorByKey("brown")
    tradeListWindow.kindLable = kindLable

    local priceLable = tradeListWindow:CreateChildWidget("label", "priceLable", 0, false)
    priceLable:SetText(SELLPRICE)
    priceLable:AddAnchor("TOPLEFT", tradeListWindow,PEICEX + 20, subtitleDist)
    priceLable.style:SetFontSize(subtitleFontSize)
    priceLable.style:SetAlign(ALIGN_LEFT)
    priceLable.style:SetColorByKey("brown")

    selectZoneMessage = tradeListWindow:CreateChildWidget("label", "selectZoneMessage", 0, false)
    selectZoneMessage:SetHeight(30)
    selectZoneMessage:SetText(SELECT_ZONE_MESSAGE)
    selectZoneMessage.style:SetFontSize(titleFontSize)
    selectZoneMessage:AddAnchor("CENTER", tradeListWindow, 0, 0)
    selectZoneMessage.style:SetAlign(ALIGN_CENTER)
    selectZoneMessage.style:SetColor(0, 255, 0, 255)
    selectZoneMessage:Show(true)

    noHousesMessage = tradeListWindow:CreateChildWidget("label", "noHousesMessage", 0, false)
    noHousesMessage:SetHeight(30)
    noHousesMessage:SetText(NO_HOUSES_AVAILABLE)
    noHousesMessage.style:SetFontSize(titleFontSize)
    noHousesMessage:AddAnchor("CENTER", tradeListWindow, 0, 0)
    noHousesMessage.style:SetAlign(ALIGN_CENTER)
    noHousesMessage.style:SetColor(255, 0, 0, 255)
    noHousesMessage:Show(false)

    page = tradeListWindow:CreateChildWidget("label", "page", 0, false)
    page:SetText(string.format("%s/%s",currentPageNum,maxPageNum))
    page.style:SetFontSize(pageNumFontSize)
    page:AddAnchor("BOTTOM", tradeListWindow,0,-60)
    page.style:SetAlign(ALIGN_CENTER)
    page.style:SetColorByKey("brown")
    page:Show(false)

    countdownLabelHousing = tradeListWindow:CreateChildWidget("label", "countdownLabelHousing", 0, false)
    countdownLabelHousing:SetHeight(20)
    countdownLabelHousing:SetText("...")
    countdownLabelHousing.style:SetFontSize(14)
    countdownLabelHousing:AddAnchor("TOPLEFT", tradeListWindow, 30, 18)
    countdownLabelHousing.style:SetAlign(ALIGN_LEFT)
    countdownLabelHousing.style:SetColor(0, 255, 0, 255)
    countdownLabelHousing:Show(true)

    local errorLabel = tradeListWindow:CreateChildWidget("label", "errorLabel", 0, false)
    errorLabel:SetHeight(20)
    errorLabel:SetText("")
    errorLabel.style:SetFontSize(14)
    errorLabel:AddAnchor("TOPLEFT", tradeListWindow, 30, 50)
    errorLabel.style:SetAlign(ALIGN_LEFT)
    errorLabel.style:SetColor(255, 0, 0, 255)
    errorLabel:Show(false)
    tradeListWindow.errorLabel = errorLabel    

    houseSizeLabel = tradeListWindow:CreateChildWidget("label", "houseSizeLabel", 0, false)
    houseSizeLabel:SetText(HOUSETYPE_LABEL)
    houseSizeLabel.style:SetFontSize(subtitleFontSize)
    houseSizeLabel:AddAnchor("TOPRIGHT", tradeListWindow, -260, 23) 
    houseSizeLabel.style:SetAlign(ALIGN_LEFT)
    houseSizeLabel.style:SetColorByKey("brown")

    local closeButton = tradeListWindow:CreateChildWidget("button", "closeButton", 0, true)
    closeButton:SetStyle("text_default")
    closeButton:AddAnchor("TOPRIGHT", tradeListWindow,-10,10)
    closeButton:Show(true)
    closeButton:SetText("X")
    closeButton:SetExtent(45,30)

    function closeButton:OnClick()
        tradeListWindow:Show(false)
    end
    closeButton:SetHandler("OnClick", closeButton.OnClick)   

    local firstPageButton = tradeListWindow:CreateChildWidget("button", "firstPageButton", 0, true)
    firstPageButton:SetStyle("text_default")
    firstPageButton:AddAnchor("BOTTOM", tradeListWindow,-70, -20)
    firstPageButton:Show(false)
    firstPageButton:SetText("<<")
    firstPageButton:SetExtent(40,30)
    tradeListWindow.firstPageButton = firstPageButton

    function firstPageButton:OnClick()
        currentPageNum = 1
        index = 0
    end
    firstPageButton:SetHandler("OnClick", firstPageButton.OnClick)

    local prePageButton = tradeListWindow:CreateChildWidget("button", "prePageButton", 0, true)
    prePageButton:SetStyle("text_default")
    prePageButton:AddAnchor("BOTTOM", tradeListWindow,-25, -20)
    prePageButton:Show(false)
    prePageButton:SetText("<")
    prePageButton:SetExtent(40,30)
    tradeListWindow.prePageButton = prePageButton

    function prePageButton:OnClick()
        if currentPageNum > 1 then
            currentPageNum = currentPageNum - 1
            index = index - 10
        end
    end
    prePageButton:SetHandler("OnClick", prePageButton.OnClick)

    local nextPageButton = tradeListWindow:CreateChildWidget("button", "nextPageButton", 0, true)
    nextPageButton:SetStyle("text_default")
    nextPageButton:AddAnchor("BOTTOM", tradeListWindow,25, -20)
    nextPageButton:Show(false)
    nextPageButton:SetText(">")
    nextPageButton:SetExtent(40,30)
    tradeListWindow.nextPageButton = nextPageButton

    function nextPageButton:OnClick()
        if currentPageNum < maxPageNum then
            currentPageNum = currentPageNum + 1
            index = index + 10
        end
    end
    nextPageButton:SetHandler("OnClick", nextPageButton.OnClick)

    local lastPageButton = tradeListWindow:CreateChildWidget("button", "lastPageButton", 0, true)
    lastPageButton:SetStyle("text_default")
    lastPageButton:AddAnchor("BOTTOM", tradeListWindow,70, -20)
    lastPageButton:Show(false)
    lastPageButton:SetText(">>")
    lastPageButton:SetExtent(40,30)
    tradeListWindow.lastPageButton = lastPageButton

    function lastPageButton:OnClick()
        currentPageNum = maxPageNum
        index = (maxPageNum - 1) * 10
    end
    lastPageButton:SetHandler("OnClick", lastPageButton.OnClick)

    for i = 1, 10 do
        local name = tradeListWindow:CreateChildWidget("label", "name" .. i, 0, false)
        name:SetHeight(20)
        name.style:SetFontSize(16)
        name:AddAnchor("TOPLEFT", tradeListWindow, NAMEX, 100+(i - 1) * 25)
        name.style:SetAlign(ALIGN_LEFT)
        name.style:SetColor(0, 0, 0, 255)
        name:SetText("")
        name.style:SetColorByKey("brown")
        tradeInfoName[i] = name

        local kind = tradeListWindow:CreateChildWidget("label", "kind" .. i, 0, false)
        kind:SetHeight(20)
        kind.style:SetFontSize(16)
        kind:AddAnchor("TOPLEFT", tradeListWindow, KINDX, 100+(i - 1) * 25)
        kind.style:SetAlign(ALIGN_LEFT)
        kind.style:SetColor(0, 0, 0, 255)
        kind:SetText("")
        kind.style:SetColorByKey("brown")
        tradeInfoKind[i] = kind

        local price = tradeListWindow:CreateChildWidget("label", "price" .. i, 0, false)
        price:SetHeight(20)
        price.style:SetFontSize(16)
        price:AddAnchor("TOPLEFT", tradeListWindow, PEICEX + 70, 100+(i - 1) * 25)
        price.style:SetAlign(ALIGN_RIGHT)  
        price.style:SetColor(0, 0, 0, 255)
        price:SetText("")
        price.style:SetColorByKey("brown")
        tradeInfoPrice[i] = price

        local drawableIcon = tradeListWindow:CreateIconDrawable("artwork")
        drawableIcon:SetExtent(30,30)
        drawableIcon:AddAnchor("TOPLEFT", tradeListWindow, 750, 95+(i - 1) * 25)
        drawableIcon:ClearAllTextures()
        drawableIcon:AddTexture("addon/tradelistfinder/Icon/gold.dds")
        drawableIcon:SetVisible(false)
        goldIcon[i] = drawableIcon
    end

    local function resetAllContinentZoneComboBoxes()
        if tradeListWindow then
            if tradeListWindow.Nuia then 
                tradeListWindow.Nuia:ResetDisplay() 
            end
            if tradeListWindow.Haranya then 
                tradeListWindow.Haranya:ResetDisplay() 
            end
            if tradeListWindow.Auroria then 
                tradeListWindow.Auroria:ResetDisplay() 
            end
            if tradeListWindow.Empty then 
                tradeListWindow.Empty:Show(true) 
            end
            
            if tradeListWindow.Continant then 
                tradeListWindow.Continant:ResetDisplay() 
                tradeListWindow.Continant:Show(true) 
            end
        end
    end

    local function resetHouseSizeComboBox()
        if tradeListWindow and tradeListWindow.houseSizeCombo then
            tradeListWindow.houseSizeCombo:ResetDisplay()
        end
        if tradeListWindow and tradeListWindow.houseSizeCombo then
            tradeListWindow.houseSizeCombo:Show(true)
        end        

    end    

    local triggerWidth = 180
    local triggerHeight = 30
    local maxVisibleOptions = 5
    local optionHeight = 30
    local ComboBoxSlaveX = -10
    local ComboBoxSlaveY = -20
    local ComboBoxSlaveAnchor = "BOTTOMRIGHT"
    local ComboBoxSlaveAnchorParent = tradeListWindow

    local nuiaZoneIds = {1, 2, 3, 5, 6, 8, 10, 18, 19, 20, 21, 22, 26, 27, 93}
    local comboBox2Options = {}
    for _, zoneId in ipairs(nuiaZoneIds) do
        table.insert(comboBox2Options, {
            text = getZoneNameById(zoneId),
            handler = function() selectedZoneId = zoneId; displayCachedTradeList() end
        })
    end

    local Nuia = CreateComboBox(tradeListWindow, triggerWidth, triggerHeight, maxVisibleOptions, comboBox2Options, optionHeight, ComboBoxSlaveAnchor, ComboBoxSlaveAnchorParent, ComboBoxSlaveX, ComboBoxSlaveY)
    Nuia:Show(false)
    tradeListWindow.Nuia = Nuia 

    local haranyaZoneIds = {4, 7, 9, 11, 12, 13, 14, 15, 16, 17, 23, 24, 25, 99}
    local comboBox3Options = {}
    for _, zoneId in ipairs(haranyaZoneIds) do
        table.insert(comboBox3Options, {
            text = getZoneNameById(zoneId),
            handler = function() selectedZoneId = zoneId; displayCachedTradeList() end
        })
    end

    local Haranya = CreateComboBox(tradeListWindow, triggerWidth, triggerHeight, maxVisibleOptions, comboBox3Options, optionHeight, ComboBoxSlaveAnchor, ComboBoxSlaveAnchorParent, ComboBoxSlaveX, ComboBoxSlaveY)
    Haranya:Show(false)
    tradeListWindow.Haranya = Haranya

    local auroriaZoneIds = {54, 56, 57, 102, 103, 61}
    local comboBox4Options = {}
    for _, zoneId in ipairs(auroriaZoneIds) do
        table.insert(comboBox4Options, {
            text = getZoneNameById(zoneId),
            handler = function() selectedZoneId = zoneId; displayCachedTradeList() end
        })
    end

    local Auroria = CreateComboBox(tradeListWindow, triggerWidth, triggerHeight, maxVisibleOptions, comboBox4Options, optionHeight, ComboBoxSlaveAnchor, ComboBoxSlaveAnchorParent, ComboBoxSlaveX, ComboBoxSlaveY)
    Auroria:Show(false)
    tradeListWindow.Auroria = Auroria

    local comboBoxEmptyOptions = {}

    local Empty = CreateComboBox(tradeListWindow, triggerWidth, triggerHeight, maxVisibleOptions, comboBoxEmptyOptions, optionHeight, ComboBoxSlaveAnchor, ComboBoxSlaveAnchorParent, ComboBoxSlaveX, ComboBoxSlaveY)
    tradeListWindow.Empty = Empty

    local houseSizeOptions = {
        { text = "8x8", handler = function() 
            houseSizeFilter = "8"
            selectedZoneId = nil
            currentContinent = nil
            resetAllContinentZoneComboBoxes()
            displayCachedTradeList()
        end },
        { text = "16x16", handler = function() 
            houseSizeFilter = "16"
            selectedZoneId = nil
            currentContinent = nil
            resetAllContinentZoneComboBoxes()
            displayCachedTradeList()
        end },
        { text = "24x24", handler = function() 
            houseSizeFilter = "24"
            selectedZoneId = nil
            currentContinent = nil
            resetAllContinentZoneComboBoxes()
            displayCachedTradeList()
        end },
        { text = "28x28", handler = function() 
            houseSizeFilter = "28"
            selectedZoneId = nil
            currentContinent = nil
            resetAllContinentZoneComboBoxes()
            displayCachedTradeList()
        end },
        { text = "44x44", handler = function() 
            houseSizeFilter = "44"
            selectedZoneId = nil
            currentContinent = nil
            resetAllContinentZoneComboBoxes()
            displayCachedTradeList()
        end },
        { text = ALL_SIZES, handler = function() 
        houseSizeFilter = "All"
        selectedZoneId = nil
        currentContinent = nil
        resetAllContinentZoneComboBoxes()
        displayCachedTradeList()
        end },
    }

    local houseSizeCombo = CreateComboBox(tradeListWindow, 100, 25, 6, houseSizeOptions, 30, "TOPRIGHT", tradeListWindow, -65, 11)
    tradeListWindow.houseSizeCombo = houseSizeCombo     
    
    local comboBox1Options = {
        { text = CONTINENT_NUIA, handler = function()
                if currentContinent ~= CONTINENT_NUIA then
                    resetSearchState()
                    houseSizeFilter = nil
                    resetHouseSizeComboBox()
                    currentContinent = CONTINENT_NUIA
                    if Haranya or Auroria or Empty then
                        Haranya:ResetDisplay()
                        Auroria:ResetDisplay()
                        Empty:ResetDisplay()
                    end
                    if Nuia then
                        Nuia:Show(true)
                    end
                    if isFirstContinentSelection then
                        isFirstContinentSelection = false
                        if selectZoneMessage then
                            selectZoneMessage:SetText(SELECT_ZONE_CONTINUE)
                        end
                    end          
                end
            end },
        { text = CONTINENT_HARANYA, handler = function()
                if currentContinent ~= CONTINENT_HARANYA then
                    resetSearchState()
                    houseSizeFilter = nil
                    resetHouseSizeComboBox()
                    currentContinent = CONTINENT_HARANYA
                    if Nuia or Auroria or Empty then
                        Nuia:ResetDisplay()
                        Auroria:ResetDisplay()
                        Empty:ResetDisplay()
                    end
                    if Haranya then
                        Haranya:Show(true)
                    end
                    if isFirstContinentSelection then
                        isFirstContinentSelection = false
                        if selectZoneMessage then
                            selectZoneMessage:SetText(SELECT_ZONE_CONTINUE)
                        end
                    end
                end
            end },
        { text = CONTINENT_AURORIA, handler = function()
                if currentContinent ~= CONTINENT_AURORIA then
                    resetSearchState()
                    houseSizeFilter = nil
                    resetHouseSizeComboBox()
                    currentContinent = CONTINENT_AURORIA
                    if Nuia or Haranya or Empty then
                        Nuia:ResetDisplay()
                        Haranya:ResetDisplay()
                        Empty:ResetDisplay()
                    end
                    if Auroria then
                        Auroria:Show(true)
                    end
                    if isFirstContinentSelection then
                        isFirstContinentSelection = false
                        if selectZoneMessage then
                            selectZoneMessage:SetText(SELECT_ZONE_CONTINUE)
                        end
                    end
                end
            end },
    }

    local comboBox1Anchor = "BOTTOMLEFT"
    local comboBox1AnchorParent = tradeListWindow
    local comboBox1OffsetX = 95
    local comboBox1OffsetY = -20
    local Continant = CreateComboBox(tradeListWindow, triggerWidth, triggerHeight, maxVisibleOptions, comboBox1Options, optionHeight, comboBox1Anchor, comboBox1AnchorParent, comboBox1OffsetX, comboBox1OffsetY)
    tradeListWindow.Continant = Continant

    return tradeListWindow
end

local function CreateToggleButton()
    if toggleButton then return end

    toggleButton = UIParent:CreateWidget("button", "toggleButton", "UIParent")
    toggleButton:SetExtent(22, 22)
    toggleButton:SetText("")
    toggleButton:Show(true)
    toggleButton:EnableDrag(true)

    local iconOverlay = toggleButton:CreateIconDrawable("artwork")
    iconOverlay:SetExtent(22, 22)
    iconOverlay:AddAnchor("CENTER", toggleButton, 0, 0)
    iconOverlay:SetVisible(true)
    iconOverlay:AddTexture("Addon/tradelistfinder/Icon/Main.dds")
    toggleButton.iconOverlay = iconOverlay

    local hoverOverlay = toggleButton:CreateIconDrawable("artwork")
    hoverOverlay:AddTexture("Addon/tradelistfinder/Icon/Main hoverOverlay.dds")
    hoverOverlay:SetExtent(22, 22)
    hoverOverlay:AddAnchor("CENTER", toggleButton, 0, 0)
    hoverOverlay:SetVisible(false)
    toggleButton.hoverOverlay = hoverOverlay

    local OnClicOverlay = toggleButton:CreateIconDrawable("artwork")
    OnClicOverlay:AddTexture("Addon/tradelistfinder/Icon/Main OnClic.dds")
    OnClicOverlay:SetExtent(22, 22)
    OnClicOverlay:AddAnchor("CENTER", toggleButton, 0, 0)
    OnClicOverlay:SetVisible(false)
    toggleButton.OnClicOverlay = OnClicOverlay

    local Tooltip = toggleButton:CreateChildWidget("label", "Tooltip", 0, true)
    Tooltip:SetHeight(30)
    Tooltip:SetAutoResize(true)
    local Tooltipbackground = Tooltip:CreateNinePartDrawable("ui/common/hud.dds", "background")
    Tooltipbackground:SetCoords(733, 169, 14, 15) 
    Tooltipbackground:SetInset(7, 7, 6, 7)
    Tooltipbackground:AddAnchor("TOPLEFT", Tooltip, -10, 0)
    Tooltipbackground:AddAnchor("BOTTOMRIGHT", Tooltip, 10, 0)
    Tooltip:SetText(SEARCHTRADELIST)
    Tooltip.style:SetAlign(ALIGN_CENTER)
    Tooltip.style:SetColorByKey("brown")
    Tooltip.style:SetFontSize(12)
    Tooltip:AddAnchor("TOPLEFT", toggleButton, -70, -30)
    Tooltip:Show(false)
    toggleButton.Tooltip = Tooltip

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

    ApplyMouseHandlers(toggleButton, mouseHandlers)

    if savedPositions["toggleButton"] then
        local uiScale = GetUIScaleFactor()
        local scaledX = savedPositions["toggleButton"].x / uiScale
        local scaledY = savedPositions["toggleButton"].y / uiScale
        toggleButton:AddAnchor("TOPLEFT", "UIParent", scaledX, scaledY)
    else
        toggleButton:AddAnchor("CENTER", "UIParent", 0, 0)
    end

    function toggleButton:OnClick()
        if not tradeListWindow then
            ToggleTradeListWindow()
        else
            tradeListWindow:Show(not tradeListWindow:IsVisible())
        end
    end
    toggleButton:SetHandler("OnClick", toggleButton.OnClick)

    function toggleButton:OnMouseDown()
        if self.OnClicOverlay then
            self.OnClicOverlay:SetVisible(true)
        end
    end
    toggleButton:SetHandler("OnMouseDown", toggleButton.OnMouseDown)

    function toggleButton:OnMouseUp()
        if self.OnClicOverlay then
            self.OnClicOverlay:SetVisible(false)
        end
    end
    toggleButton:SetHandler("OnMouseUp", toggleButton.OnMouseUp)

    function toggleButton:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    toggleButton:SetHandler("OnDragStart", toggleButton.OnDragStart)

    function toggleButton:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
        local correctedX, correctedY = self:CorrectOffsetByScreen()
        SaveButtonPosition("toggleButton", correctedX, correctedY)
    end
    toggleButton:SetHandler("OnDragStop", toggleButton.OnDragStop)
end

function refreshtimer:OnUpdate(dt)
    if page then
        page:SetText(string.format("%s/%s",currentPageNum,maxPageNum))
    end

    UpdateNavigationVisibility()

    local currentTime = os.time()
    local timeSinceLastRefresh = currentTime - lastHousingDataRefreshTime
    local remainingRefreshTime = HOUSING_DATA_REFRESH_INTERVAL - timeSinceLastRefresh

    if isRequestingHousingData and isWaitingForResponse then
        local requestDuration = currentTime - requestStartTime
        if requestDuration > REQUEST_TIMEOUT then
            isWaitingForResponse = false
            currentRetryCount = currentRetryCount + 1
            
            if currentRetryCount >= MAX_RETRY_ATTEMPTS then
                isRequestingHousingData = false
                hasFailedToRefresh = true
                currentRetryCount = 0
                housingRequestQueue = {}
                
                if countdownLabelHousing then
                    countdownLabelHousing:Show(false)
                end
                
                if tradeListWindow and tradeListWindow.errorLabel then
                    tradeListWindow.errorLabel:SetText(REFRESH_FAILED_MESSAGE)
                    tradeListWindow.errorLabel:Show(true)
                end
            else
                X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format(TIMEOUT_MESSAGE, currentRequestingZoneId or 0, currentRetryCount, MAX_RETRY_ATTEMPTS))
                requestStartTime = currentTime
                isWaitingForResponse = true
                X2Resident:RequestHousingTradeList(currentRequestingZoneId, 1, "")
            end
        end
    end

    if countdownLabelHousing and not hasFailedToRefresh then
        if isRequestingHousingData then
            if isFirstRefresh then
                countdownLabelHousing:SetText(INITIALIZING_LABEL)
            else
                countdownLabelHousing:SetText(REFRESHING_LABEL)
            end
            countdownLabelHousing.style:SetColor(255, 165, 0, 255)
            countdownLabelHousing:Show(true)
        elseif remainingRefreshTime > 0 then
            isFirstRefresh = false 
            countdownLabelHousing:SetText(string.format(REFRESH_COUNTDOWN_LABEL, math.ceil(remainingRefreshTime)))
            countdownLabelHousing.style:SetColor(0, 255, 0, 255)
            countdownLabelHousing:Show(true)
            
            if tradeListWindow and tradeListWindow.errorLabel then
                tradeListWindow.errorLabel:Show(false)
            end
        else
            countdownLabelHousing:SetText(REFRESHING_LABEL)
            countdownLabelHousing.style:SetColor(255, 165, 0, 255)
            countdownLabelHousing:Show(true)
            if timeSinceLastRefresh >= HOUSING_DATA_REFRESH_INTERVAL and not isRequestingHousingData then
                requestAllHousingData()
            end
        end
    end

    if tradeListWindow then
        if not hasSearched then
            if selectZoneMessage then selectZoneMessage:Show(true); end
            if noHousesMessage then noHousesMessage:Show(false); end
            for i = 1, 10 do
                if tradeInfoName[i] then
                    tradeInfoName[i]:SetText("")
                    tradeInfoKind[i]:SetText("")
                    tradeInfoPrice[i]:SetText("")
                    goldIcon[i]:SetVisible(false)
                end
            end
            return
        else
            if selectZoneMessage then selectZoneMessage:Show(false); end
        end
    end

    if list and #list > 0 then
        if noHousesMessage then noHousesMessage:Show(false); end
        if page then page:Show(true); end

        for i = 1, 10 do
            local item = list[(index + i)]
            if item then
                if item.sellername and item.kind and item.division and item.price then
                    if houseSizeFilter and item.zoneName then
                        tradeInfoName[i]:SetText(string.format("%s (%s)", item.sellername or "error", item.zoneName))
                    else
                        tradeInfoName[i]:SetText(string.format("%s", item.sellername or "error"))
                    end
                    
                    local division = item.division:match("(%d+)") or item.division:match("(%d+)")
                    if division then
                        tradeInfoKind[i]:SetText(string.format("%s(%sx%s)", item.kind or "error", division, division))
                    else
                        tradeInfoKind[i]:SetText(string.format("%s", item.kind or "error"))
                    end
                    
                    local price = item.price / 10000
                    tradeInfoPrice[i]:SetText(formatPrice(price))  
                    goldIcon[i]:SetVisible(true)
                else
                    tradeInfoName[i]:SetText("incomplete Data")
                    tradeInfoKind[i]:SetText("")
                    tradeInfoPrice[i]:SetText("")
                    goldIcon[i]:SetVisible(false)
                end
            else
                tradeInfoName[i]:SetText("")
                tradeInfoKind[i]:SetText("")
                tradeInfoPrice[i]:SetText("")
                goldIcon[i]:SetVisible(false)
            end
        end
    else
        if noHousesMessage then noHousesMessage:Show(true); end
        if page then page:Show(false); end
        for i = 1, 10 do
            if tradeInfoName[i] then
                tradeInfoName[i]:SetText("")
            end
            if tradeInfoKind[i] then
                tradeInfoKind[i]:SetText("")
            end
            if tradeInfoPrice[i] then
                tradeInfoPrice[i]:SetText("")
            end
            if goldIcon[i] then
                goldIcon[i]:SetVisible(false)
            end
        end
    end
end

local function EnteredWorld()
    LoadSavedPositions()
    CreateToggleButton()
    ToggleTradeListWindow()
    requestAllHousingData()
    X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format(LOADED))
end
UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)

refreshtimer:SetHandler("OnUpdate", refreshtimer.OnUpdate)