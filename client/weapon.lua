LNGX = LNGX or {}

local floor = math.floor
local function H(n) return joaat(n) & 0xFFFFFFFF end

local GROUP = {
    [416676503]  = 'pistol',
    [690389602]  = 'pistol',
    [3337201093] = 'smg',
    [970310034]  = 'rifle',
    [1159398588] = 'mg',
    [860033945]  = 'shotgun',
    [3082541095] = 'sniper',
    [2725924767] = 'heavy',
    [3566412244] = 'melee',
    [1548507267] = 'thrown',
    [1595662460] = 'tool',
    [4257178988] = 'tool',
}
local GROUP_LABEL = {
    pistol = 'PISTOL', smg = 'SMG', rifle = 'RIFLE', mg = 'MACHINE GUN', shotgun = 'SHOTGUN',
    sniper = 'SNIPER', heavy = 'HEAVY WEAPON', melee = 'MELEE', thrown = 'THROWABLE', tool = 'TOOL',
}
local NO_CLIP = { melee = true, thrown = true, tool = true }

local NAMES = {
    pistol = 'PISTOL', pistol_mk2 = 'PISTOL MK II', combatpistol = 'COMBAT PISTOL', appistol = 'AP PISTOL',
    pistol50 = 'PISTOL .50', snspistol = 'SNS PISTOL', snspistol_mk2 = 'SNS PISTOL MK II', heavypistol = 'HEAVY PISTOL',
    vintagepistol = 'VINTAGE PISTOL', marksmanpistol = 'MARKSMAN PISTOL', revolver = 'HEAVY REVOLVER', revolver_mk2 = 'REVOLVER MK II',
    doubleaction = 'DOUBLE ACTION', ceramicpistol = 'CERAMIC PISTOL', navyrevolver = 'NAVY REVOLVER', gadgetpistol = 'PERICO PISTOL',
    stungun = 'STUN GUN', flaregun = 'FLARE GUN',
    microsmg = 'MICRO SMG', smg = 'SMG', smg_mk2 = 'SMG MK II', assaultsmg = 'ASSAULT SMG', combatpdw = 'COMBAT PDW',
    machinepistol = 'MACHINE PISTOL', minismg = 'MINI SMG', gusenberg = 'GUSENBERG',
    assaultrifle = 'ASSAULT RIFLE', assaultrifle_mk2 = 'ASSAULT RIFLE MK II', carbinerifle = 'CARBINE RIFLE', carbinerifle_mk2 = 'CARBINE RIFLE MK II',
    advancedrifle = 'ADVANCED RIFLE', specialcarbine = 'SPECIAL CARBINE', specialcarbine_mk2 = 'SPECIAL CARBINE MK II',
    bullpuprifle = 'BULLPUP RIFLE', bullpuprifle_mk2 = 'BULLPUP RIFLE MK II', compactrifle = 'COMPACT RIFLE', militaryrifle = 'MILITARY RIFLE',
    mg = 'MG', combatmg = 'COMBAT MG', combatmg_mk2 = 'COMBAT MG MK II',
    pumpshotgun = 'PUMP SHOTGUN', pumpshotgun_mk2 = 'PUMP SHOTGUN MK II', sawnoffshotgun = 'SAWN-OFF SHOTGUN', assaultshotgun = 'ASSAULT SHOTGUN',
    bullpupshotgun = 'BULLPUP SHOTGUN', musket = 'MUSKET', heavyshotgun = 'HEAVY SHOTGUN', dbshotgun = 'DOUBLE BARREL', autoshotgun = 'SWEEPER SHOTGUN',
    sniperrifle = 'SNIPER RIFLE', heavysniper = 'HEAVY SNIPER', heavysniper_mk2 = 'HEAVY SNIPER MK II', marksmanrifle = 'MARKSMAN RIFLE', marksmanrifle_mk2 = 'MARKSMAN RIFLE MK II',
    rpg = 'RPG', grenadelauncher = 'GRENADE LAUNCHER', minigun = 'MINIGUN', firework = 'FIREWORK LAUNCHER', railgun = 'RAILGUN',
    hominglauncher = 'HOMING LAUNCHER', compactlauncher = 'COMPACT LAUNCHER',
    grenade = 'GRENADE', stickybomb = 'STICKY BOMB', smokegrenade = 'SMOKE GRENADE', bzgas = 'BZ GAS', molotov = 'MOLOTOV',
    proxmine = 'PROXIMITY MINE', pipebomb = 'PIPE BOMB', flare = 'FLARE', snowball = 'SNOWBALL', ball = 'BALL',
    knife = 'KNIFE', nightstick = 'NIGHTSTICK', hammer = 'HAMMER', bat = 'BASEBALL BAT', crowbar = 'CROWBAR', golfclub = 'GOLF CLUB',
    bottle = 'BOTTLE', dagger = 'DAGGER', hatchet = 'HATCHET', knuckle = 'KNUCKLE DUSTER', machete = 'MACHETE', switchblade = 'SWITCHBLADE',
    battleaxe = 'BATTLE AXE', poolcue = 'POOL CUE', wrench = 'PIPE WRENCH', flashlight = 'FLASHLIGHT', stone_hatchet = 'STONE HATCHET',
    petrolcan = 'JERRY CAN', fireextinguisher = 'FIRE EXTINGUISHER',
}

