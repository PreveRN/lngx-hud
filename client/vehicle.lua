local VC = Config.VehicleControl or {}
if VC.Enabled == false then return end

local open, veh = false, 0
local hazard, windows, lights = {}, {}, {}

local function ctrl(v)
    if not NetworkHasControlOfEntity(v) then
        NetworkRequestControlOfEntity(v)
        local t = GetGameTimer() + 500
        while not NetworkHasControlOfEntity(v) and GetGameTimer() < t do Wait(0) end
    end
end

local function findVehicle()
    local ped = PlayerPedId()
    local v = GetVehiclePedIsIn(ped, false)
    if v ~= 0 then return v end
    local pos = GetEntityCoords(ped)
    local best, bd = 0, (VC.Range or 6.0) + 0.0
    for _, e in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(e) - pos)
        if d < bd then best, bd = e, d end
    end
    return best
end

local function seatOf(v)
    local ped = PlayerPedId()
    for s = -1, 2 do
        if GetPedInVehicleSeat(v, s) == ped then return s end
    end
    return -2
end

local function readState(v)
    local _, lo, hi = GetVehicleLightsState(v)
    local lv = 0
    if lights[v] then lv = lights[v] elseif hi == 1 then lv = 2 elseif lo == 1 then lv = 1 end
    local doors, wins = {}, {}
    for i = 0, 3 do
        doors[i + 1] = GetVehicleDoorAngleRatio(v, i) > 0.1 and 1 or 0
        wins[i + 1] = (windows[v] and windows[v][i]) and 1 or 0
    end
    local name = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(v)))
    if name == 'NULL' then name = 'Vehicle Control' end
    return {
        name = name,
        engine = GetIsVehicleEngineRunning(v),
        lights = lv,
        hazard = hazard[v] == true,
        interior = IsVehicleInteriorLightOn(v),
        locked = GetVehicleDoorLockStatus(v) > 1,
        hood = GetVehicleDoorAngleRatio(v, 4) > 0.1,
        trunk = GetVehicleDoorAngleRatio(v, 5) > 0.1,
        doors = doors,
        windows = wins,
        seat = seatOf(v),
    }
end

local function closeMenu()
    if not open then return end
    open, veh = false, 0
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'vc:close' })
end

local function openMenu()
    if open then return closeMenu() end
    veh = findVehicle()
    if veh == 0 then
        LNGX.notify(LNGX.L('vc.title'), LNGX.L('vc.none'), 'error')
        return
    end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'vc:open', data = readState(veh) })
    CreateThread(function()
        while open do
            Wait(500)
            if not DoesEntityExist(veh) or #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(veh)) > (VC.Range or 6.0) + 4.0 then
                closeMenu(); break
            end
            SendNUIMessage({ action = 'vc:update', data = readState(veh) })
        end
    end)
end

local function inVeh(v) return GetVehiclePedIsIn(PlayerPedId(), false) == v end

local actions = {
    engine = function(v, d)
        local on = d.state and d.state.engine
        SetVehicleEngineOn(v, on and true or false, false, true)
    end,
    lights = function(v, d)
        local lv = (d.state and d.state.lights) or 0
        lights[v] = lv
        if lv == 0 then SetVehicleLights(v, 0); SetVehicleFullbeam(v, false)
        elseif lv == 1 then SetVehicleLights(v, 2); SetVehicleFullbeam(v, false)
        else SetVehicleLights(v, 2); SetVehicleFullbeam(v, true) end
    end,
    hazard = function(v, d)
        local on = d.state and d.state.hazard and true or false
        hazard[v] = on
        SetVehicleIndicatorLights(v, 0, on); SetVehicleIndicatorLights(v, 1, on)
    end,
    interior = function(v, d) SetVehicleInteriorlight(v, d.state and d.state.interior and true or false) end,
    lock = function(v, d)
        local l = d.state and d.state.locked
        SetVehicleDoorsLocked(v, l and 2 or 1)
        SetVehicleDoorsLockedForAllPlayers(v, l and true or false)
        PlaySoundFrontend(-1, l and 'SELECT' or 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end,
    door = function(v, d)
        local i = tonumber(d.index) if not i then return end
        if GetVehicleDoorAngleRatio(v, i) > 0.1 then SetVehicleDoorShut(v, i, false) else SetVehicleDoorOpen(v, i, false, false) end
    end,
    hood = function(v)
        if GetVehicleDoorAngleRatio(v, 4) > 0.1 then SetVehicleDoorShut(v, 4, false) else SetVehicleDoorOpen(v, 4, false, false) end
    end,
    trunk = function(v)
        if GetVehicleDoorAngleRatio(v, 5) > 0.1 then SetVehicleDoorShut(v, 5, false) else SetVehicleDoorOpen(v, 5, false, false) end
    end,
    window = function(v, d)
        local i = tonumber(d.index) if not i then return end
        windows[v] = windows[v] or {}
        if windows[v][i] then windows[v][i] = nil; RollUpWindow(v, i) else windows[v][i] = true; RollDownWindow(v, i) end
    end,
    seat = function(v, d)
        local s = tonumber(d.index) if not s or s < -1 or s > 2 then return end
        if not inVeh(v) then return end
        if not IsVehicleSeatFree(v, s) then return end
        SetPedIntoVehicle(PlayerPedId(), v, s)
    end,
}

RegisterNUICallback('vcAction', function(d, cb)
    cb('ok')
    if not open or veh == 0 or not DoesEntityExist(veh) or type(d) ~= 'table' then return end
    local fn = actions[d.type]
    if not fn then return end
    ctrl(veh)
    fn(veh, d)
end)

RegisterNUICallback('vcClose', function(_, cb)
    cb('ok')
    open, veh = false, 0
    SetNuiFocus(false, false)
end)

local cmd = VC.Command
if cmd == nil then cmd = 'vehmenu' end
if cmd then
    RegisterCommand(cmd, openMenu, false)
    RegisterKeyMapping(cmd, 'Vehicle Control', 'keyboard', VC.Key or '')
end

exports('openVehicleControl', openMenu)
exports('closeVehicleControl', closeMenu)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
