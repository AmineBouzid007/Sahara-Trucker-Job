
local ESX = exports['es_extended']:getSharedObject()

-- =====================================================
-- [01] DATA STORAGE & EXPORT
-- =====================================================
local ActiveConvoys = {} 
local ConvoyJobPool = {} 

exports('getConvoyJobs', function()
    return ConvoyJobPool
end)

-- =====================================================
-- [02] GENERATORS & SETUP
-- =====================================================
local function GenerateUniqueID()
    local newID
    while true do
        newID = math.random(1111, 9999) 
        if not ActiveConvoys[newID] then return newID end
    end
end

local function GenerateConvoyContracts()
    if not ConvoyConfig or not ConvoyConfig.JobPool then return false end
    ConvoyJobPool = {}
    math.randomseed(os.time())
    local poolSize = #ConvoyConfig.JobPool
    if poolSize == 0 then return false end
    for i = 1, (ConvoyConfig.MaxDailyJobs or 5) do
        local base = ConvoyConfig.JobPool[math.random(1, poolSize)]
        if base then
            table.insert(ConvoyJobPool, {
                id = 2000 + i, name = "SQUAD_OP: " .. (base.name or "Cargo"), type = base.type, streetNames = "HIGH_SECURITY_SECTOR", totalPrice = (base.basePrice or 600) + math.random(200, 500), level = base.minLevel or 1, distance = math.random(10, 25), imgSrc = base.img, trailerModel = base.trailerModel
            })
        end
    end
    print("^4[Convoy System]^7 Uplink established. " .. #ConvoyJobPool .. " squad contracts ready.")
    return true
end
CreateThread(function()
    while not GenerateConvoyContracts() do
        Wait(2000)
    end
end)

-- =====================================================
-- [03] SESSION MANAGEMENT
-- =====================================================
RegisterNetEvent('truckjob:server:createConvoy', function()
    local src = source
    local uniqueID = GenerateUniqueID()
    ActiveConvoys[uniqueID] = { leader = src, members = { {name = GetPlayerName(src) .. " (Leader)", id = src, isLeader = true} }, currentJob = nil }
    TriggerClientEvent('truckjob:client:updateConvoyPlayers', src, ActiveConvoys[uniqueID].members, uniqueID)
end)

RegisterNetEvent('truckjob:server:joinConvoy', function(convoyID)
    local src = source
    local cID = tonumber(convoyID)
    if ActiveConvoys[cID] then
        table.insert(ActiveConvoys[cID].members, {name = GetPlayerName(src), id = src, isLeader = false})
        for _, m in ipairs(ActiveConvoys[cID].members) do TriggerClientEvent('truckjob:client:updateConvoyPlayers', m.id, ActiveConvoys[cID].members, cID) end
        if ActiveConvoys[cID].currentJob then TriggerClientEvent('truckjob:client:syncConvoyJob', src, ActiveConvoys[cID].currentJob) end
    else
        TriggerClientEvent('truckjob:client:joinFailed', src)
    end
end)

RegisterNetEvent('truckjob:server:selectJob', function(data)
    local src = source
    local cID = tonumber(data.convoyID)
    if cID and ActiveConvoys[cID] and ActiveConvoys[cID].leader == src then
        ActiveConvoys[cID].currentJob = data.jobData
        for _, member in ipairs(ActiveConvoys[cID].members) do
            if member.id ~= src then TriggerClientEvent('truckjob:client:syncConvoyJob', member.id, data.jobData) end
        end
    end
end)

-- =====================================================
-- [04] SQUAD DEPLOYMENT (WITH ON-SCREEN NOTIFICATIONS)
-- =====================================================
RegisterNetEvent('truckjob:server:requestConvoyStart', function()
    local src = source
    local convoyData = nil
    for id, data in pairs(ActiveConvoys) do
        if data.leader == src then convoyData = data; break end
    end

    if not convoyData then
        TriggerClientEvent('ox_lib:notify', src, { id = 'truck_err', title='SERVER FAIL', description = 'You are not a convoy leader.', type = 'error' })
        return
    end

    if not convoyData.currentJob then
        TriggerClientEvent('ox_lib:notify', src, { id = 'truck_err', title='SERVER FAIL', description = 'No contract has been selected.', type = 'error' })
        return
    end

    if #convoyData.members < 1 then
        TriggerClientEvent('ox_lib:notify', src, { 
            id = 'truck_err', 
            title='SERVER FAIL', 
            description = 'Not enough members (need at least 1 for test).', 
            type = 'error' 
        })
        return
    end
    
    local jobData = convoyData.currentJob
    local jobType = jobData.type
    local truckModel = ConvoyConfig.TruckModels and ConvoyConfig.TruckModels[jobType] or 'phantom'
    local trailerModel = jobData.trailerModel or 'tanker'

    if not jobType or not truckModel or not trailerModel then
        TriggerClientEvent('ox_lib:notify', src, { id = 'truck_err', title='SERVER FAIL', description = "Job data is incomplete (missing type, truck, or trailer model).", type = 'error' })
        return
    end

    local deliveryPoints = ConvoyLocations.DeliveryPoints[jobType]
    if not deliveryPoints or #deliveryPoints == 0 then
        TriggerClientEvent('ox_lib:notify', src, { id = 'truck_err', title='SERVER FAIL', description = "No delivery points found for job type: " .. jobType, type = 'error' })
        return
    end
    
    TriggerClientEvent('ox_lib:notify', src, { id = 'truck_ok', title='SERVER PASS', description = 'All checks passed. Spawning vehicles...', type = 'success' })
    Wait(1000)
    
    local sharedDestIndex = math.random(#deliveryPoints)

    print("[CONVOY] Starting mission for", #convoyData.members, "players")
    for i, member in ipairs(convoyData.members) do
        local truckSpawn = vector4(ConvoyConfig.TruckSpawn.x + ((i - 1) * 8.0), ConvoyConfig.TruckSpawn.y, ConvoyConfig.TruckSpawn.z, ConvoyConfig.TruckSpawn.w)
        local trailerSpawn = ConvoyConfig.TrailerSpawnPoints[i] or ConvoyConfig.TrailerSpawnPoints[#ConvoyConfig.TrailerSpawnPoints]

        local truck = CreateVehicle(joaat(truckModel), truckSpawn.x, truckSpawn.y, truckSpawn.z, truckSpawn.w, true, true)
        local trailer = CreateVehicle(joaat(trailerModel), trailerSpawn.x, trailerSpawn.y, trailerSpawn.z, trailerSpawn.w, true, true)
        
        local timeout = 0
        while not DoesEntityExist(truck) or not DoesEntityExist(trailer) do Wait(50); timeout = timeout + 50; if timeout > 2000 then break end end

        if DoesEntityExist(truck) and DoesEntityExist(trailer) then
            SetVehicleNumberPlateText(truck, "SQD-" .. member.id)
            TriggerClientEvent('truckjob:convoy:client:beginMission', member.id, NetworkGetNetworkIdFromEntity(truck), NetworkGetNetworkIdFromEntity(trailer), jobType, sharedDestIndex)
        else
            TriggerClientEvent('ox_lib:notify', member.id, { id = 'truck_err', title='CRITICAL FAIL', description = "Could not create vehicles.", type = 'error' })
        end
    end
end)

-- =====================================================
-- [05] CLEANUP HANDLER
-- =====================================================
local function HandleDeparture(src)
    for id, data in pairs(ActiveConvoys) do
        for i, m in ipairs(data.members) do
            if m.id == src then
                if data.leader == src then
                    for _, member in ipairs(data.members) do TriggerClientEvent('truckjob:client:joinFailed', member.id) end
                    ActiveConvoys[id] = nil
                else
                    table.remove(data.members, i)
                    for _, member in ipairs(data.members) do TriggerClientEvent('truckjob:client:updateConvoyPlayers', member.id, data.members, id) end
                end
                return
            end
        end
    end
end
RegisterNetEvent('truckjob:server:leaveConvoy', function() HandleDeparture(source) end)
AddEventHandler('playerDropped', function() HandleDeparture(source) end)
