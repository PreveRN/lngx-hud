LNGX = LNGX or {}

local sig = nil
local ESXobj = nil
local QBobj = nil

local function esx()
    if ESXobj then return ESXobj end
    local ok, obj = pcall(function() return exports[Config.Resources.esx]:getSharedObject() end)
    if ok and obj then ESXobj = obj end
    return ESXobj
end

local function num(v)
    v = tonumber(v)
    return v and math.floor(v + 0.5) or nil
end

local function qbPlayerData()
    if LNGX.fw == 'qbox' then return exports[Config.Resources.qbox]:GetPlayerData() end
    if not QBobj then QBobj = exports[Config.Resources.qb]:GetCoreObject() end
    return QBobj.Functions.GetPlayerData()
end

local function collect()
    local cfg = Config.PlayerInfo or {}
    local d = { id = GetPlayerServerId(PlayerId()) }

    if LNGX.fw == 'esx' then
        local E = esx()
        local pd = E and E.GetPlayerData and E.GetPlayerData()
        if pd then
            if pd.job then d.job, d.grade = pd.job.label or pd.job.name, pd.job.grade_label end
            d.cash = num(pd.money)
            for _, a in ipairs(pd.accounts or {}) do
                if a.name == 'money' and d.cash == nil then d.cash = num(a.money)
                elseif a.name == 'bank' then d.bank = num(a.money)
                elseif a.name == (cfg.BlackAccount or 'black_money') then d.black = num(a.money) end
            end
        end
    elseif LNGX.fw == 'qb' or LNGX.fw == 'qbox' then
        local ok, pd = pcall(qbPlayerData)
        if ok and pd then
            if pd.job then
                d.job = pd.job.label or pd.job.name
                d.grade = type(pd.job.grade) == 'table' and pd.job.grade.name or nil
            end
            if pd.money then d.cash, d.bank = num(pd.money.cash), num(pd.money.bank) end
        end
    end
    return d
end

function LNGX.refreshInfo(force)
    local cfg = Config.PlayerInfo
    local on = cfg and cfg.Enabled ~= false and LNGX.settings and LNGX.settings.info ~= false
    if not on then
        if sig ~= 'off' or force then sig = 'off'; SendNUIMessage({ action = 'info', data = { show = false } }) end
        return
    end
    local d = collect()
    local s = table.concat({ tostring(d.id), tostring(d.job), tostring(d.grade), tostring(d.cash), tostring(d.bank), tostring(d.black) }, '|')
    if s == sig and not force then return end
    sig = s
    d.show = true
    SendNUIMessage({ action = 'info', data = d })
end

function LNGX.infoReset() sig = nil end

function LNGX.infoConfig()
    local c = Config.PlayerInfo
    if type(c) ~= 'table' then return { enabled = false } end
    return { enabled = c.Enabled ~= false, position = c.Position, x = c.X, y = c.Y, show = c.Show,
        currency = c.Currency, locale = c.Locale }
end

local infoQueued = false
local function queueInfo()
    if infoQueued then return end
    infoQueued = true
    SetTimeout(150, function()
        infoQueued = false
        LNGX.refreshInfo()
    end)
end
RegisterNetEvent('esx:setAccountMoney', queueInfo)
RegisterNetEvent('esx:setJob', queueInfo)
RegisterNetEvent('QBCore:Player:SetPlayerData', queueInfo)
RegisterNetEvent('QBCore:Client:OnJobUpdate', queueInfo)

CreateThread(function()
    while true do
        if LNGX.loaded then LNGX.refreshInfo() end
        Wait((Config.PlayerInfo and Config.PlayerInfo.Tick) or 1500)
    end
end)
