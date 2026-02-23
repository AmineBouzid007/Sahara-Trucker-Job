SoloConfig = {} 

-- =====================================================
-- [01] TERMINAL NPC SETTINGS
-- =====================================================
SoloConfig.NPC = {
    model = `s_m_m_trucker_01`,
    coords = vector4(-1182.51, -2205.99, 13.18, 323.14),
    animation = {"amb@world_human_clipboard@male@base", "base"},
    blip = {
        sprite = 477, 
        color = 3, 
        scale = 0.8,
        name = "Personal Logistics Terminal"
    }
}

-- =====================================================
-- [02] STATIC CONTRACT DATABASE (FIXED NAME)
-- =====================================================
SoloConfig.StaticJobs = { -- MATCHES SERVER.LUA
    { 
        id = 1, 
        name = "Liquid Energy Sync", 
        type = "fuel", 
        streetNames = "HIGHWAY_21", 
        totalPrice = 300, 
        kmEarnings = 10, 
        imgSrc = "images/trailers/tanker.png", 
        level = 1, 
        distance = 5.0 
    },
    { 
        id = 2, 
        name = "Timber Extraction", 
        type = "logs", 
        streetNames = "DOWNTOWN_CORE", 
        totalPrice = 450, 
        kmEarnings = 15, 
        imgSrc = "images/trailers/trailers3.png", 
        level = 1, 
        distance = 8.0 
    },
    { 
        id = 3, 
        name = "Heavy Shielding", 
        type = "containers", 
        streetNames = "AIRPORT_DRIVE", 
        totalPrice = 600, 
        kmEarnings = 20, 
        imgSrc = "images/trailers/docktrailer.png", 
        level = 3, -- Requires Rank 3
        distance = 12.0 
    }
}

SoloConfig.TruckSpawn = vector4(-1170.3165, -2210.9538, 13.1882, 328.8189)
SoloConfig.TrailerSpawn = vector4(-1160.0, -2200.0, 13.18, 320.0)
SoloConfig.MaxRandomJobs = 3 

-- Logic Mapping
SoloConfig.TruckModels = { ['fuel'] = `linerunner`, ['logs'] = `hauler`, ['containers'] = `phantom` }
SoloConfig.TrailerModels = { ['fuel'] = `tanker`, ['logs'] = `trailerlogs`, ['containers'] = `docktrailer` }
