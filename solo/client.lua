local ESX = exports['es_extended']:getSharedObject()

-- ==========================================
-- [01] GLOBAL VARIABLES (SOLO SCOPE)
-- ==========================================
local jobActive = false
local truckEntity = nil
local trailerEntity = nil
local deliveryBlip = nil
local currentDestination = nil
local playerLevel = 1 

-- ==========================================
-- [02] CORE UTILITIES
-- ==========================================

-- Optimized Model Loader with Error Handling (Preserved Detail)
local function LoadModel(model)
    if not model then return false end
    local modelHash = type(model) == "string" and joaat(model) or model
    
    if not IsModelInCdimage(modelHash) then 
        print("^1[Solo Trucking] Error: Model " .. model .. " does not exist in CD Image!^7")
        return false 
    end

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then 
            print("^1[Solo Trucking] Error: Model uplink failed (Timeout).^7")
            return false 
        end
    end
    return true
end

-- Tactical HUD Interaction Text
local function ShowHelpText(msg)
    AddTextEntry('SoloJobHelp', msg)
    BeginTextCommandDisplayHelp('SoloJobHelp')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- ==========================================
-- [03] NPC & TARGET INITIALIZATION
-- ==========================================
-- In solo/client.lua -- REPLACE THE NPC CREATION THREAD WITH THIS

CreateThread(function()
    -- This is now the ONLY script that creates the NPC.
    if not SoloConfig or not SoloConfig.NPC then return end
    if not LoadModel(SoloConfig.NPC.model) then return end
    
    local coords = SoloConfig.NPC.coords
    local ped = CreatePed(4, SoloConfig.NPC.model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    
    if SoloConfig.NPC.animation then
        lib.requestAnimDict(SoloConfig.NPC.animation[1])
        TaskPlayAnim(ped, SoloConfig.NPC.animation[1], SoloConfig.NPC.animation[2], 8.0, 0, -1, 49, 0, 0, 0, 0)
    end

    local npcBlip = AddBlipForEntity(ped)
    SetBlipSprite(npcBlip, 477)
    SetBlipColour(npcBlip, 4) -- Yellow for multi-purpose
    SetBlipScale(npcBlip, 0.9)
    SetBlipAsShortRange(npcBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Logistics Terminal")
    EndTextCommandSetBlipName(npcBlip)
    
    -- A SINGLE target option that gets ALL data at once.
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'unified_logistics_terminal',
            icon = 'fa-solid fa-globe',
            label = 'Access Logistics Network',
            distance = 2.5,
            onSelect = function()
                if jobActive then
                    lib.notify({ title='TERMINAL', description='Active contract in progress.', type='error' })
                    return
                end
                
                -- Call the new unified server callback
                ESX.TriggerServerCallback('truckjob:getInitialData', function(data)
                    if data then
                        playerLevel = data.player.level 
                        SetNuiFocus(true, true)
                        SendNUIMessage({
                            action = "openUI",
                            serverID = GetPlayerServerId(PlayerId()),
                            player = data.player,
                            soloJobs = data.soloJobs,
                            convoyJobs = data.convoyJobs
                        })
                    else
                        lib.notify({ title='SYSTEM ERROR', description='Uplink to logistics database failed.', type='error' })
                    end
                end)
            end
        }
    })
end)



-- ==========================================
-- [04] NUI CALLBACKS (SOLO LOGIC)
-- ==========================================

