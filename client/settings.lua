LNGX = LNGX or {}

local KVP = 'lngx-hud:settings:v1'
local STATUS_KEYS = { 'health', 'armor', 'hunger', 'thirst', 'stress', 'stamina', 'oxygen', 'premium' }
local INFO_KEYS = { 'id', 'job', 'cash', 'bank', 'black' }
local BOOL = { visible = true, speedo = true, location = true, nav = true, onlyVeh = true, beltSound = true, cruiseSound = true, mapBorder = true, info = true, weapon = true }
local ENUM = { unit = { kmh = true, mph = true }, shape = { square = true, circle = true }, style = { ring = true, line = true }, speedoStyle = { round = true, petrol = true } }

local function defaults()
    local st = {}
    for _, k in ipairs(STATUS_KEYS) do st[k] = true end
    local inf = {}
    local show = (Config.PlayerInfo and Config.PlayerInfo.Show) or {}
    for _, k in ipairs(INFO_KEYS) do inf[k] = show[k] ~= false end
    return {
        infoItems   = inf,
        visible     = true,
        status      = st,
        speedo      = true,
        unit        = (Config.SpeedUnit == 'mph') and 'mph' or 'kmh',
        location    = Config.ShowLocation ~= false,
        nav         = (Config.Nav and Config.Nav.Enabled) and true or false,
        shape       = (Config.MapShape == 'circle') and 'circle' or 'square',
        onlyVeh     = Config.OnlyInVehicle and true or false,
        beltSound   = not (Config.Seatbelt and Config.Seatbelt.Sound == false),
        volume      = (Config.Seatbelt and Config.Seatbelt.Volume) or 0.6,
        cruiseSound = not (Config.Cruise and Config.Cruise.Sound == false),
        mapBorder   = not (Config.MapBorder and Config.MapBorder.Enabled == false),
        info        = not (Config.PlayerInfo and Config.PlayerInfo.Enabled == false),
        weapon      = not (Config.Weapon and Config.Weapon.Enabled == false),
        style       = (Config.StatusStyle == 'ring') and 'ring' or 'line',
        speedoStyle = (Config.SpeedoStyle == 'round' or Config.SpeedoStyle == 'petrol') and Config.SpeedoStyle or 'round',
    }
end

local function valid(key, v)
    if BOOL[key] then return type(v) == 'boolean', v end
    if ENUM[key] then return ENUM[key][v] == true, v end
    if key == 'volume' then
        v = tonumber(v)
        if not v then return false end
        return true, math.max(0.0, math.min(1.0, math.floor(v * 100 + 0.5) / 100))
    end
    return false
end

local S = defaults()
do
    local raw = GetResourceKvpString(KVP)
    local ok, saved = pcall(json.decode, raw or '')
    if ok and type(saved) == 'table' then
        for k in pairs(S) do
            if k ~= 'status' and k ~= 'infoItems' then
                local good, v = valid(k, saved[k])
                if good then S[k] = v end
            end
        end
        if type(saved.infoItems) == 'table' then
            for _, k in ipairs(INFO_KEYS) do
                if type(saved.infoItems[k]) == 'boolean' then S.infoItems[k] = saved.infoItems[k] end
            end
        end
        if type(saved.status) == 'table' then
            for _, k in ipairs(STATUS_KEYS) do
                if type(saved.status[k]) == 'boolean' then S.status[k] = saved.status[k] end
            end
        end
    end
end

LNGX.settings = S
LNGX.visible = S.visible

local function save()
    SetResourceKvp(KVP, json.encode(S))
end

function LNGX.sendPrefs()
    SendNUIMessage({ action = 'prefs', status = S.status, infoItems = S.infoItems, speedoStyle = S.speedoStyle })
end

local function apply(key)
    if key == 'visible' then
        LNGX.visible = S.visible
    elseif key == 'shape' then
        if LNGX.getMapShape and LNGX.getMapShape() ~= S.shape then LNGX.setMapShape(S.shape) end
    elseif key == 'mapBorder' or key == 'style' then
        if LNGX.sendConfig then LNGX.sendConfig() end
    elseif key == 'speedoStyle' then
        LNGX.sendPrefs()
    elseif key:sub(1, 5) == 'info.' then
        LNGX.sendPrefs()
    elseif key == 'info' then
        if LNGX.refreshInfo then LNGX.refreshInfo(true) end
    elseif key == 'weapon' then
        if LNGX.weaponReset then LNGX.weaponReset() end
    elseif key:sub(1, 7) == 'status.' then
        LNGX.sendPrefs()
    end
    if LNGX.onSettingsChanged then LNGX.onSettingsChanged() end
end

function LNGX.openSettings()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'settings', open = true, values = S })
end

RegisterNUICallback('setSetting', function(d, cb)
    cb('ok')
    if type(d) ~= 'table' or type(d.key) ~= 'string' then return end
    local isub = d.key:match('^info%.(%a+)$')
    if isub then
        if S.infoItems[isub] ~= nil and type(d.value) == 'boolean' then
            S.infoItems[isub] = d.value
            save()
            apply(d.key)
        end
        return
    end
    local sub = d.key:match('^status%.(%a+)$')
    if sub then
        if S.status[sub] ~= nil and type(d.value) == 'boolean' then
            S.status[sub] = d.value
            save()
            apply(d.key)
        end
        return
    end
    local ok, v = valid(d.key, d.value)
    if ok then
        S[d.key] = v
        save()
        apply(d.key)
    end
end)

RegisterNUICallback('resetSettings', function(_, cb)
    for k, v in pairs(defaults()) do S[k] = v end
    save()
    apply('visible')
    apply('shape')
    apply('mapBorder')
    apply('style')
    apply('info')
    apply('speedoStyle')
    LNGX.sendPrefs()
    SendNUIMessage({ action = 'settings', open = true, values = S })
    cb('ok')
end)

RegisterNUICallback('closeSettings', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

exports('openSettings', function() LNGX.openSettings() end)

local cmd = Config.SettingsCommand
if cmd == nil then cmd = Config.ToggleCommand end
if cmd == nil then cmd = 'hud' end
if cmd then
    RegisterCommand(cmd, function() LNGX.openSettings() end, false)
end
RegisterCommand('lngx-hud', function() LNGX.openSettings() end, false)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
