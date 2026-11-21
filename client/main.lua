LNGX = LNGX or {}
if LNGX.visible == nil then LNGX.visible = true end
LNGX.override = {}
LNGX.seatbelt = nil

local sent, pending, dirty = {}, {}, false
local lastVis = nil
local vSent, vShown = {}, false
local lastStatus = 0
local fuelCache = { veh = 0, class = 0, tank = 65.0, res = nil }

local noBelt = {}
local noCruise = {}
for _, c in ipairs((Config.Cruise and Config.Cruise.BlockClasses) or {}) do noCruise[c] = true end
for _, c in ipairs(Config.NoSeatbeltClasses or {}) do noBelt[c] = true end

local PC = Config.Plane or {}
local planeCls, aircraft, noEject = {}, {}, {}
for _, c in ipairs(PC.Classes or { 15, 16 }) do planeCls[c] = true end
if PC.Enabled ~= false then
    for c in pairs(planeCls) do
        aircraft[c] = true
        if PC.Seatbelt ~= false then noBelt[c] = nil end
        if PC.Cruise ~= false then noCruise[c] = nil end
        if not PC.EjectOnCrash then noEject[c] = true end
    end
end

local floor, max, min = math.floor, math.max, math.min
local function round(n) return floor(n + 0.5) end
local function clamp(n, a, b) return max(a, min(b, n)) end

local wpCache = { t = -1000, has = false, x = 0.0, y = 0.0, z = 0.0 }
local function getWaypoint(now)
    now = now or GetGameTimer()
    if now - wpCache.t >= 100 then
        wpCache.t = now
        local b = GetFirstBlipInfoId(8)
        if DoesBlipExist(b) then
            local c = GetBlipInfoIdCoord(b)
            wpCache.has, wpCache.x, wpCache.y, wpCache.z = true, c.x, c.y, c.z
        else
            wpCache.has = false
        end
    end
    return wpCache.has, wpCache.x, wpCache.y, wpCache.z
end

local curVeh, curClass = 0, -1

local function push(k, v)
    if sent[k] ~= v then
        sent[k] = v
        pending[k] = v
        dirty = true
    end
end

local function flush()
    if dirty then
        SendNUIMessage({ action = 'update', data = pending })
        pending, dirty = {}, false
    end
end

local function stat(k, fallback)
    local o = LNGX.override[k]
    if o ~= nil then return o end
    local f = LNGX.fwStats[k]
    if f ~= nil then return f end
    return fallback
end

local function statusTick(ped, pid)
    local maxHp = GetEntityMaxHealth(ped)
    local health = 0
    if not IsEntityDead(ped) and maxHp > 100 then
        health = clamp(round((GetEntityHealth(ped) - 100) / (maxHp - 100) * 100), 0, 100)
    end
    push('health', health)
    push('armor', clamp(GetPedArmour(ped), 0, 100))
    push('stamina', clamp(round(100 - GetPlayerSprintStaminaRemaining(pid)), 0, 100))

    local oxygen = 100
    if IsPedSwimmingUnderWater(ped) then
        oxygen = clamp(floor(GetPlayerUnderwaterTimeRemaining(pid) * 10), 0, 100)
    end
    push('oxygen', oxygen)

    push('hunger', clamp(round(stat('hunger', 100)), 0, 100))
    push('thirst', clamp(round(stat('thirst', 100)), 0, 100))
    push('stress', clamp(round(stat('stress', 0)), 0, 100))

    local prem = LNGX.override.premium
    if prem == nil then prem = false end
    push('premium', prem)

    flush()
end

local function resolveFuelRes()
    if Config.Fuel ~= 'auto' and Config.Fuel ~= 'native' then return Config.Fuel end
    if Config.Fuel == 'auto' then
        for _, r in ipairs(Config.FuelResources or {}) do
            if GetResourceState(r) == 'started' then return r end
        end
    end
    return nil
end

local function callGetFuel(res, veh) return exports[res]:GetFuel(veh) end

