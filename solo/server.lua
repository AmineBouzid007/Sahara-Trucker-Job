local ESX = exports['es_extended']:getSharedObject()

-- =====================================================
-- [01] DATA STORAGE
-- =====================================================
local SoloDynamicJobs = {} 

-- =====================================================
-- [02] SOLO DYNAMIC JOB GENERATION
-- This generates your "PRIVATE" solo contracts
-- =====================================================
local function GenerateSoloJobs()
    SoloDynamicJobs = {}
    math.randomseed(os.time())
    if not SoloConfig or not SoloConfig.StaticJobs then return false end
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
    while not GenerateSoloJobs() do
        Wait(2500)
    end
end)

-- =====================================================
-- [03] UNIFIED DATA CALLBACK (THE REAL FIX)
-- This is the ONLY callback the UI uses to get data.
-- =====================================================
ESX.RegisterServerCallback('truckjob:getInitialData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end
    
    local convoyJobs = {} -- Default to an empty table for safety

    -- This safely asks the convoy script for its jobs without crashing
    local success, result = pcall(function()
        return exports['delivery_job2']:getConvoyJobs()
    end)

    if success and result then
        convoyJobs = result
    else
        print("^1[TRUCKER JOB WARNING]^7: Could not get convoy jobs from export. This is normal on first load. If it persists, check fxmanifest.")
    end
    
    -- This sends the complete package of ALL jobs to the UI
    cb({
        serverID = source,
        player = {
            name = xPlayer.getName(),
            level = 1, -- TODO: Replace with your actual player level logic
            xp = 25    -- TODO: Replace with your actual player XP logic
        },
        soloJobs = {
            static = SoloConfig.StaticJobs or {},
            random = SoloDynamicJobs or {}
        },
        convoyJobs = convoyJobs or {}
    })
end)

-- =====================================================
-- [04] SOLO ECONOMY & PAYMENTS
-- This handles payments for SOLO jobs only.
-- =====================================================
RegisterNetEvent('truckjob:solo:pay', function(amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local maxSoloPay = 3500
    if tonumber(amount) > maxSoloPay then 
        amount = maxSoloPay 
    end
    xPlayer.addMoney(tonumber(amount))
    TriggerClientEvent('ox_lib:notify', src, { title = 'TERMINAL_UPLINK', description = 'Credits transferred: $' .. amount, type = 'success' })
end)

-- =====================================================
-- [05] CLEANUP (PLAYER DISCONNECT)
-- Note: This part was missing from your last version. It's important for stability.
-- =====================================================
AddEventHandler('playerDropped', function(reason)
    local src = source
    -- If you have solo mission tracking, add it here.
    -- For now, this is a placeholder.
end)
