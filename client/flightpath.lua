LNGX = LNGX or {}
LNGX.flightBlips = {}

local FP = Config.FlightPath or {}
if FP.Enabled == false then return end
if Config.Plane and Config.Plane.Enabled == false then return end

local aircraft = {}
for _, c in ipairs((Config.Plane and Config.Plane.Classes) or { 15, 16 }) do aircraft[c] = true end

local blips, count = {}, 0
local lastX, lastY, lastWx, lastWy = 0.0, 0.0, 0.0, 0.0
local floor, sqrt, min, max = math.floor, math.sqrt, math.min, math.max
local lineBlip, lineX, lineY = nil, 0.0, 0.0
local MODE = (FP.Mode == 'dots') and 'dots' or 'line'
local lastErr, dbg = nil, { inAir = false, class = -1, wp = false, dist = 0.0, n = 0 }

local function try(fn, ...) local ok = pcall(fn, ...) return ok end

local function newBlip()
    local b = AddBlipForCoord(0.0, 0.0, 0.0)
    SetBlipSprite(b, FP.Sprite or 1)
    SetBlipScale(b, FP.Scale or 0.4)
    SetBlipColour(b, FP.Colour or 8)
    SetBlipAsShortRange(b, true)
    SetBlipDisplay(b, 2)
    try(function() SetBlipHiddenOnLegend(b, true) end)
    LNGX.flightBlips[b] = true
    return b
end

local function setCount(n)
    while count < n do
        count = count + 1
        blips[count] = newBlip()
    end
    while count > n do
        local b = blips[count]
        LNGX.flightBlips[b] = nil
        if DoesBlipExist(b) then RemoveBlip(b) end
        blips[count] = nil
        count = count - 1
    end
end

local function removeLine()
    if lineBlip then
        LNGX.flightBlips[lineBlip] = nil
        if DoesBlipExist(lineBlip) then RemoveBlip(lineBlip) end
        lineBlip = nil
    end
end

local function updateLine(px, py, dx, dy, dist)
    local ang = floor(math.deg(math.atan(dy, dx)) + 0.5) % 360
    if FP.LineInvertRotation then ang = (360 - ang) % 360 end
    local b = AddBlipForArea(px + dx * 0.5, py + dy * 0.5, 0.0, dist, FP.LineWidth or 14.0)
    SetBlipRotation(b, ang)
    SetBlipColour(b, FP.Colour or 8)
    SetBlipAlpha(b, FP.Alpha or 190)
    SetBlipAsShortRange(b, false)
    SetBlipDisplay(b, 2)
    try(function() SetBlipHiddenOnLegend(b, true) end)
    LNGX.flightBlips[b] = true
    removeLine()
    lineBlip = b
end

local function tick()
    local interval = FP.Interval or 500
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local show = false
    dbg.inAir, dbg.wp, dbg.dist = false, false, 0.0

    if veh ~= 0 then
        local class = GetVehicleClass(veh)
        dbg.class = class
        if aircraft[class] then
            dbg.inAir = true
            local wp = GetFirstBlipInfoId(8)
            if DoesBlipExist(wp) then
                dbg.wp = true
                local w = GetBlipInfoIdCoord(wp)
                local p = GetEntityCoords(veh)
                local dx, dy = w.x - p.x, w.y - p.y
                local dist = sqrt(dx * dx + dy * dy)
                dbg.dist = dist
                if dist >= (FP.MinDistance or 150.0) then
                    show = true
                    local moved = (p.x - lastX) ^ 2 + (p.y - lastY) ^ 2 > 100.0
                    local wpMoved = (w.x ~= lastWx) or (w.y ~= lastWy)
                    if MODE == 'line' then
                        if (p.x - lineX) ^ 2 + (p.y - lineY) ^ 2 > (FP.LineStep or 25.0) ^ 2 or wpMoved or not lineBlip or not DoesBlipExist(lineBlip) then
                            lastWx, lastWy, lineX, lineY = w.x, w.y, p.x, p.y
                            updateLine(p.x, p.y, dx, dy, dist)
                        end
                    elseif moved or wpMoved or count == 0 then
                        lastX, lastY, lastWx, lastWy = p.x, p.y, w.x, w.y
                        local n = max(2, min(FP.MaxBlips or 60, floor(dist / (FP.Spacing or 120.0))))
                        setCount(n)
                        for i = 1, n do
                            local t = i / (n + 1)
                            local b = blips[i]
                            if not DoesBlipExist(b) then
                                LNGX.flightBlips[b] = nil
                                b = newBlip()
                                blips[i] = b
                            end
                            SetBlipCoords(b, p.x + dx * t, p.y + dy * t, 0.0)
                            SetBlipDisplay(b, 2)
                        end
                    end
                end
            end
        end
    end

    dbg.n = (MODE == 'line') and (lineBlip and 1 or 0) or count
    if not show then
        if count > 0 then setCount(0) end
        removeLine()
    end
    return (veh ~= 0 and dbg.inAir) and interval or 1000
end

CreateThread(function()
    while true do
        local ok, res = pcall(tick)
        local wait = 1000
        if ok then wait = res
        elseif res ~= lastErr then
            lastErr = res
            print(('[lngx-hud][flightpath] error: %s'):format(tostring(res)))
        end
        Wait(wait)
    end
end)

RegisterCommand('flightdebug', function()
    local first = blips[1] and DoesBlipExist(blips[1]) and GetBlipCoords(blips[1]) or nil
    print(('[lngx-hud][flightpath] di pesawat/heli=%s (class %d) | waypoint=%s | jarak=%.0f m | mode=%s | blip dibuat=%d | titik#1=%s | error=%s'):format(
        tostring(dbg.inAir), dbg.class, tostring(dbg.wp), dbg.dist, MODE, dbg.n,
        first and ('%.0f, %.0f'):format(first.x, first.y) or 'tidak ada', tostring(lastErr)))
end, false)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then setCount(0) removeLine() end
end)
