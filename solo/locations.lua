SoloLocations = {}

-- =====================================================
-- [01] SECTOR DEPLOYMENT POINT (NPC LOCATION)
-- =====================================================
SoloLocations.JobStart = {
    coords = vector3(-1182.51, -2205.99, 13.18), -- Personal Terminal
    heading = 323.14,
    pedModel = `s_m_m_trucker_01`,
    name = "Personal Logistics Node"
}

-- =====================================================
-- [02] INDIVIDUAL SPAWN VECTORS
-- =====================================================
SoloLocations.Spawns = {
    Truck = { coords = vector4(-1170.31, -2210.95, 13.18, 328.81) },
    Trailer = { coords = vector4(-1160.0, -2200.0, 13.18, 320.0) }
}

-- =====================================================
-- [03] SOLO TARGET VECTORS (DESTINATIONS)
-- =====================================================
SoloLocations.DeliveryPoints = {
    ['fuel'] = {
        { label = "Fuel Node Alpha", coords = vector3(49.2, 2778.1, 58.0) },
        { label = "Fuel Node Beta", coords = vector3(200.1, -1500.4, 29.0) }
    },
    ['logs'] = {
        { label = "Processing Plant 1", coords = vector3(-563.2, 5342.2, 70.5) },
        { label = "Processing Plant 2", coords = vector3(1200.5, 2750.3, 38.0) }
    },
    ['containers'] = {
        { label = "Port Hub A", coords = vector3(-880.2, -2370.5, 13.0) },
        { label = "Port Hub B", coords = vector3(810.3, -2400.4, 28.5) }
    },
    ['biggoods'] = {
        { label = "Warehouse Terminal 1", coords = vector3(100.2, -300.0, 45.0) }
    },
    ['generic'] = {
        { label = "Central Hub", coords = vector3(215.3, -810.2, 30.7) }
    }
}

-- Mapping for logic simplification
SoloLocations.TruckModels = {
    ['fuel'] = `linerunner`,
    ['logs'] = `linerunner`,
    ['containers'] = `linerunner`,
    ['biggoods'] = `hauler`,
    ['generic'] = `packer`
}

SoloLocations.TrailerModels = {
    ['fuel'] = `tanker`,
    ['logs'] = `trailerlogs`,
    ['containers'] = `docktrailer`,
    ['biggoods'] = `trailers3`,
    ['generic'] = `trailers`
}
