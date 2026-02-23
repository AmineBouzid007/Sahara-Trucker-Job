local ESX = exports['es_extended']:getSharedObject()

-- =====================================================
-- [01] DATA STORAGE
-- =====================================================
local SoloDynamicJobs = {} 
local ActiveSoloMissions = {} -- Tracks who is currently deployed solo

-- =====================================================
-- [02] SOLO DYNAMIC JOB GENERATION
-- =====================================================
local function GenerateSoloJobs()
    SoloDynamicJobs = {}
    math.randomseed(os.time())
    
    if not SoloConfig or not SoloConfig.StaticJobs then
        print("^1[Solo Logistics] Error: SoloConfig.StaticJobs is missing! Check solo/config.lua.^7")
        return false
    end

    local poolSize = #SoloConfig.StaticJobs
    if poolSize == 0 then return false end

    local maxJobs = SoloConfig.MaxRandomJobs or 3
    for i = 1, maxJobs do
        local base = SoloConfig.StaticJobs[math.random(1, poolSize)]
        
        if base then
            table.insert(SoloDynamicJobs, {
                id = 500 + i, 
                name = "PRIVATE: " .. (base.name or "Cargo") .. " #" .. math.random(10, 99),
                type = base.type or "legal",
                totalPrice = (base.totalPrice or 400) + math.random(20, 100),
                imgSrc = base.imgSrc or "images/trailers/tanker.png",
                level = base.level or 1,
                distance = math.random(2, 8),
                streetNames = base.streetNames or "LOCAL_SECTOR"
            })
        end
    end
    print("^2[Solo Logistics]^7 System ready. " .. #SoloDynamicJobs .. " private contracts encrypted.")
    return true
end

CreateThread(function()
    local attempts = 0
    while attempts < 10 do
        if SoloConfig and SoloConfig.StaticJobs then
            if GenerateSoloJobs() then break end
        end
        attempts = attempts + 1
        Wait(2000)
    end
end)

-- =====================================================
-- [03] SOLO DATA CALLBACK
-- =====================================================
ESX.RegisterServerCallback('truckjob:solo:getData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end

    cb({
        serverID = source,
        player = {
            name = xPlayer.getName(),
            level = 1, 
            xp = 25
        },
        jobs = SoloConfig.StaticJobs, 
        randomJobs = SoloDynamicJobs  
    })
end)

-- =====================================================
-- [04] SOLO ECONOMY & PAYMENTS
-- =====================================================
RegisterNetEvent('truckjob:solo:pay', function(amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    local maxSoloPay = 3500
    if amount > maxSoloPay then 
        print(("^1[Security] %s attempted to exploit Solo payment: $%s^7"):format(GetPlayerName(src), amount))
        amount = maxSoloPay 
    end

    xPlayer.addMoney(amount)
    ActiveSoloMissions[src] = nil -- Mark mission as finished in server memory
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'TERMINAL_UPLINK',
        description = 'Credits transferred: $' .. amount,
        type = 'success'
    })

    TriggerClientEvent('truckjob:solo:updateStats', src, { level = 1, xp = 40 })
end)

-- Tracks when a player starts a solo job
RegisterNetEvent('truckjob:solo:startMission', function()
    local src = source
    ActiveSoloMissions[src] = true
end)

-- =====================================================
-- [05] LOGGING
-- =====================================================
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    print("^2[Solo Logistics]^7 Modular Server Logic initialized.")
end)

-- =====================================================
-- [06] CLEANUP (PLAYER DISCONNECT)
-- =====================================================
-- This ensures that if a player crashes, the server removes them from the mission tracker
AddEventHandler('playerDropped', function(reason)
    local src = source
    if ActiveSoloMissions[src] then
        print(("^3[Solo Logistics] Asset link lost: %s (Reason: %s). Cleaning up mission state.^7"):format(GetPlayerName(src), reason))
        ActiveSoloMissions[src] = nil
    end
end)
