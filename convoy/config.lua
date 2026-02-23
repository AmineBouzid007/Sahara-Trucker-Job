ConvoyConfig = {} -- Rename to ConvoyConfig to avoid clashing with SoloConfig

-- =====================================================
-- GENERAL SETTINGS
-- =====================================================
ConvoyConfig.MaxDailyJobs = 5 
ConvoyConfig.DefaultTruck = `linerunner` 

-- =====================================================
-- NPC SETTINGS (The squad terminal location)
-- =====================================================
ConvoyConfig.NPC = {
    model = `s_m_m_trucker_01`,
    coords = vector4(-1182.51, -2205.99, 13.18, 323.14), -- Adjust if needed
    animation = {"amb@world_human_clipboard@male@base", "base"}
}

-- =====================================================
-- JOB POOL CONFIGURATION
-- =====================================================
ConvoyConfig.JobPool = {
    { 
        name = "Fuel Delivery", 
        type = "fuel", 
        img = "images/trailers/tanker.png", 
        basePrice = 500, 
        minLevel = 1,
        trailerModel = `tanker`
    },
    { 
        name = "Logging Transport", 
        type = "logs", 
        img = "images/trailers/trailers3.png", 
        basePrice = 750, 
        minLevel = 2,
        trailerModel = `trailerlogs`
    },
    { 
        name = "Industrial Containers", 
        type = "containers", 
        img = "images/trailers/docktrailer.png", 
        basePrice = 1200, 
        minLevel = 3, 
        trailerModel = `docktrailer`
    },
    { 
        name = "General Cargo", 
        type = "cargo", 
        img = "images/trailers/trailers2.png", 
        basePrice = 900, 
        minLevel = 2,
        trailerModel = `trailers2`
    }
}

-- =====================================================
-- SPAWN SETTINGS (Preventing Explosions)
-- =====================================================
ConvoyConfig.TruckSpawn = vector4(-1170.3165, -2210.9538, 13.18, 328.81)

-- Multiple points for trailers to support Convoy spawning
ConvoyConfig.TrailerSpawnPoints = {
    vector4(-1160.0, -2200.0, 13.18, 320.0),
    vector4(-1155.0, -2205.0, 13.18, 320.0),
    vector4(-1150.0, -2210.0, 13.18, 320.0),
    vector4(-1145.0, -2215.0, 13.18, 320.0),
}

-- =====================================================
-- UI & VISUALS
-- =====================================================
ConvoyConfig.CurrencySymbol = "$"
ConvoyConfig.DistanceUnit = "km"
ConvoyConfig.Debug = false 
