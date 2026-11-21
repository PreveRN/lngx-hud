LNGX = LNGX or {}
LNGX.fw = 'standalone'
LNGX.loaded = false
LNGX.fwStats = {}

local function started(res)
    return res and GetResourceState(res) == 'started'
end

local function setFw(k, v)
    if type(v) == 'number' then LNGX.fwStats[k] = v end
end

RegisterNetEvent('esx_status:onTick', function(status)
    if type(status) ~= 'table' then return end
    for i = 1, #status do
        local s = status[i]
        local n = s.name
        if n == 'hunger' or n == 'thirst' or n == 'stress' then
            setFw(n, s.percent or ((s.val or 0) / 10000))
        end
    end
end)
RegisterNetEvent('esx:playerLoaded', function() LNGX.loaded = true end)
RegisterNetEvent('esx:onPlayerLogout', function() LNGX.loaded = false end)

local function applyQB(pd)
    local m = pd and pd.metadata
    if not m then return end
    setFw('hunger', m.hunger)
    setFw('thirst', m.thirst)
    setFw('stress', m.stress)
end

local QBobj = nil
local function qbPlayerData()
    if LNGX.fw == 'qbox' then
        return exports[Config.Resources.qbox]:GetPlayerData()
    end
    if not QBobj then QBobj = exports[Config.Resources.qb]:GetCoreObject() end
    return QBobj.Functions.GetPlayerData()
end

local function qbSync()
    local ok, pd = pcall(qbPlayerData)
    if ok and pd then applyQB(pd) end
end

RegisterNetEvent('QBCore:Player:SetPlayerData', applyQB)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LNGX.loaded = true
    if LNGX.fw == 'qb' or LNGX.fw == 'qbox' then qbSync() end
end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() LNGX.loaded = false end)
RegisterNetEvent('qbx_core:client:playerLoggedOut', function() LNGX.loaded = false end)

CreateThread(function()
    local fw = Config.Framework
    if fw == 'auto' then
        for _ = 1, 20 do
            if started(Config.Resources.qbox) then fw = 'qbox' break
            elseif started(Config.Resources.qb) then fw = 'qb' break
            elseif started(Config.Resources.esx) then fw = 'esx' break end
            Wait(500)
        end
        if fw == 'auto' then fw = 'standalone' end
    end
    LNGX.fw = fw

    if fw == 'standalone' then
        LNGX.loaded = true
    elseif fw == 'esx' then
        local ok, loaded = pcall(function()
            local ESX = exports[Config.Resources.esx]:getSharedObject()
            if ESX.IsPlayerLoaded then return ESX.IsPlayerLoaded() end
            return ESX.PlayerLoaded == true
        end)
        if ok and loaded then LNGX.loaded = true end
    else
        if LocalPlayer.state.isLoggedIn then LNGX.loaded = true end
        while true do
            qbSync()
            Wait(10000)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    DisplayRadar(true)
end)

function LNGX.customNotify(title, msg, kind)
end

local function nativeNotify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end

function LNGX.notify(title, msg, kind)
    kind = kind or 'inform'
    local mode = Config.Notify or 'auto'
    local dur = Config.NotifyDuration or 3000
    if mode == 'auto' then
        if started('ox_lib') then mode = 'ox'
        elseif LNGX.fw == 'esx' then mode = 'esx'
        elseif LNGX.fw == 'qbox' then mode = 'qbox'
        elseif LNGX.fw == 'qb' then mode = 'qb'
        else mode = 'native' end
    end
    local ok = false
    if mode == 'ox' then
        ok = pcall(function()
            exports.ox_lib:notify({ title = title, description = msg, type = kind, duration = dur, position = 'top-right' })
        end)
    elseif mode == 'esx' then
        ok = pcall(function()
            TriggerEvent('esx:showNotification', msg, kind, dur)
        end)
    elseif mode == 'qbox' then
        ok = pcall(function()
            exports.qbx_core:Notify(msg, kind == 'inform' and 'primary' or kind, dur)
        end)
    elseif mode == 'qb' then
        ok = pcall(function()
            TriggerEvent('QBCore:Notify', msg, kind == 'inform' and 'primary' or kind, dur)
        end)
    elseif mode == 'custom' then
        ok = pcall(LNGX.customNotify, title, msg, kind)
    end
    if not ok then nativeNotify(msg) end
end