local function getFuel(veh)
    if Config.Fuel ~= 'native' then
        local st = fuelCache.state
        if st then
            local sb = st[Config.FuelStatebag or 'fuel']
            if type(sb) == 'number' then return sb end
        end
        if fuelCache.res then
            local ok, v = pcall(callGetFuel, fuelCache.res, veh)
            if ok and type(v) == 'number' then return v end
        end
    end
    local tank = fuelCache.tank
    if tank <= 0 then tank = 65.0 end
    return GetVehicleFuelLevel(veh) / tank * 100
end

local belted = false
local beltLoop = false
local prevSpd, prevVel, prevVeh = 0.0, nil, 0

local function isBelted()
    if LNGX.seatbelt ~= nil then return LNGX.seatbelt end
    return belted
end

local function setBelt(state, silent)
    if belted == state then return end
    belted = state
    LocalPlayer.state:set('seatbelt', state, true)
    if not silent and LNGX.settings.beltSound then
        SendNUIMessage({ action = 'sound', name = state and 'seatbeltOn' or 'seatbeltOff', volume = LNGX.settings.volume })
    end
    if not silent and Config.Seatbelt.Notify then
        local m = Config.Seatbelt.Messages or {}
        local title = m.title or LNGX.L('seatbelt.title')
        if state then LNGX.notify(title, m.on or LNGX.L('seatbelt.on'), 'success')
        else LNGX.notify(title, m.off or LNGX.L('seatbelt.off'), 'error') end
    end
    if state and Config.Seatbelt.BlockExit and not beltLoop then
        beltLoop = true
        CreateThread(function()
            while belted do
                DisableControlAction(0, 75, true)
                DisableControlAction(27, 75, true)
                Wait(0)
            end
            beltLoop = false
        end)
    end
end

local function toggleBelt()
    if not Config.Seatbelt.Enabled then return end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 or noBelt[GetVehicleClass(veh)] then return end
    setBelt(not belted)
end

local function ejectPed(ped, veh, vel)
    local c = GetEntityCoords(ped)
    local f = GetEntityForwardVector(veh)
    SetEntityCoords(ped, c.x + f.x, c.y + f.y, c.z + 0.4, false, false, false, false)
    SetPedToRagdoll(ped, 4000, 4000, 0, false, false, false)
    if vel then SetEntityVelocity(ped, vel.x, vel.y, vel.z) end
    local hp = GetEntityHealth(ped) - (Config.Seatbelt.EjectDamage or 0)
    SetEntityHealth(ped, max(hp, 0))
end

local function seatbeltReset()
    prevSpd, prevVel, prevVeh = 0.0, nil, 0
    if belted then setBelt(false, true) end
end

local function seatbeltTick(ped, veh, class, spd)
    local cfg = Config.Seatbelt
    if not cfg.Enabled or not cfg.Eject or noBelt[class] or noEject[class] then return end
    if isBelted() then
        prevVeh, prevSpd, prevVel = veh, 0.0, nil
        return
    end
    local kmh = spd * 3.6
    if veh == prevVeh and prevSpd >= cfg.EjectSpeed and (prevSpd - kmh) >= cfg.EjectDrop then
        ejectPed(ped, veh, prevVel)
        kmh = 0.0
    end
    prevVeh, prevSpd = veh, kmh
    prevVel = (kmh >= cfg.EjectSpeed) and GetEntityVelocity(veh) or nil
end

local cruise = { on = false, veh = 0, target = 0.0, air = false }

local function cruiseNotify(key, kind)
    local cfg = Config.Cruise
    if not cfg.Notify then return end
    local m = cfg.Messages or {}
    LNGX.notify(m.title or LNGX.L('cruise.title'), m[key] or LNGX.L('cruise.' .. key), kind)
end

local function cruiseSound(on)
    if not LNGX.settings.cruiseSound then return end
    if on then PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    else PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
end