RegisterNUICallback('closeUI', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- This handles job start for SOLO contracts
RegisterNUICallback('startSoloJob', function(data, cb)

    SetNuiFocus(false, false)

    if not data.jobType then
        cb('ok')
        return
    end

    StartSoloTruckJob(data.jobType)

    cb('ok')
end)

-- ==========================================
-- [05] JOB EXECUTION LOGIC (SOLO)
-- ==========================================

function StartSoloTruckJob(jobType)
    if jobActive then return end

    -- Load from SoloLocations (solo/location.lua)
    local truckModel = SoloLocations.TruckModels[jobType] or `linerunner`
    local trailerModel = SoloLocations.TrailerModels[jobType] or `tanker`
    local destinations = SoloLocations.DeliveryPoints[jobType]

    if not destinations then
        lib.notify({title="ERROR", description="Sector data for this cargo is missing.", type="error"})
        return
    end

    -- 1. Setup Random Solo Destination
    currentDestination = destinations[math.random(#destinations)]

    -- 2. Initializing Hardware (Truck)
    if not LoadModel(truckModel) then return end
    
    local spawn = SoloConfig.TruckSpawn
    truckEntity = CreateVehicle(truckModel, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleNumberPlateText(truckEntity, "SOLO-" .. GetPlayerServerId(PlayerId()))
    SetEntityAsMissionEntity(truckEntity, true, true)
    SetVehicleOnGroundProperly(truckEntity)
    
    -- 3. Spawning Payload (Trailer)
    if not LoadModel(trailerModel) then return end
    
    -- Use specific solo spawn for trailer if defined, otherwise offset from truck
    local trailerSpawn = SoloConfig.TrailerSpawn or vector4(spawn.x - 5.0, spawn.y, spawn.z, spawn.w)
    trailerEntity = CreateVehicle(trailerModel, trailerSpawn.x, trailerSpawn.y, trailerSpawn.z, trailerSpawn.w, true, false)
    SetEntityAsMissionEntity(trailerEntity, true, true)
    SetVehicleOnGroundProperly(trailerEntity)

    -- 4. Blip Uplink
    deliveryBlip = AddBlipForCoord(currentDestination.coords)
    SetBlipSprite(deliveryBlip, 478)
    SetBlipColour(deliveryBlip, 3) -- Blue for Solo
    SetBlipRoute(deliveryBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Solo Target: " .. currentDestination.label)
    EndTextCommandSetBlipName(deliveryBlip)

    jobActive = true
    lib.notify({ title='DEPLOYMENT', description='Contract accepted. Secure trailer and move to target.', type='success' })
end

-- ==========================================
-- [06] SOLO DELIVERY LOOP (PERFORMANCE)
-- ==========================================
CreateThread(function()
    while true do
        local sleep = 1500
        
        if jobActive and currentDestination then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local destCoords = currentDestination.coords
            local distance = #(playerCoords - destCoords)

            if distance < 100.0 then
                sleep = 0
                if DoesEntityExist(truckEntity) then
                    -- Cyber Blue Marker
                    DrawMarker(1, destCoords.x, destCoords.y, destCoords.z - 1.0, 0,0,0, 0,0,0, 4.0, 4.0, 1.0, 0, 210, 255, 100, false, false, 2, false, nil, nil, false)
                    
                    if distance < 10.0 then
                        if IsVehicleAttachedToTrailer(truckEntity) then
                            ShowHelpText("STAND BY... HOLD ~INPUT_VEH_HEADLIGHT~ TO DECOUPLE PAYLOAD")
                        else
                            local trailerPos = GetEntityCoords(trailerEntity)
                            if #(trailerPos - destCoords) < 15.0 then
                                -- PAYLOAD SECURED
                                ShowHelpText("PAYLOAD DELIVERED. RETURN ASSET TO BASE DEPOT.")
                                if DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
                                
                                -- Depot Return Blip
                                local depot = SoloConfig.TruckSpawn
                                deliveryBlip = AddBlipForCoord(depot.x, depot.y, depot.z)
                                SetBlipSprite(deliveryBlip, 477)
                                SetBlipColour(deliveryBlip, 2)
                                SetBlipRoute(deliveryBlip, true)
                                
                                -- Cleanup Trailer
                                SetEntityAsMissionEntity(trailerEntity, false, false)
                                Wait(2000)
                                DeleteVehicle(trailerEntity)
                                trailerEntity = nil
                                currentDestination = nil 
                            else
                                ShowHelpText("~r~POSITION PAYLOAD WITHIN THE TARGET VECTOR!")
                            end
                        end
                    end
                end
            end
        elseif jobActive and not currentDestination and truckEntity then
            -- ASSET RETURN SEQUENCE
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local depotCoords = vector3(SoloConfig.TruckSpawn.x, SoloConfig.TruckSpawn.y, SoloConfig.TruckSpawn.z)
            local distToDepot = #(playerCoords - depotCoords)

            if distToDepot < 50.0 then
                sleep = 0
                DrawMarker(2, depotCoords.x, depotCoords.y, depotCoords.z + 1.5, 0,0,0, 180.0,0,0, 2.0, 2.0, 2.0, 0, 210, 255, 150, true, true, 2, false, nil, nil, false)
                
                if distToDepot < 8.0 then
                    ShowHelpText("PRESS ~INPUT_CONTEXT~ TO FINALIZE SOLO CONTRACT")
                    if IsControlJustReleased(0, 38) then
                        if IsPedInVehicle(playerPed, truckEntity, false) then
                            -- Trigger Solo Payment
                            TriggerServerEvent('truckjob:solo:pay', 1200) 
                            
                            -- System Cleanup
                            if DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
                            DeleteVehicle(truckEntity)
                            truckEntity = nil
                            jobActive = false
                            lib.notify({title='CONTRACT COMPLETE', description='Credits transferred to your account.', type='success'})
                        else
                            lib.notify({description="Asset required for verification. Get back in the truck.", type="error"})
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ==========================================
-- [07] UPDATES & CLEANUP
-- ==========================================

RegisterNetEvent('truckjob:solo:updateStats', function(stats)
    if stats.level then playerLevel = stats.level end
    SendNUIMessage({ action = "updateStats", stats = stats })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if truckEntity then DeleteVehicle(truckEntity) end
        if trailerEntity then DeleteVehicle(trailerEntity) end
        if DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
    end
end)
