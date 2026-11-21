local function fwName()
    local fw = Config.Framework or 'auto'
    if fw ~= 'auto' then return fw end
    for _, k in ipairs({ 'esx', 'qb', 'qbox' }) do
        if GetResourceState(Config.Resources[k]) == 'started' then return k end
    end
    return 'standalone'
end

local function isAdmin(src)
    local groups = (Config.AdminHud and Config.AdminHud.Groups) or { 'admin', 'superadmin', 'god' }
    local fw = fwName()

    if fw == 'esx' then
        local ok, ESX = pcall(function() return exports[Config.Resources.esx]:getSharedObject() end)
        local xp = ok and ESX and ESX.GetPlayerFromId(src)
        local g = xp and xp.getGroup and xp.getGroup()
        if g then for _, v in ipairs(groups) do if g == v then return true end end end
    elseif fw == 'qb' then
        local ok, QB = pcall(function() return exports[Config.Resources.qb]:GetCoreObject() end)
        if ok and QB and QB.Functions and QB.Functions.HasPermission then
            for _, v in ipairs(groups) do if QB.Functions.HasPermission(src, v) then return true end end
        end
    elseif fw == 'qbox' then
        for _, v in ipairs(groups) do
            local ok, res = pcall(function() return exports[Config.Resources.qbox]:HasPermission(src, v) end)
            if ok and res then return true end
        end
    end

    return IsPlayerAceAllowed(src, 'command')
end

RegisterNetEvent('lngx-hud:adminRequest', function()
    local src = source
    if isAdmin(src) then
        TriggerClientEvent('lngx-hud:adminOpen', src)
    else
        TriggerClientEvent('lngx-hud:adminDenied', src)
    end
end)

local KVP = 'lngx-hud:adminhud:v1'
local LOC_KEYS = { 'left', 'bottom', 'width', 'style', 'ry', 'gap', 'span', 'overlap' }
local BORDER_KEYS = { 'left', 'bottom', 'width', 'height', 'radius' }

local function num(v)
    v = tonumber(v)
    if not v or v ~= v or v < -2000 or v > 5000 then return nil end
    if v % 1 == 0 then return math.floor(v) end
    return math.floor(v * 100 + 0.5) / 100
end

local function numstr(v)
    if v % 1 == 0 then return ('%d'):format(v) end
    local r = ('%.2f'):format(v):gsub('0+$', '')
    return r
end

local function clean(t, order)
    if type(t) ~= 'table' then return nil end
    local r, n = {}, 0
    for _, k in ipairs(order) do
        local v = t[k]
        if k == 'style' then
            if v == 'arc' or v == 'pill' then r.style = v; n = n + 1 end
        elseif v ~= nil then
            local x = num(v)
            if x == nil then return nil end
            r[k] = x; n = n + 1
        end
    end
    return n > 0 and r or nil
end

local function fmt(t, order)
    local parts = {}
    for _, k in ipairs(order) do
        local v = t[k]
        if v ~= nil then
            parts[#parts + 1] = (k == 'style') and ("style = '%s'"):format(v) or ('%s = %s'):format(k, numstr(v))
        end
    end
    return '{ ' .. table.concat(parts, ', ') .. ' }'
end

local function loadLayout()
    local raw = GetResourceKvpString(KVP)
    if not raw or raw == '' then return nil end
    local ok, d = pcall(json.decode, raw)
    return (ok and type(d) == 'table') and d or nil
end

RegisterNetEvent('lngx-hud:requestLayout', function()
    local d = loadLayout()
    if d then TriggerClientEvent('lngx-hud:layout', source, d) end
end)

local function patchConfig(d)
    local res = GetCurrentResourceName()
    local old = LoadResourceFile(res, 'config.lua')
    if not old then return false end
    local new = {
        loc = { square = fmt(d.loc.square, LOC_KEYS), circle = fmt(d.loc.circle, LOC_KEYS) },
        border = { square = fmt(d.border.square, BORDER_KEYS), circle = fmt(d.border.circle, BORDER_KEYS) },
    }
    local thick = numstr(d.border.Thick)
    local out, block, done = {}, nil, 0
    for line in (old .. (old:sub(-1) == '\n' and '' or '\n')):gmatch('([^\n]*)\n') do
        if line:match('^Config%.LocationPosition%s*=%s*{') then block = 'loc'
        elseif line:match('^Config%.MapBorder%s*=%s*{') then block = 'border'
        elseif line:match('^}') then block = nil
        elseif block then
            local ind, name, eq, tail = line:match('^(%s*)(%a+)(%s*=%s*)%b{}(.*)$')
            if (name == 'square' or name == 'circle') and new[block][name] then
                line = ind .. name .. eq .. new[block][name] .. tail
                done = done + 1
            elseif block == 'border' then
                local pre, rest = line:match('^(%s*Thick%s*=%s*)[%d%.%-]+(.*)$')
                if pre then line = pre .. thick .. rest; done = done + 1 end
            end
        end
        out[#out + 1] = line
    end
    if done ~= 5 then return false end
    SaveResourceFile(res, 'config.lua.bak', old, -1)
    return SaveResourceFile(res, 'config.lua', table.concat(out, '\n') .. (old:sub(-1) == '\n' and '\n' or ''), -1) and true or false
end

RegisterNetEvent('lngx-hud:adminSave', function(data)
    local src = source
    local function reply(ok, msg) TriggerClientEvent('lngx-hud:adminSaved', src, ok, msg) end
    if not isAdmin(src) then return reply(false, LNGX.L('admin.denied_save')) end
    if type(data) ~= 'table' or type(data.loc) ~= 'table' or type(data.border) ~= 'table' then
        return reply(false, LNGX.L('admin.invalid_data'))
    end

    local d = {
        loc = { square = clean(data.loc.square, LOC_KEYS), circle = clean(data.loc.circle, LOC_KEYS) },
        border = {
            Thick = num(data.border.Thick),
            square = clean(data.border.square, BORDER_KEYS),
            circle = clean(data.border.circle, BORDER_KEYS),
        },
    }
    if not (d.loc.square and d.loc.circle and d.border.square and d.border.circle and d.border.Thick) then
        return reply(false, LNGX.L('admin.invalid_value'))
    end

    SetResourceKvp(KVP, json.encode(d))
    local fileOk = patchConfig(d)
    TriggerClientEvent('lngx-hud:layout', -1, d)
    print(('[lngx-hud] layout /adminhud disimpan oleh player %s (config.lua: %s)'):format(src, fileOk and 'diperbarui' or 'tidak diubah, memakai data server'))
    reply(true, fileOk and LNGX.L('admin.saved_file') or LNGX.L('admin.saved_kvp'))
end)