local function cruiseStop(silent)
    if not cruise.on then return end
    cruise.on = false
    if cruise.veh ~= 0 and DoesEntityExist(cruise.veh) then
        SetVehicleMaxSpeed(cruise.veh, 0.0)
    end
    cruise.veh = 0
    if not silent then
        cruiseSound(false)
        cruiseNotify('off', 'error')
    end
end

local function cruiseLoop()
    CreateThread(function()
        local air = cruise.air
        local crashDrop = ((air and (PC.CruiseCrashDrop or 60)) or (Config.Cruise.CrashDrop or 20)) / 3.6
        while cruise.on do
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 or veh ~= cruise.veh or not DoesEntityExist(veh) or GetPedInVehicleSeat(veh, -1) ~= ped then
                cruiseStop(true)
                break
            end
            local spd = GetEntitySpeed(veh)
            if air then
                if IsControlPressed(0, 72) or IsControlPressed(0, 88)
                    or not GetIsVehicleEngineRunning(veh) or IsPedDeadOrDying(ped, true)
                    or (not IsEntityInAir(veh) and GetEntityHeightAboveGround(veh) < 3.0)
                    or spd < cruise.target - crashDrop then
                    cruiseStop(false)
                    break
                end
                if spd < cruise.target - 0.5 then
                    SetVehicleForwardSpeed(veh, spd + clamp((cruise.target - spd) * 0.05, 0.02, 0.12))
                end
            else
                if IsControlPressed(0, 72) or IsControlPressed(0, 76)
                    or not GetIsVehicleEngineRunning(veh) or IsPedDeadOrDying(ped, true)
                    or GetEntitySpeedVector(veh, true).y < -0.5
                    or spd < cruise.target - crashDrop then
                    cruiseStop(false)
                    break
                end
                if spd < cruise.target - 0.5 and not IsEntityInAir(veh) and not IsControlPressed(0, 71) then
                    SetControlNormal(0, 71, clamp((cruise.target - spd) * 0.5 + 0.25, 0.25, 1.0))
                end
            end
            Wait(0)
        end
    end)
end

local function cruiseStart()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    local class = GetVehicleClass(veh)
    if noCruise[class] or not GetIsVehicleEngineRunning(veh) then return end
    local spd = GetEntitySpeed(veh)
    local air = aircraft[class] or false
    if air then
        if not IsEntityInAir(veh) or GetEntityHeightAboveGround(veh) < (PC.CruiseMinHeight or 15.0) then
            cruiseNotify('air', 'error')
            return
        end
        local minKts = (class == 15) and (PC.CruiseMinSpeedHeli or 25) or (PC.CruiseMinSpeed or 50)
        if spd * 1.943844 < minKts then
            cruiseNotify('slow', 'error')
            return
        end
    else
        if IsEntityInAir(veh) then return end
        if GetEntitySpeedVector(veh, true).y < 0.0 or spd * 3.6 < (Config.Cruise.MinSpeed or 30) then
            cruiseNotify('slow', 'error')
            return
        end
    end
    cruise.on, cruise.veh, cruise.target, cruise.air = true, veh, spd, air
    SetVehicleMaxSpeed(veh, spd)
    cruiseSound(true)
    cruiseNotify('on', 'success')
    cruiseLoop()
end

local function toggleCruise()
    if not Config.Cruise.Enabled then return end
    if cruise.on then cruiseStop(false) else cruiseStart() end
end

local loc = { t = 0, street = '', zone = '', dest = '' }
local function zoneName(x, y, z)
    local code = GetNameOfZone(x, y, z)
    local label = GetLabelText(code)
    if label == 'NULL' or label == '' then return code end
    return label
