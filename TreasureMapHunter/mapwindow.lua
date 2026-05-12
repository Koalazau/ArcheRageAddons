local webMapWindow = nil

local function convertCoordinatesForWebMap(coordText)
    if not coordText then return nil end
    
    local lonDir, lonDeg, lonMin, lonSec, latDir, latDeg, latMin, latSec = 
        coordText:match("([WE]) (%d+)°(%d+)' (%d+)\", ([NS]) (%d+)°(%d+)' (%d+)\"")
    
    if lonDir and latDir then
        local lonDecimal = tonumber(lonDeg) + tonumber(lonMin)/60 + tonumber(lonSec)/3600
        local latDecimal = tonumber(latDeg) + tonumber(latMin)/60 + tonumber(latSec)/3600
        
        if lonDir == "W" then lonDecimal = -lonDecimal end
        if latDir == "S" then latDecimal = -latDecimal end
        
        local formattedCoords = string.format("%s%d°%d'%d\"%s%d°%d'%d\"", 
            lonDir, tonumber(lonDeg), tonumber(lonMin), tonumber(lonSec),
            latDir, tonumber(latDeg), tonumber(latMin), tonumber(latSec))
            
        return formattedCoords, lonDir, lonDeg, lonMin, lonSec, latDir, latDeg, latMin, latSec
    end
    return nil
end

local function CreateWebMapWindow()
    if webMapWindow then
        return webMapWindow
    end

    webMapWindow = CreateEmptyWindow("treasureWebMapWindow", "UIParent")
    webMapWindow:SetExtent(755, 790)
    webMapWindow:AddAnchor("CENTER", "UIParent", 0, 0)
    webMapWindow:EnableDrag(true)
    webMapWindow:SetCloseOnEscape(true)
    
    function webMapWindow:OnShow()
        SettingWindowSkin(webMapWindow)
        webMapWindow:SetStartAnimation(true, true)
    end
    webMapWindow:SetHandler("OnShow", webMapWindow.OnShow)

    function webMapWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    webMapWindow:SetHandler("OnDragStart", webMapWindow.OnDragStart)

    function webMapWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
    end
    webMapWindow:SetHandler("OnDragStop", webMapWindow.OnDragStop)

    local titleBar = webMapWindow:CreateChildWidget("label", "titleBar", 0, false)
    titleBar:SetHeight(25)
    titleBar:SetText("Treasure Map - Web View")
    titleBar.style:SetFontSize(14)
    titleBar:AddAnchor("TOP", webMapWindow, 0, 5)
    titleBar.style:SetAlign(ALIGN_CENTER)
    titleBar.style:SetColor(1, 1, 1, 1)
    webMapWindow.titleBar = titleBar
    
    local closeButton = webMapWindow:CreateChildWidget("button", "closeButton", 0, true)
    closeButton:SetStyle("text_default")
    closeButton:AddAnchor("TOPRIGHT", webMapWindow, -10, 5)
    closeButton:SetText("X")
    closeButton:SetExtent(30, 20)
    closeButton:Show(true)
    
    function closeButton:OnClick()
        webMapWindow:Show(false)
    end
    closeButton:SetHandler("OnClick", closeButton.OnClick)
    
    local webbrowser = UIParent:CreateWidget("webbrowser", "treasureMap_webbrowser", webMapWindow)
    webbrowser:SetExtent(735, 740)
    webbrowser:AddAnchor("TOP", webMapWindow, 0, 35)
    webbrowser:Show(true)
    webMapWindow.webbrowser = webbrowser
    webMapWindow:SetHandler("OnWheelUp", function() webbrowser:WheelUp() end)
    webMapWindow:SetHandler("OnWheelDown", function() webbrowser:WheelDown() end)
    
    return webMapWindow
end

function CloseWebMapWindow()
    if webMapWindow and webMapWindow:IsVisible() then
        webMapWindow:Show(false)
    end
end

function UpdateWebMapCoordinates(coordText)
    if not webMapWindow or not webMapWindow:IsVisible() then return end
    if not coordText then return end
    
    local formattedCoords, lonDir, lonDeg, lonMin, lonSec, latDir, latDeg, latMin, latSec = convertCoordinatesForWebMap(coordText)
    if not formattedCoords then return end
    
    local url = string.format("https://archerageaddonmanager.github.io/archerage-map/?dlatk=%s&dlatd=%s&dlatm=%s&dlats=%s&dlngk=%s&dlngd=%s&dlngm=%s&dlngs=%s",
        latDir, latDeg, latMin, latSec, lonDir, lonDeg, lonMin, lonSec)
    
    webMapWindow.titleBar:SetText("Treasure Map - Web View (" .. formattedCoords .. ")")
    webMapWindow.webbrowser:RequestExternalPage("about:blank")
    webMapWindow.webbrowser:RequestExternalPage(url)
end

function OpenWebMapWithCoordinates(coordText)
    if not coordText then
        return
    end
    
    local formattedCoords, lonDir, lonDeg, lonMin, lonSec, latDir, latDeg, latMin, latSec = convertCoordinatesForWebMap(coordText)
    if not formattedCoords then
        return
    end
    
    local url = string.format("https://archerageaddonmanager.github.io/archerage-map/?dlatk=%s&dlatd=%s&dlatm=%s&dlats=%s&dlngk=%s&dlngd=%s&dlngm=%s&dlngs=%s",
        latDir, latDeg, latMin, latSec, lonDir, lonDeg, lonMin, lonSec)
    
    local window = CreateWebMapWindow()
    window.titleBar:SetText("Treasure Map - Web View (" .. formattedCoords .. ")")
    
    window.webbrowser:RequestExternalPage("about:blank")
    window.webbrowser:RequestExternalPage(url) 
    
    window:Show(true)
end

_G.OpenWebMapWithCoordinates = OpenWebMapWithCoordinates

return {
  OpenWebMapWithCoordinates = OpenWebMapWithCoordinates
}