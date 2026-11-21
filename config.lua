Config = {}

-- SELECT EN OR ID
Config.Language = 'en'


-- FRAMEWORK = esx,qb,qbox, auto (otomatis)
Config.Framework = 'auto'

Config.Resources = {
    esx  = 'es_extended',
    qb   = 'qb-core',
    qbox = 'qbx_core',
}

-- ============ MINIMAP ============
Config.MapShape = 'square'             -- 'square' or 'circle'
Config.OnlyInVehicle = false           -- true = minimap show only in vehicle
Config.HideWhenPaused = true           -- hide the HUD when the pause menu is opened
Config.Zoom = 1000                     -- zoom radar
Config.MapOffsetY = -0.005             -- High-resolution screen, so it automatically fits all resolutions.
Config.HideMapBlips = true             -- hide all items/blips on the minimap (they will still appear on the pause menu map)
Config.MinimapWaypoint = true          -- true = the waypoint icon remains visible on the minimap even when other blips are hidden (HideMapBlips); false = it is hidden along with them
Config.HidePlayerBlip = false          -- true = the player position icon on the minimap is also hidden
Config.MapShapeCommand = 'false'        -- /mapshape square|circle (nil/false = disable command)

Config.RadioOffOnEnter = true     -- true = vehicle radio automatically turns OFF when a player enters (can be turned on manually); false = GTA default

-- ============ NOTIFIKASI ============
Config.Notify = 'auto' -- 'ox' | 'esx' | 'qb' | 'qbox' | 'native' | 'auto (otomatis)'
Config.NotifyDuration = 3000  

-- ============ HUD ============
Config.HudPosition = {
    square = { left = 26, bottom = 6 },
    circle = { left = 42, bottom = 6 },
}
Config.SettingsCommand = 'hud'    -- /hud open hud. false or nil 

-- ============ BRAND SERVER NAME ============
Config.ServerBrand = {
    Enabled  = true,
    Name     = 'LNGX',            -- NAME SERVER or '' to hide
    Subtitle = 'ROLEPLAY',        
    Position = 'top-right',       -- 'top-left' | 'top-center' | 'top-right' | 'bottom-left' | 'bottom-center' | 'bottom-right'
    X = 24, Y = 22,               
}

-- ============ LOGO SERVER ============
Config.ServerLogo = {
    Enabled  = true,
    File     = 'logo.png',
    Size     = 96,                
    Round    = false,            
    Position = 'top-left',        
    X = 24, Y = 22,
}

-- ============ INFO PEMAIN (ID, job, cash, bank) ============
Config.PlayerInfo = {
    Enabled  = true,
    Position = 'top-right',       -- 'top-left' | 'top-center' | 'top-right' | 'bottom-left' | 'bottom-center' | 'bottom-right'
    X = 24, Y = 84,               
    Currency = '$',               -- currency symbol (mis. 'Rp')
    Locale   = 'en-US',           -- format number: 'en-US' = 1,234 | 'id-ID' = 1.234
    Show = { id = true, job = true, cash = true, bank = true, black = true },   
    BlackAccount = 'black_money', 
    Tick = 5000,                 
}

-- ============ ICON WEAPON ============
Config.Weapon = {
    Enabled  = true,
    Position = 'top-right',       -- 'top-left' | 'top-center' | 'top-right' | 'bottom-left' | 'bottom-center' | 'bottom-right'
    X = 24, Y = 292,              
    Tick = 200,                   
    ShowAmmo = true,              -- show amount bullet
    ShowName = true,              -- show name weapon
    HideInVehicle = false,        -- true = hide while inside a vehicle
    LowAmmo = 0.25,               -- The bullet count turns red when the magazine is ≤ 25% (0 = only when empty)
    Hide = { 'weapon_unarmed', 'gadget_parachute' },   -- a weapon that does not display an icon
    Names = {}, -- Custom names (for addon weapons): Names = { weapon_xxx = 'DISPLAY NAME' }; Icons = { weapon_xxx = 'rifle' }
    Icons = {}, -- Icon type: gun | smg | rifle | mg | shotgun | sniper | heavy | melee | thrown | tools
}

-- ============ PERFORMA ============
Config.StatusTick  = 250          
Config.VehicleTick = 100          
Config.BlipBackupInterval = 3000  