end
local function updateLoc(veh, now)
    if now - loc.t < 1000 then return end
    loc.t = now
    local p = GetEntityCoords(veh)
    local s1, s2 = GetStreetNameAtCoord(p.x, p.y, p.z)
    local n1 = (s1 and s1 ~= 0) and GetStreetNameFromHashKey(s1) or ''
    local n2 = (s2 and s2 ~= 0) and GetStreetNameFromHashKey(s2) or ''
    if n2 == n1 then n2 = '' end
    loc.street = (n1 ~= '' and n2 ~= '') and (n1 .. ' / ' .. n2) or (n1 ~= '' and n1 or n2)
    loc.zone = zoneName(p.x, p.y, p.z)
    loc.dest = ''
    local has, wx, wy, wz = getWaypoint(now)
    if has then loc.dest = zoneName(wx, wy, wz) end
end

local lSent = {}
local function locationTick(ent, show, now)
    if show then updateLoc(ent, now) end
    local street, zone = show and loc.street or '', show and loc.zone or ''
    if lSent.show == show and lSent.street == street and lSent.zone == zone then return end
    lSent.show, lSent.street, lSent.zone = show, street, zone
    SendNUIMessage({ action = 'loc', show = show, street = street, zone = zone })
end

local function getNav(veh, now)
    if not LNGX.settings.nav then return nil end
    local has, wx, wy = getWaypoint(now)
    if not has then return nil end
    local p = GetEntityCoords(veh)
    local dx, dy = wx - p.x, wy - p.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist >= 1000.0 then dist = floor(dist / 100 + 0.5) * 100
    elseif dist >= 100.0 then dist = floor(dist / 10 + 0.5) * 10
    else dist = floor(dist / 5 + 0.5) * 5 end
    local bearing = math.deg(math.atan2(-dx, dy)) % 360.0
    local ang = (GetEntityHeading(veh) - bearing) % 360.0
    ang = floor(ang / 5 + 0.5) * 5 % 360
    return dist, ang
end

local slow = { t = -1000, fuel = 0, engine = 0 }

local function ensureFuelCache(veh, class)
    if veh ~= fuelCache.veh then
        fuelCache.veh = veh
        fuelCache.class = class
        fuelCache.tank = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume')
        fuelCache.res = resolveFuelRes()
        fuelCache.state = Entity(veh).state
        slow.t = -1000
    end
end

local function beltState(class)
    if noBelt[class] then return nil end
    local belt
    if LNGX.seatbelt ~= nil then belt = LNGX.seatbelt
    elseif Config.Seatbelt.Enabled then belt = belted
    else belt = LocalPlayer.state.seatbelt end
    if type(belt) ~= 'boolean' then return nil end
    return belt
end

local function cruiseState(class, veh)
    if Config.Cruise.Enabled and not noCruise[class] then return cruise.on and cruise.veh == veh end
    return nil
end

local function vehicleTick(veh, class, spd, now)
    ensureFuelCache(veh, class)

    local speed = round(spd * ((LNGX.settings.unit == 'mph') and 2.236936 or 3.6))

    local gear = GetVehicleCurrentGear(veh)
    if gear == 0 and GetEntitySpeedVector(veh, true).y < -0.5 then gear = 'R' end

    local rpm = floor(GetVehicleCurrentRpm(veh) * 25 + 0.5) / 25

    if now - slow.t >= 500 then
        slow.t = now
        slow.fuel = clamp(round(getFuel(veh)), 0, 100)
        slow.engine = clamp(round(GetVehicleEngineHealth(veh) / 10), 0, 100)
    end
    local fuel, engine = slow.fuel, slow.engine
    local engineOn = GetIsVehicleEngineRunning(veh) and true or false

    local _, lightsOn, highBeam = GetVehicleLightsState(veh)
    lightsOn, highBeam = lightsOn == 1, highBeam == 1

    local belt = beltState(class)
    local cr = cruiseState(class, veh)
    local crSpd = cr and round(cruise.target * ((LNGX.settings.unit == 'mph') and 2.236936 or 3.6)) or 0

    local navDist, navAng = getNav(veh, now)
    local lDest = (LNGX.settings.location and navDist) and loc.dest or ''

    local s = vSent
    if vShown and s.speed == speed and s.gear == gear and s.rpm == rpm and s.fuel == fuel
        and s.engine == engine and s.engineOn == engineOn and s.seatbelt == belt and s.cruise == cr and s.cruiseSpeed == crSpd
        and s.navDist == navDist and s.navAng == navAng
        and s.lDest == lDest and s.lights == lightsOn and s.highBeam == highBeam then
        return
    end

    vShown = true
    s.speed, s.gear, s.rpm, s.fuel, s.engine, s.engineOn, s.seatbelt, s.cruise, s.cruiseSpeed, s.navDist, s.navAng, s.lDest, s.lights, s.highBeam =
        speed, gear, rpm, fuel, engine, engineOn, belt, cr, crSpd, navDist, navAng, lDest, lightsOn, highBeam

    SendNUIMessage({
        action = 'vehicle',
        data = {
            show = true, speed = speed, gear = gear, rpm = rpm, fuel = fuel,
            engine = engine, engineOn = engineOn, seatbelt = belt, cruise = cr, cruiseSpeed = crSpd, lights = lightsOn, highBeam = highBeam, unit = (LNGX.settings.unit == 'mph') and 'mph' or 'km/h',
            navDist = navDist, navAng = navAng, destZone = lDest, navArrive = Config.Nav and Config.Nav.ArrivalRadius or 30,
        },
    })
