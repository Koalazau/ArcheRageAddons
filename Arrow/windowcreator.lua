ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)

local windowCreator = {}
local debugMode
function windowCreator.CreateFollowWindow(target)
    -- Создаем окно
    local window = CreateEmptyWindow(target.."window", "UIParent")
    window:SetExtent(240, 80)

    if debugMode == true then
        local background = window:CreateColorDrawable(0, 0, 0, 0.5, "background")
        background:AddAnchor("TOPLEFT", window, 0, 0)
        background:AddAnchor("BOTTOMRIGHT", window, 0, 0)
    end

    -- Переменные для хранения предыдущих координат
    local lastX, lastY = nil, nil
    local positionThreshold = 0.5 -- Порог изменения координат

    -- Обработчик обновления окна
    function window:OnUpdate(dt)
        -- Получаем экранные координаты цели
        local nScrX_Tar, nScrY_Tar, nScrZ_Tar = X2Unit:GetUnitScreenPosition(target)
        
        if nScrZ_Tar == nil then
            -- Если цель не найдена, убираем окно за пределы экрана
            if lastX ~= 5000 or lastY ~= 5000 then
                window:AddAnchor("TOPLEFT", "UIParent", 5000, 5000)
                lastX, lastY = 5000, 5000
            end
        elseif nScrZ_Tar > 0 then
            -- Если цель найдена, вычисляем новые координаты
            local x = math.floor(nScrX_Tar - 120)
            local y = math.floor(nScrY_Tar - 70)
            
            -- Проверяем, изменились ли координаты больше, чем на пороговое значение
            if lastX == nil or lastY == nil or 
               math.abs(x - lastX) > positionThreshold or 
               math.abs(y - lastY) > positionThreshold then
                -- Обновляем положение окна
                window:AddAnchor("TOPLEFT", "UIParent", x, y)
                lastX, lastY = x, y
            end
        end
    end
    
    -- Устанавливаем обработчик обновления
    window:SetHandler("OnUpdate", window.OnUpdate)
    
    -- Показываем окно
    window:Show(true)
    window:EnablePick(false)
    
    return window
end

function windowCreator.CreateStaticWindow(parent, x, y, r, g, b, a)
    -- Если параметры не переданы, используем красный цвет по умолчанию
    r = r or 1
    g = g or 0
    b = b or 0
    a = a or 0.5

    local window = CreateEmptyWindow(x..y.."window", parent)
    window:SetExtent(25, 25)
    window:AddAnchor("TOP", x, y)

    if debugMode == true then
        local background = window:CreateColorDrawable(r, g, b, a, "background")
        background:AddAnchor("TOPLEFT", window, 0, 0)
        background:AddAnchor("BOTTOMRIGHT", window, 0, 0)
    end
    
    window:Show(true)
    window:EnablePick(false)

    return window
end


function windowCreator.EnableDebugMode()
    debugMode = true
end

_G.WindowCreator = windowCreator