LNGX = LNGX or {}

local currentShape = LNGX.settings.shape
local lastRadar = nil
local lastApply = 0
local lastResX, lastResY = GetActiveScreenResolution()
local mapLoading = false
local min = math.min

local function getMinimapOffset()
    local defaultAspectRatio = 1920 / 1080
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX / resolutionY
    if aspectRatio > defaultAspectRatio then
        return ((defaultAspectRatio - aspectRatio) / 3.6) - 0.008
    end
    return 0
end

function LNGX.borderData()
    local b = Config.MapBorder or {}
    local g = b[currentShape] or b.square or {}
    return {
        enabled = LNGX.settings.mapBorder ~= false,
        thick = b.Thick or 3,
        color = b.Color or 'rgba(255,255,255,.55)',
        glow = b.Glow or false,
        shadow = b.Shadow ~= false,
        left = g.left or 28, bottom = g.bottom or 66, width = g.width or 312, height = g.height or 198,
        radius = (currentShape == 'circle') and -1 or (g.radius or 0),
    }
end

function LNGX.linesData()
    local c = Config.LineHud
    if type(c) ~= 'table' then return { enabled = false } end
    local g = c[currentShape] or c.square or {}
    return {
        master = c.Enabled ~= false,
        enabled = c.Enabled ~= false and LNGX.settings.style == 'line',
        height = c.Height or 6, height2 = c.Height2 or 4, gap = c.Gap or 4, rowGap = c.RowGap or 7,
        rounded = c.Rounded ~= false, radius = c.Radius or 5,
        left = g.left or 28, bottom = g.bottom or 70, width = g.width or 312,
        show = c.Show or {}, hideEmpty = c.HideWhenEmpty or {}, hideFull = c.HideWhenFull or {},
        colors = c.Colors or {}, lowAt = c.LowAt or 17,
    }
end

function LNGX.sendMapBorder(show)
    SendNUIMessage({ action = 'mapborder', show = show and true or false })
end

function LNGX.brandData()
    local b = Config.ServerBrand
    if type(b) ~= 'table' then return { enabled = false } end
    return { enabled = b.Enabled ~= false, name = b.Name, subtitle = b.Subtitle,
        position = b.Position, x = b.X, y = b.Y }
end

function LNGX.logoData()
    local l = Config.ServerLogo
    if type(l) ~= 'table' then return { enabled = false } end
    return { enabled = l.Enabled ~= false, file = l.File, size = l.Size, round = l.Round and true or false,
        position = l.Position, x = l.X, y = l.Y }
end

function LNGX.sendConfig()
    SendNUIMessage({
        action = 'config',
        shape = currentShape,
        hud = Config.HudPosition[currentShape] or Config.HudPosition.square,
        loc = (Config.LocationPosition or {})[currentShape] or (Config.LocationPosition or {}).square,
        border = LNGX.borderData(),
        lines = LNGX.linesData(),
        brand = LNGX.brandData(),
        logo = LNGX.logoData(),
        info = LNGX.infoConfig and LNGX.infoConfig() or nil,
        weapon = LNGX.weaponConfig and LNGX.weaponConfig() or nil,
    })
end

local function loadMap()
    if mapLoading then return end
    mapLoading = true
    local off = getMinimapOffset()
    local dy = Config.MapOffsetY or 0.0

    if currentShape == 'square' then
        RequestStreamedTextureDict('squaremap', false)
        while not HasStreamedTextureDictLoaded('squaremap') do Wait(50) end

        SetMinimapClipType(0)
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'squaremap', 'radarmasksm')
        AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'squaremap', 'radarmasksm')

        SetMinimapComponentPosition('minimap', 'L', 'B', 0.0 + off, -0.047 + dy, 0.1638, 0.183)
        SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.0 + off, 0.0 + dy, 0.128, 0.20)
        SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.01 + off, 0.025 + dy, 0.262, 0.300)

        SetBlipAlpha(GetNorthRadarBlip(), 0)
        SetRadarBigmapEnabled(true, false)
        SetMinimapClipType(0)
        Wait(50)
        SetRadarBigmapEnabled(false, false)
    else
        RequestStreamedTextureDict('circlemap', false)
        while not HasStreamedTextureDictLoaded('circlemap') do Wait(50) end

        SetMinimapClipType(1)
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'circlemap', 'radarmasksm')
        AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'circlemap', 'radarmasksm')

        SetMinimapComponentPosition('minimap', 'L', 'B', -0.0100 + off, -0.030 + dy, 0.180, 0.258)
        SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.200 + off, 0.0 + dy, 0.065, 0.20)
        SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.00 + off, 0.015 + dy, 0.252, 0.338)

        SetBlipAlpha(GetNorthRadarBlip(), 0)
        SetMinimapClipType(1)
        SetRadarBigmapEnabled(true, false)
        Wait(50)
        SetRadarBigmapEnabled(false, false)
    end

    SetRadarZoom(Config.Zoom)
    mapLoading = false
    LNGX.sendMapBorder(lastRadar)
end