end

local function hideVehicle()
    if vShown then
        vShown = false
        vSent = {}
        fuelCache.veh = 0
        SendNUIMessage({ action = 'vehicle', data = { show = false } })
    end
end

local noStall = {}
for _, n in ipairs(PC.NoStallModels or {}) do noStall[joaat(n) & 0xFFFFFFFF] = true end

local pSent, pShown = {}, false
LNGX.planeFlaps = nil

local function r1(n) return floor(n * 10 + 0.5) / 10 end

local function planeTick(veh, class, spd, now)
    ensureFuelCache(veh, class)
    if now - slow.t >= 500 then
        slow.t = now
        slow.fuel = clamp(round(getFuel(veh)), 0, 100)
        slow.engine = clamp(round(GetVehicleEngineHealth(veh) / 10), 0, 100)
    end

    local kts = spd * 1.943844
    local pos = GetEntityCoords(veh)
    local vel = GetEntityVelocity(veh)
    local roll = GetEntityRoll(veh)
    if PC.InvertRoll then roll = -roll end

    local hasGear = GetVehicleHasLandingGear(veh)
    local gearDown = (not hasGear) or GetLandingGearState(veh) == 0
    local agl = GetEntityHeightAboveGround(veh)
    local engineOn = GetIsVehicleEngineRunning(veh)

    local isHeli = (class == 15)
    local stall = false
    if not isHeli and engineOn and IsEntityInAir(veh) and agl > (PC.StallMinHeight or 12.0) and kts < (PC.StallSpeed or 70)
        and not noStall[GetEntityModel(veh) & 0xFFFFFFFF] then
        stall = true
    end

    local flaps = LNGX.planeFlaps
    if flaps == nil then
        flaps = 0
        if PC.AutoFlaps ~= false and gearDown and engineOn then
            if kts < 90 then flaps = 3 elseif kts < 120 then flaps = 2 elseif kts < 150 then flaps = 1 end
        end
    end

    local navDist, navAng = getNav(veh, now)

    local d = {
        speed = floor(kts + 0.5),
        altitude = floor(max(0.0, pos.z * 3.28084) + 0.5),
        vspeed = floor(vel.z * 196.85 / 10 + 0.5) * 10,
        heading = floor((360.0 - GetEntityHeading(veh)) % 360.0 + 0.5) % 360,
        pitch = r1(GetEntityPitch(veh)),
        roll = r1(roll),
        throttle = floor(clamp(GetVehicleCurrentRpm(veh), 0.0, 1.0) * 100 + 0.5) / 100,
        fuel = slow.fuel,
        gear = gearDown and true or false,
        flaps = flaps,
        stall = stall,
        heli = isHeli,
        belt = beltState(class),
        cruise = cruiseState(class, veh),
        navDist = navDist, navAng = navAng,
        destZone = (LNGX.settings.location and navDist) and loc.dest or '',
        navArrive = PC.NavArrival or 150,
    }

    local s = pSent
    if pShown and s.speed == d.speed and s.altitude == d.altitude and s.vspeed == d.vspeed and s.heading == d.heading
        and s.pitch == d.pitch and s.roll == d.roll and s.throttle == d.throttle and s.fuel == d.fuel
        and s.gear == d.gear and s.flaps == d.flaps and s.stall == d.stall
        and s.heli == d.heli and s.belt == d.belt and s.cruise == d.cruise
        and s.navDist == d.navDist and s.navAng == d.navAng and s.destZone == d.destZone then
        return
    end
    local wasShown = pShown
    pShown = true
    for k, v in pairs(d) do s[k] = v end
    s.belt, s.cruise, s.navDist, s.navAng = d.belt, d.cruise, d.navDist, d.navAng
    d.show = true
    if not wasShown then d.layout = PC.Position or { right = 40, bottom = 34, scale = 0.42 } end
    SendNUIMessage({ action = 'plane', data = d })
