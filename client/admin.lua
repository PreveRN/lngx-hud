LNGX = LNGX or {}

local AD = Config.AdminHud or {}
local isOpen = false

local function copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = copy(v) end
    return r
end

local defaults = { loc = copy(Config.LocationPosition or {}), border = copy(Config.MapBorder or {}) }

local LOC_KEYS = { left = true, bottom = true, width = true, ry = true, gap = true, span = true, overlap = true }
local BORDER_KEYS = { left = true, bottom = true, width = true, height = true, radius = true }

local function payload()
    local shape = LNGX.getMapShape()
    return { action = 'admin', open = true, shape = shape, loc = (Config.LocationPosition or {})[shape] or {}, border = LNGX.borderData() }
end

local function numstr(v)
    if type(v) == 'number' and v % 1 == 0 then return ('%d'):format(v) end
    return tostring(v)
end

local function fmt(t, order)
    local parts = {}
    for _, k in ipairs(order) do
        local v = t[k]
        if v ~= nil then
            parts[#parts + 1] = (type(v) == 'string') and ("%s = '%s'"):format(k, v) or ('%s = %s'):format(k, numstr(v))
        end
    end
    return '{ ' .. table.concat(parts, ', ') .. ' }'
end

local function exportText()
    local L, B = Config.LocationPosition or {}, Config.MapBorder or {}
    local lo = { 'left', 'bottom', 'width', 'style', 'ry', 'gap', 'span', 'overlap' }
    local bo = { 'left', 'bottom', 'width', 'height', 'radius' }
    return table.concat({
        '-- Config.LocationPosition',
        ('    square = %s,'):format(fmt(L.square or {}, lo)),
        ('    circle = %s,'):format(fmt(L.circle or {}, lo)),
        '',
        '-- Config.MapBorder',
        ('    Thick   = %s,'):format(numstr(B.Thick or 3)),
        ('    square  = %s,'):format(fmt(B.square or {}, bo)),
        ('    circle  = %s,'):format(fmt(B.circle or {}, bo)),
    }, '\n')
end

local function open()
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage(payload())
end

local function close()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'admin', open = false })
end

if AD.Command ~= false then
    RegisterCommand(AD.Command or 'adminhud', function()
        TriggerServerEvent('lngx-hud:adminRequest')
    end, false)
end

RegisterNetEvent('lngx-hud:adminOpen', function() open() end)
RegisterNetEvent('lngx-hud:adminDenied', function()
    LNGX.notify(LNGX.L('admin.title'), LNGX.L('admin.denied_open'), 'error')
end)

RegisterNUICallback('adminSet', function(d, cb)
    cb('ok')
    if type(d) ~= 'table' or type(d.key) ~= 'string' then return end
    local shape = LNGX.getMapShape()
    if d.group == 'loc' then
        Config.LocationPosition = Config.LocationPosition or {}
        local cfg = Config.LocationPosition[shape] or {}
        Config.LocationPosition[shape] = cfg
        if d.key == 'style' then
            if d.value == 'arc' or d.value == 'pill' then cfg.style = d.value end
        elseif LOC_KEYS[d.key] and tonumber(d.value) then
            cfg[d.key] = tonumber(d.value)
        end
    elseif d.group == 'border' then
        Config.MapBorder = Config.MapBorder or {}
        local cfg = Config.MapBorder[shape] or {}
        Config.MapBorder[shape] = cfg
        if d.key == 'thick' and tonumber(d.value) then
            Config.MapBorder.Thick = tonumber(d.value)
        elseif BORDER_KEYS[d.key] and tonumber(d.value) then
            cfg[d.key] = tonumber(d.value)
        end
    end
    LNGX.sendConfig()
end)

RegisterNUICallback('adminReset', function(_, cb)
    cb('ok')
    Config.LocationPosition = copy(defaults.loc)
    Config.MapBorder = copy(defaults.border)
    LNGX.sendConfig()
    SendNUIMessage(payload())
end)

RegisterNUICallback('adminExport', function(_, cb)
    cb('ok')
    local text = exportText()
    print('[lngx-hud] --- salin ke config.lua ---\n' .. text)
    SendNUIMessage({ action = 'adminExport', text = text })
end)

RegisterNUICallback('adminSave', function(_, cb)
    cb('ok')
    local L, B = Config.LocationPosition or {}, Config.MapBorder or {}
    TriggerServerEvent('lngx-hud:adminSave', {
        loc = { square = L.square, circle = L.circle },
        border = { Thick = B.Thick, square = B.square, circle = B.circle },
    })
    close()
end)

local function mergeInto(dst, src)
    for k, v in pairs(src or {}) do
        if type(v) == 'number' or type(v) == 'string' then dst[k] = v end
    end
end

RegisterNetEvent('lngx-hud:layout', function(d)
    if type(d) ~= 'table' then return end
    Config.LocationPosition = Config.LocationPosition or {}
    Config.MapBorder = Config.MapBorder or {}
    for _, shape in ipairs({ 'square', 'circle' }) do
        Config.LocationPosition[shape] = Config.LocationPosition[shape] or {}
        Config.MapBorder[shape] = Config.MapBorder[shape] or {}
        if d.loc then mergeInto(Config.LocationPosition[shape], d.loc[shape]) end
        if d.border then mergeInto(Config.MapBorder[shape], d.border[shape]) end
    end
    if d.border and tonumber(d.border.Thick) then Config.MapBorder.Thick = tonumber(d.border.Thick) end
    if LNGX.sendConfig then LNGX.sendConfig() end
    if isOpen then SendNUIMessage(payload()) end
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('lngx-hud:requestLayout')
end)

RegisterNetEvent('lngx-hud:adminSaved', function(ok, msg)
    LNGX.notify(LNGX.L('admin.title'), msg or '', ok and 'success' or 'error')
end)

RegisterNUICallback('adminClose', function(_, cb)
    cb('ok')
    close()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
