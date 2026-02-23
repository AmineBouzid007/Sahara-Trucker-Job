ConvoyLocations = {}

-- =====================================================
-- [01] SQUAD SIGNAL HUB (NPC LOCATION)
-- =====================================================
ConvoyLocations.JobStart = {
    coords = vector3(-1182.51, -2205.99, 13.18), -- Network Terminal
    heading = 323.14,
    pedModel = `s_m_m_trucker_01`,
    name = "Squad Command Terminal"
}

-- =====================================================
-- [02] SQUAD SPAWN VECTORS (PREVENTING COLLISION)
-- =====================================================
ConvoyLocations.Spawns = {
    Truck = { coords = vector4(-1170.31, -2210.95, 13.18, 328.81) },
    -- Convoy trailer slots are defined in convoy/config.lua
}

-- =====================================================
-- [03] SQUAD OBJECTIVE VECTORS (DESTINATIONS)
-- =====================================================
ConvoyLocations.DeliveryPoints = {
    ['fuel'] = {
        { label = "Squad Objective: Refinery", coords = vector3(1700.5, -1500.2, 30.5) },
        { label = "Squad Objective: Terminal", coords = vector3(200.1, -1500.4, 29.0) }
    },
    ['logs'] = {
        { label = "Squad Objective: Paleto Sawmill", coords = vector3(-440.5, 6000.1, 31.0) },
        { label = "Squad Objective: Lumber Yard", coords = vector3(1200.5, 2750.3, 38.0) }
    },
    ['containers'] = {
        { label = "Squad Objective: Terminal A", coords = vector3(1000.5, -2500.2, 15.0) },
        { label = "Squad Objective: Terminal B", coords = vector3(810.3, -2400.4, 28.5) }
    },
    ['cargo'] = {
        { label = "Squad Objective: Depot X", coords = vector3(1200.5, 2750.3, 38.0) }
    }
}

-- Mapping for Logic
ConvoyLocations.TruckModels = {
    ['fuel'] = `linerunner`,
    ['logs'] = `linerunner`,
    ['containers'] = `linerunner`,
    ['cargo'] = `linerunner`
}

ConvoyLocations.TrailerModels = {
    ['fuel'] = `tanker`,
    ['logs'] = `trailerlogs`,
    ['containers'] = `docktrailer`,
    ['cargo'] = `trailers2`
}