end

local function hidePlane()
    if pShown then
        pShown = false
        pSent = {}
        SendNUIMessage({ action = 'plane', data = { show = false } })
    end
end

function LNGX.onSettingsChanged()
    vSent = {}
    pSent = {}
    lSent = {}
end

CreateThread(function()
    local pid = PlayerId()
    while true do
        local now = GetGameTimer()
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local paused = IsPauseMenuActive()
        local shown = LNGX.loaded and LNGX.visible
        local hudVisible = shown and not (Config.HideWhenPaused and paused)

        local brandVisible = LNGX.loaded and not (Config.HideWhenPaused and paused)
        local visKey = (hudVisible and 1 or 0) + (brandVisible and 2 or 0)
        if visKey ~= lastVis then
            lastVis = visKey
            SendNUIMessage({ action = 'visible', state = hudVisible, brand = brandVisible and true or false })
        end

        if veh ~= curVeh then
            curVeh = veh
            curClass = (veh ~= 0) and GetVehicleClass(veh) or -1
            if veh ~= 0 and Config.RadioOffOnEnter then
                CreateThread(function()
                    for _, delay in ipairs({ 0, 250, 700 }) do
                        Wait(delay)
                        if not DoesEntityExist(veh) or GetVehiclePedIsIn(PlayerPedId(), false) ~= veh then return end
                        SetVehRadioStation(veh, 'OFF')
                    end
                end)
            end
        end

        LNGX.updateMap(shown, veh ~= 0, paused, now)

        local inVeh = veh ~= 0
        local vspd = 0.0
        if inVeh then
            vspd = GetEntitySpeed(veh)
            seatbeltTick(ped, veh, curClass, vspd)
        else
            seatbeltReset()
        end

        local wait = 500
        if hudVisible then
            local mapOn = (not LNGX.settings.onlyVeh) or inVeh
            locationTick(inVeh and veh or ped, LNGX.settings.location and mapOn, now)

            if now - lastStatus >= Config.StatusTick then
                lastStatus = now
                statusTick(ped, pid)
            end

            if inVeh and LNGX.settings.speedo and (Config.ShowSpeedoAsPassenger or GetPedInVehicleSeat(veh, -1) == ped) then
                if PC.Enabled ~= false and planeCls[curClass] then
                    hideVehicle()
                    planeTick(veh, curClass, vspd, now)
                    wait = PC.Tick or 50
                else
                    hidePlane()
                    vehicleTick(veh, curClass, vspd, now)
                    wait = Config.VehicleTick
                end
            else
                hideVehicle()
                hidePlane()
                wait = Config.StatusTick
            end
        else
            hideVehicle()
            hidePlane()
            locationTick(ped, false, now)
        end

        if inVeh and Config.Seatbelt.Enabled and Config.Seatbelt.Eject and not isBelted() and not noBelt[curClass] and not noEject[curClass] then
            wait = min(wait, Config.VehicleTick)
        end

        Wait(wait)
    end
end)