local SPRITE_MAX, CHUNK = 1250, 420
local lastBlipCount, lastSweep, bgCursor = -1, 0, 0

local function sweepBlips(from, to)
    local playerBlip = GetMainPlayerBlipId()
    local wpBlip = (Config.MinimapWaypoint ~= false) and GetFirstBlipInfoId(8) or 0
    if wpBlip ~= 0 and DoesBlipExist(wpBlip) then SetBlipDisplay(wpBlip, 2) else wpBlip = 0 end
    for sprite = from, min(to, SPRITE_MAX - 1) do
        local b = GetFirstBlipInfoId(sprite)
        while DoesBlipExist(b) do
            if b ~= playerBlip and b ~= wpBlip and not (LNGX.flightBlips and LNGX.flightBlips[b]) then SetBlipDisplay(b, 3) end
            b = GetNextBlipInfoId(sprite)
        end
    end
    if Config.HidePlayerBlip and playerBlip and DoesBlipExist(playerBlip) then
        SetBlipDisplay(playerBlip, 3)
    end
end

local function hideBlips(now)
    local n = GetNumberOfActiveBlips()
    if n ~= lastBlipCount and now - lastSweep >= 500 then
        lastBlipCount, lastSweep = n, now
        sweepBlips(0, SPRITE_MAX - 1)
    elseif now - lastSweep >= (Config.BlipBackupInterval or 3000) then
        lastSweep = now
        sweepBlips(bgCursor, bgCursor + CHUNK - 1)
        bgCursor = bgCursor + CHUNK
        if bgCursor >= SPRITE_MAX then bgCursor = 0 end
    end
end

function LNGX.updateMap(shown, inVeh, paused, now)
    now = now or GetGameTimer()
    local radar = shown and ((not LNGX.settings.onlyVeh) or inVeh)
    if radar ~= lastRadar then
        lastRadar = radar
        LNGX.radarOn = radar and true or false
        lastBlipCount = -1
        DisplayRadar(radar)
        LNGX.sendMapBorder(radar)
    end

    if radar and Config.HideMapBlips then hideBlips(now) end

    if radar and now - lastApply > 1500 then
        lastApply = now
        local rx, ry = GetActiveScreenResolution()
        if rx ~= lastResX or ry ~= lastResY then
            lastResX, lastResY = rx, ry
            CreateThread(loadMap)
        end
        SetRadarBigmapEnabled(false, false)
        SetRadarZoom(Config.Zoom)
    end
end

function LNGX.setMapShape(shape)
    if shape ~= 'square' and shape ~= 'circle' then return false end
    currentShape = shape
    CreateThread(function()
        loadMap()
        LNGX.sendConfig()
    end)
    return true
end

function LNGX.getMapShape() return currentShape end

CreateThread(function()
    DisplayRadar(false)
    Wait(1000)
    loadMap()
end)

RegisterCommand('locpos', function(_, args)
    Config.LocationPosition = Config.LocationPosition or {}
    local cfg = Config.LocationPosition[currentShape] or {}
    Config.LocationPosition[currentShape] = cfg
    local keys = { 'left', 'bottom', 'width', 'overlap', 'ry', 'gap', 'span' }
    if tonumber(args[1]) then
        for i = 1, 4 do if tonumber(args[i]) then cfg[keys[i]] = tonumber(args[i]) end end
    elseif args[1] == 'style' and (args[2] == 'arc' or args[2] == 'pill') then
        cfg.style = args[2]
    elseif args[1] and tonumber(args[2]) then
        for _, k in ipairs(keys) do if args[1] == k then cfg[k] = tonumber(args[2]) end end
    end
    LNGX.sendConfig()
    print(('[lngx-hud] %s = { left = %s, bottom = %s, width = %s, overlap = %s, style = \'%s\', ry = %s, gap = %s, span = %s },'):format(
        currentShape, cfg.left or 0, cfg.bottom or 0, cfg.width or 0, cfg.overlap or 0, cfg.style or 'pill', cfg.ry or 100, cfg.gap or 14, cfg.span or 44))
end, false)

if Config.MapShapeCommand then
    RegisterCommand(Config.MapShapeCommand, function(_, args)
        LNGX.setMapShape(args[1])
    end, false)
end

RegisterCommand('mapborder', function(_, args)
    Config.MapBorder = Config.MapBorder or {}
    local cfg = Config.MapBorder[currentShape] or {}
    Config.MapBorder[currentShape] = cfg
    local v = tonumber(args[2])
    if args[1] == 'thick' and v then
        Config.MapBorder.Thick = v
    elseif v then
        for _, k in ipairs({ 'left', 'bottom', 'width', 'height', 'radius' }) do
            if args[1] == k then cfg[k] = v end
        end
    end
    LNGX.sendConfig()
    print(('[lngx-hud] Thick = %s, %s = { left = %s, bottom = %s, width = %s, height = %s, radius = %s },'):format(
        Config.MapBorder.Thick or 3, currentShape, cfg.left or 0, cfg.bottom or 0, cfg.width or 0, cfg.height or 0, cfg.radius or 0))
end, false)
