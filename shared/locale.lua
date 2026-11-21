LNGX = LNGX or {}

local function load(code)
    if type(code) ~= 'string' or not code:match('^[%w_%-]+$') then return nil end
    local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(code))
    if not raw then return nil end
    if raw:sub(1, 3) == '\239\187\191' then raw = raw:sub(4) end
    local ok, t = pcall(json.decode, raw)
    if ok and type(t) == 'table' then return t end
    print(('[lngx-hud] locales/%s.json tidak valid (cek koma / tanda kutip)'):format(code))
    return nil
end

local lang = tostring(Config.Language or 'id'):lower()
local base = load('id') or {}
local dict = (lang == 'id') and base or load(lang)
if not dict then
    print(('[lngx-hud] bahasa "%s" tidak ditemukan di locales/, memakai "id"'):format(lang))
    dict, lang = base, 'id'
end

LNGX.lang = lang

function LNGX.L(key, ...)
    local s = dict[key]
    if s == nil then s = base[key] end
    if s == nil then return key end
    if select('#', ...) > 0 then
        local ok, r = pcall(string.format, s, ...)
        return ok and r or s
    end
    return s
end

if not IsDuplicityVersion() then
    function LNGX.sendLocale()
        local t = {}
        for k, v in pairs(base) do if k:sub(1, 3) == 'ui.' then t[k] = v end end
        for k, v in pairs(dict) do if k:sub(1, 3) == 'ui.' then t[k] = v end end
        SendNUIMessage({ action = 'locale', lang = lang, t = t })
    end
end