RegisterNUICallback('ready', function(_, cb)
    sent, pending, dirty = {}, {}, false
    vSent, vShown, lastVis, lastStatus, lSent = {}, false, nil, 0, {}
    pSent, pShown = {}, false
    fuelCache.veh = 0
    LNGX.sendLocale()
    LNGX.sendConfig()
    LNGX.sendPrefs()
    if LNGX.infoReset then LNGX.infoReset() LNGX.refreshInfo(true) end
    if LNGX.weaponReset then LNGX.weaponReset() end
    cb('ok')
end)

exports('setVisible', function(state) LNGX.visible = state and true or false end)
exports('isVisible', function() return LNGX.visible end)
exports('toggle', function() LNGX.visible = not LNGX.visible return LNGX.visible end)
exports('setStat', function(key, value) LNGX.override[key] = value end)
exports('setPremium', function(value) LNGX.override.premium = value end)
exports('isSeatbelt', function() return isBelted() end)
exports('setSeatbelt', function(value) LNGX.seatbelt = value end)
exports('setMapShape', function(shape) return LNGX.setMapShape(shape) end)
exports('getMapShape', function() return LNGX.getMapShape() end)
exports('getFramework', function() return LNGX.fw end)
exports('isCruise', function() return cruise.on end)
exports('setPlaneFlaps', function(n) LNGX.planeFlaps = (n ~= nil) and clamp(floor(tonumber(n) or 0), 0, 3) or nil end)
exports('setCruise', function(state) if state then if not cruise.on then cruiseStart() end else cruiseStop(false) end end)

RegisterNetEvent('lngx-hud:setVisible', function(state) LNGX.visible = state and true or false end)
RegisterNetEvent('lngx-hud:setStat', function(key, value) LNGX.override[key] = value end)
RegisterNetEvent('lngx-hud:setPremium', function(value) LNGX.override.premium = value end)
RegisterNetEvent('lngx-hud:setSeatbelt', function(value) LNGX.seatbelt = value end)

if Config.Seatbelt.Enabled then
    RegisterCommand(Config.Seatbelt.Command, toggleBelt, false)
    RegisterKeyMapping(Config.Seatbelt.Command, 'Sabuk pengaman (lngx-hud)', 'keyboard', Config.Seatbelt.Key)
end

if Config.Cruise.Enabled then
    RegisterCommand(Config.Cruise.Command, toggleCruise, false)
    RegisterKeyMapping(Config.Cruise.Command, 'Cruise control (lngx-hud)', 'keyboard', Config.Cruise.Key)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then cruiseStop(true) end
end)

local ROUTE_IDS = { 142, 150, 151 }
local ROUTE_DEFAULT = { { 164, 76, 242 }, { 210, 166, 249 }, { 82, 38, 121 } }

local function setRouteColour(c)
    for i = 1, 3 do
        ReplaceHudColourWithRgba(ROUTE_IDS[i], c[i][1], c[i][2], c[i][3], 255)
    end
end

if Config.Route and Config.Route.Rgba then
    CreateThread(function()
        Wait(1000)
        setRouteColour(Config.Route.Rgba)
    end)
    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then setRouteColour(ROUTE_DEFAULT) end
    end)
end

if Config.Route and Config.Route.HideDistance then
    CreateThread(function()
        local interval = Config.Route.HideDistanceInterval or 0
        local minimap = RequestScaleformMovie('minimap')
        SetBigmapActive(true, false)
        Wait(0)
        SetBigmapActive(false, false)
        while true do
            if LNGX.radarOn and getWaypoint() then
                BeginScaleformMovieMethod(minimap, 'HIDE_SATNAV')
                EndScaleformMovieMethod()
                Wait(interval)
            else
                Wait(250)
            end
        end
    end)
end