-- ============ SPEEDOMETER ============
Config.SpeedUnit = 'kmh'          -- 'kmh' | 'mph'
Config.ShowSpeedoAsPassenger = false  
Config.Fuel = 'auto' -- 'LegacyFuel', 'cdn-fuel', 'ps-fuel')
Config.FuelStatebag = 'fuel'
Config.FuelResources = { 'LegacyFuel', 'cdn-fuel', 'ps-fuel' }
Config.Nav = {
    Enabled = true,
    ArrivalRadius = 30,           
}

Config.LocationPosition = {
    square = { left = 28, bottom = 264, width = 312 },   
    circle = { left = 42, bottom = 314, width = 291, style = 'arc', ry = 133, gap = 18, span = 50, overlap = 20 },
}

Config.MapBorder = {
    Enabled = true,               
    Thick   = 3,                  
    Color   = 'rgba(255,255,255,.55)',   
    Glow    = 'rgba(47,155,255,.25)',   
    Shadow  = true,               
    square  = { left = 28, bottom = 66, width = 312, height = 198, radius = 6 },
    circle  = { left = 42, bottom = 82, width = 291, height = 244 }, 
}

Config.StatusStyle = 'line'
Config.SpeedoStyle = 'round'

Config.LineHud = {
    Enabled = true,                
    Height  = 11,                  
    Height2 = 5,                   
    Gap     = 3,                   
    RowGap  = 7,                   
    Rounded = false,               
    Radius  = 5,                  
    square  = { left = 27, bottom = 50, width = 314 },    
    circle  = { left = 42, bottom = 50, width = 291 },
    Show = { health = true, armor = true, hunger = true, thirst = true, stress = true, stamina = true, oxygen = true },
    HideWhenEmpty = { stress = true },
    HideWhenFull = { stamina = true, oxygen = true },
    Colors = {
        health = '#F3163E', armor = '#00A3FF', hunger = '#ADFE00', thirst = '#00FFF0',
        stress = '#FF0099', stamina = '#FFA048', oxygen = '#5AC8FA',
    },
    LowAt = 17,                   
}

Config.AdminHud = {
    Command = 'adminhud',         -- false = disable command
    Groups = { 'admin', 'superadmin', 'god' },   -- framework admin group (ESX group / QBCore & Qbox permission) that can open
}
Config.ShowLocation = true        

Config.Route = {
    Rgba = { { 255, 64, 160 }, { 255, 150, 205 }, { 150, 30, 95 } },   -- pink
    HideDistance = true,      
    HideDistanceInterval = 0, 
}
-- ============ SPEEDOMETER PLANE ============
Config.Plane = {
    Enabled = true,            
    Classes = { 15, 16 },      
    Seatbelt = true,          
    EjectOnCrash = false,     
    Cruise = true,             
    CruiseMinSpeed = 50,       
    CruiseMinSpeedHeli = 25,   
    CruiseMinHeight = 15.0,    
    NavArrival = 150,          
    CruiseCrashDrop = 60,     
    Position = { right = 40, bottom = 34, scale = 0.42 },
    Tick = 50,                 
    InvertRoll = false,        
    StallSpeed = 70,           
    StallMinHeight = 12.0,     
    NoStallModels = { 'hydra', 'avenger', 'avenger2', 'blimp', 'blimp2', 'blimp3' }, 
    AutoFlaps = true,
}

Config.FlightPath = {
    Enabled = true,            
    Mode = 'line',             
    LineWidth = 14.0,          
    Alpha = 190,               
    LineStep = 25.0,          
    LineInvertRotation = false,  
    Spacing = 120.0,           
    MaxBlips = 60,            
    MinDistance = 150.0,       
    Interval = 500,            
    Sprite = 1,                
    Scale = 0.4,               
    Colour = 8,                
}

Config.NoSeatbeltClasses = { 8, 13, 14, 15, 16, 21 }
 
Config.Seatbelt = {
    Enabled = true,            
    Key = 'B',                
    Command = 'lngx-seatbelt',
    BlockExit = true,         
    Sound = true,             
    Volume = 0.6,              
    Notify = true,             
    Eject = true,              
    EjectSpeed = 70,          
    EjectDrop = 40,            
    EjectDamage = 25,         
}

Config.Cruise = {
    Enabled = true,            
    Key = 'CAPITAL',           
    Command = 'lngx-cruise',
    MinSpeed = 30,            
    CrashDrop = 20,           
    BlockClasses = { 13, 14, 15, 16, 21 },   
    Sound = true,              
    Notify = true,             
}

Config.VehicleControl = {
    Enabled = true,            
    Command = 'vehmenu',       
    Key = '',                  
    Range = 6.0,              
}