local nameByHash, hideHash = {}, {}
local CW = Config.Weapon or {}
local keyByHash = {}
for n, label in pairs(NAMES) do nameByHash[H('weapon_' .. n)] = label; keyByHash[H('weapon_' .. n)] = 'weapon_' .. n end
for n, label in pairs(CW.Names or {}) do nameByHash[H(n)] = tostring(label):upper(); keyByHash[H(n)] = n end
local iconByHash = {}
for n, ic in pairs(CW.Icons or {}) do iconByHash[H(n)] = ic end
for _, n in ipairs(CW.Hide or { 'weapon_unarmed', 'gadget_parachute' }) do hideHash[H(n)] = true end

local sent, shown = {}, false

local function hideWeapon()
    if shown then
        shown = false
        sent = {}
        SendNUIMessage({ action = 'weapon', data = { show = false } })
    end
end

function LNGX.weaponReset() sent, shown = {}, false end

function LNGX.weaponConfig()
    local c = Config.Weapon
    if type(c) ~= 'table' then return { enabled = false } end
    return { enabled = c.Enabled ~= false, position = c.Position, x = c.X, y = c.Y }
end

CreateThread(function()
    local tick = CW.Tick or 200
    while true do
        local wait = 500
        local on = CW.Enabled ~= false and LNGX.loaded and LNGX.visible and LNGX.settings and LNGX.settings.weapon ~= false
        if on and Config.HideWhenPaused and IsPauseMenuActive() then on = false end
        if on then
            local ped = PlayerPedId()
            if CW.HideInVehicle and IsPedInAnyVehicle(ped, false) then
                hideWeapon()
            else
                local hash = GetSelectedPedWeapon(ped) & 0xFFFFFFFF
                if hash == 0 or hideHash[hash] or IsPedDeadOrDying(ped, true) then
                    hideWeapon()
                else
                    local kind = iconByHash[hash] or GROUP[GetWeapontypeGroup(hash) & 0xFFFFFFFF] or 'pistol'
                    local total = GetAmmoInPedWeapon(ped, hash) or 0
                    local clip, maxClip, reserve = nil, nil, nil
                    if kind == 'thrown' then
                        clip = total
                    elseif not NO_CLIP[kind] then
                        local _, c = GetAmmoInClip(ped, hash)
                        maxClip = GetMaxAmmoInClip(ped, hash, true)
                        clip = c or 0
                        reserve = math.max(0, total - clip)
                    end
                    local low = false
                    if clip ~= nil and kind ~= 'thrown' then
                        local th = CW.LowAmmo or 0.25
                        low = (clip <= 0) or (maxClip and maxClip > 0 and th > 0 and clip <= floor(maxClip * th))
                    elseif kind == 'thrown' then
                        low = clip <= 0
                    end
                    local d = {
                        show = true, kind = kind, key = keyByHash[hash],
                        name = CW.ShowName ~= false and (nameByHash[hash] or GROUP_LABEL[kind]) or '',
                        clip = (CW.ShowAmmo ~= false) and clip or nil,
                        reserve = (CW.ShowAmmo ~= false) and reserve or nil,
                        low = low and true or false,
                    }
                    if not shown or sent.kind ~= d.kind or sent.key ~= d.key or sent.name ~= d.name or sent.clip ~= d.clip
                        or sent.reserve ~= d.reserve or sent.low ~= d.low then
                        shown = true
                        sent = { kind = d.kind, key = d.key, name = d.name, clip = d.clip, reserve = d.reserve, low = d.low }
                        SendNUIMessage({ action = 'weapon', data = d })
                    end
                    wait = tick
                end
            end
        else
            hideWeapon()
        end
        Wait(wait)
    end
end)
