local ESX = exports['es_extended']:getSharedObject()

-- =====================================================
-- [01] DATA STORAGE
-- =====================================================
local ActiveConvoys = {} 
local ConvoyJobPool = {} 

-- =====================================================
-- [02] UNIQUE SIGNAL GENERATOR
-- =====================================================
local function GenerateUniqueID()
    local newID
    local isUnique = false
    while not isUnique do
        newID = math.random(1111, 9999) 
        if not ActiveConvoys[newID] then isUnique = true end
    end
    return newID
end

-- =====================================================
-- [03] DYNAMIC CONVOY CONTRACT GENERATION
-- =====================================================
local function GenerateConvoyContracts()
    -- Safety Check: Ensure config is loaded
    if not ConvoyConfig or not ConvoyConfig.JobPool then return false end
    
    ConvoyJobPool = {}
    math.randomseed(os.time())
    
    local poolSize = #ConvoyConfig.JobPool
    for i = 1, (ConvoyConfig.MaxDailyJobs or 5) do
        local base = ConvoyConfig.JobPool[math.random(1, poolSize)]
        if base then
            table.insert(ConvoyJobPool, {
                id = 2000 + i, -- Convoy IDs start at 2000
                name = "SQUAD_OP: " .. (base.name or "Cargo"),
                type = base.type,
                streetNames = "HIGH_SECURITY_SECTOR",
                totalPrice = (base.basePrice or 600) + math.random(200, 500),
                level = base.minLevel or 1,
                distance = math.random(10, 25),
                imgSrc = base.img
            })
        end
    end
    print("^4[Convoy System]^7 Uplink established. " .. #ConvoyJobPool .. " squad contracts ready.")
    return true
end

-- Initialize with a Wait-Loop to prevent empty job list
CreateThread(function()
    local success = false
    while not success do
        Wait(2000) -- Wait 2 seconds between retries
        success = GenerateConvoyContracts()
        if not success then print("^4[Convoy System] Waiting for shared configuration files...^7") end
    end
end)

-- =====================================================
-- [04] SQUAD DATA CALLBACK
-- =====================================================
ESX.RegisterServerCallback('truckjob:convoy:getData', function(source, cb)
    cb({
        serverID = source,
        player = { 
            name = GetPlayerName(source), 
            level = 1, -- Integration Point: Pull player level from DB here
            xp = 50 
        },
        randomJobs = ConvoyJobPool 
    })
end)

-- =====================================================
-- [05] SESSION MANAGEMENT
-- =====================================================

-- Host Signal
RegisterNetEvent('truckjob:server:createConvoy', function()
    local src = source
    local uniqueID = GenerateUniqueID()
    ActiveConvoys[uniqueID] = {
        leader = src,
        members = { {name = GetPlayerName(src) .. " (Leader)", id = src, isLeader = true} },
        currentJob = nil
    }
    TriggerClientEvent('truckjob:client:updateConvoyPlayers', src, ActiveConvoys[uniqueID].members, uniqueID)
end)

-- Join Signal
RegisterNetEvent('truckjob:server:joinConvoy', function(convoyID)
    local src = source
    local cID = tonumber(convoyID)
    if ActiveConvoys[cID] then
        table.insert(ActiveConvoys[cID].members, {name = GetPlayerName(src), id = src, isLeader = false})
        for _, m in ipairs(ActiveConvoys[cID].members) do
            TriggerClientEvent('truckjob:client:updateConvoyPlayers', m.id, ActiveConvoys[cID].members, cID)
        end
        -- Sync current pick
        if ActiveConvoys[cID].currentJob then
            TriggerClientEvent('truckjob:client:syncConvoyJob', src, ActiveConvoys[cID].currentJob)
        end
    else
        TriggerClientEvent('truckjob:client:joinFailed', src)
    end
end)

-- Select Job (Leader Only)
RegisterNetEvent('truckjob:server:selectJob', function(data)
    local src = source
    local cID = tonumber(data.convoyID)
    if cID and ActiveConvoys[cID] and ActiveConvoys[cID].leader == src then
        ActiveConvoys[cID].currentJob = data.jobData
        for _, member in ipairs(ActiveConvoys[cID].members) do
            if member.id ~= src then
                TriggerClientEvent('truckjob:client:syncConvoyJob', member.id, data.jobData)
            end
        end
    end
end)

-- Squad Deployment
RegisterNetEvent('truckjob:server:requestConvoyStart', function(jobType, convoyID)
    local src = source
    local cID = tonumber(convoyID)
    local sharedDest = 1
    if ConvoyLocations and ConvoyLocations.DeliveryPoints[jobType] then
        sharedDest = math.random(1, #ConvoyLocations.DeliveryPoints[jobType])
    end
    if ActiveConvoys[cID] and ActiveConvoys[cID].leader == src then
        for _, member in ipairs(ActiveConvoys[cID].members) do
            TriggerClientEvent('truckjob:client:startSyncedJob', member.id, jobType, sharedDest)
        end
    end
end)

-- =====================================================
-- [06] CLEANUP HANDLER
-- =====================================================
local function HandleDeparture(src)
    for id, data in pairs(ActiveConvoys) do
        for i, m in ipairs(data.members) do
            if m.id == src then
                if data.leader == src then
                    for _, member in ipairs(data.members) do
                        TriggerClientEvent('truckjob:client:joinFailed', member.id)
                    end
                    ActiveConvoys[id] = nil
                else
                    table.remove(data.members, i)
                    for _, member in ipairs(data.members) do
                        TriggerClientEvent('truckjob:client:updateConvoyPlayers', member.id, data.members, id)
                    end
                end
                return
            end
        end
    end
end

RegisterNetEvent('truckjob:server:leaveConvoy', function() HandleDeparture(source) end)
AddEventHandler('playerDropped', function() HandleDeparture(source) end)
