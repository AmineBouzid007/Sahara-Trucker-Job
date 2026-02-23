local ESX = exports['es_extended']:getSharedObject()

-- ==========================================
-- [01] GLOBAL VARIABLES (SQUAD SCOPE)
-- ==========================================
local jobActive = false
local truckEntity = nil
local trailerEntity = nil
local deliveryBlip = nil
local currentDestination = nil
local currentConvoyID = nil
local playerLevel = 1 

-- ==========================================
-- [02] CORE UTILITIES
-- ==========================================

-- Preserved Detail: Optimized Model Uplink
local function LoadModel(model)
    if not model then return false end
    local modelHash = type(model) == "string" and joaat(model) or model
    
    if not IsModelInCdimage(modelHash) then 
        print("^4[Convoy System] Critical Error: Asset " .. model .. " not found in database!^7")
        return false 
    end

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then 
            print("^4[Convoy System] Error: Asset downlink timed out.^7")
            return false 
        end
    end
    return true
end

-- Tactical HUD Text
local function ShowHelpText(msg)
    AddTextEntry('ConvoyHelp', msg)
    BeginTextCommandDisplayHelp('ConvoyHelp')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- ==========================================
-- [03] NETWORK TERMINAL INITIALIZATION
-- ==========================================
CreateThread(function()
    -- Uses ConvoyConfig from convoy/config.lua
    if not ConvoyConfig or not ConvoyConfig.NPC then return end
    if not LoadModel(ConvoyConfig.NPC.model) then return end
    
    local coords = ConvoyConfig.NPC.coords
    local ped = CreatePed(4, ConvoyConfig.NPC.model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    
    -- Tactical Animation
    if ConvoyConfig.NPC.animation then
        lib.requestAnimDict(ConvoyConfig.NPC.animation[1])
        TaskPlayAnim(ped, ConvoyConfig.NPC.animation[1], ConvoyConfig.NPC.animation[2], 8.0, 0, -1, 49, 0, 0, 0, 0)
    end

    -- Network Node Blip
    local npcBlip = AddBlipForEntity(ped)
    SetBlipSprite(npcBlip, 477)
    SetBlipColour(npcBlip, 38) -- Dark Blue
    SetBlipScale(npcBlip, 0.85)
    SetBlipAsShortRange(npcBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Squad Network Terminal")
    EndTextCommandSetBlipName(npcBlip)

    -- ox_target Integration (Cyber Link)
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'convoy_terminal',
            icon = 'fa-solid fa-satellite-dish',
            label = 'Access Squad Network',
            distance = 2.5,
            onSelect = function()
                if jobActive then
                    lib.notify({ title='SIGNAL ERROR', description='deployment in progress. Complete current route.', type='error' })
                    return
                end
                
                -- Callback targeting the convoy/server.lua
                ESX.TriggerServerCallback('truckjob:convoy:getData', function(data)
                    if data then
                        playerLevel = data.player.level 
                        SetNuiFocus(true, true)
                        SendNUIMessage({
                            action = "openUI",
                            serverID = GetPlayerServerId(PlayerId()),
                            player = data.player,
                            jobs = {}, -- Normal jobs empty here, we focus on random convoy jobs
                            randomJobs = data.randomJobs 
                        })
                    end
                end)
            end
        }
    })
end)

-- ==========================================
-- [04] NUI CALLBACKS (SQUAD SYNC)
-- ==========================================

RegisterNUICallback('createConvoy', function(data, cb)
    TriggerServerEvent('truckjob:server:createConvoy', data.convoyID)
    cb('ok')
end)

RegisterNUICallback('joinConvoy', function(data, cb)
    TriggerServerEvent('truckjob:server:joinConvoy', data.convoyID)
    cb('ok')
end)

RegisterNUICallback('selectJob', function(data, cb)
    TriggerServerEvent('truckjob:server:selectJob', data)
    cb('ok')
end)

RegisterNUICallback('startJob', function(data, cb)
    SetNuiFocus(false, false)
    if currentConvoyID then
        -- Signal the server to start the job for the whole squad
        TriggerServerEvent('truckjob:server:requestConvoyStart', data.jobType, currentConvoyID)
    end
    cb('ok')
end)

RegisterNUICallback('leaveConvoy', function(_, cb)
    TriggerServerEvent('truckjob:server:leaveConvoy')
    currentConvoyID = nil
    cb('ok')
end)

-- ==========================================
-- [05] CONVOY SYNC EVENTS (SERVER TO CLIENT)
-- ==========================================

RegisterNetEvent('truckjob:client:updateConvoyPlayers', function(members, convoyID)
    currentConvoyID = convoyID
    SendNUIMessage({
        action = "updateConvoyPlayers",
        convoyID = convoyID,
        members = members
    })
end)

RegisterNetEvent('truckjob:client:syncConvoyJob', function(jobData)
    SendNUIMessage({
        action = "syncConvoyJob",
        jobData = jobData
    })
end)

RegisterNetEvent('truckjob:client:joinFailed', function()
    currentConvoyID = nil
    SendNUIMessage({ action = "resetConvoy" })
    lib.notify({ title = 'LINK_LOST', description = 'Signal ID not found in sector.', type = 'error' })
end)

RegisterNetEvent('truckjob:client:startSyncedJob', function(jobType, destinationIndex)
    StartConvoyJob(jobType, destinationIndex)
end)

-- ==========================================
-- [06] SQUAD DEPLOYMENT LOGIC
-- ==========================================

function StartConvoyJob(jobType, forcedDestIndex)
    if jobActive then return end

    -- Load from ConvoyLocations (convoy/location.lua)
    local truckModel = ConvoyLocations.TruckModels[jobType] or `phantom`
    local trailerModel = ConvoyLocations.TrailerModels[jobType] or `tanker`
    local destinations = ConvoyLocations.DeliveryPoints[jobType]

    if not destinations or not destinations[forcedDestIndex] then return end

    -- 1. Setup Synced Destination
    currentDestination = destinations[forcedDestIndex]

    -- 2. Spawning Squad Assets (Truck)
    if not LoadModel(truckModel) then return end
    
    local spawn = ConvoyConfig.TruckSpawn
    -- Offset based on server ID to prevent explosions during squad spawn
    local offset = (GetPlayerServerId(PlayerId()) % 5) * 6.0
    
    truckEntity = CreateVehicle(truckModel, spawn.x + offset, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleNumberPlateText(truckEntity, "SQD-" .. GetPlayerServerId(PlayerId()))
    SetEntityAsMissionEntity(truckEntity, true, true)
    
    -- 3. Spawning Squad Payload (Trailer)
    if not LoadModel(trailerModel) then return end
    
    -- Randomly pick a slot from the convoy trailer depot
    local trailerSpawn = ConvoyConfig.TrailerSpawnPoints[math.random(#ConvoyConfig.TrailerSpawnPoints)]
    trailerEntity = CreateVehicle(trailerModel, trailerSpawn.x, trailerSpawn.y, trailerSpawn.z, trailerSpawn.w, true, false)
    SetEntityAsMissionEntity(trailerEntity, true, true)

    -- 4. Shared Target Blip
    deliveryBlip = AddBlipForCoord(currentDestination.coords)
    SetBlipSprite(deliveryBlip, 478)
    SetBlipColour(deliveryBlip, 38) -- Tactical Blue
    SetBlipRoute(deliveryBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Squad Objective: " .. currentDestination.label)
    EndTextCommandSetBlipName(deliveryBlip)

    jobActive = true
    lib.notify({ title='SQUAD LINKED', description='Route synced. Secure payload and move to objective.', type='success' })
end

-- ==========================================
-- [07] SQUAD DELIVERY LOOP
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
                    DrawMarker(1, destCoords.x, destCoords.y, destCoords.z - 1.0, 0,0,0, 0,0,0, 5.0, 5.0, 1.0, 0, 210, 255, 80, false, false, 2, false, nil, nil, false)
                    
                    if distance < 12.0 then
                        if IsVehicleAttachedToTrailer(truckEntity) then
                            ShowHelpText("HOLD ~INPUT_VEH_HEADLIGHT~ TO DISCONNECT SQUAD PAYLOAD")
                        else
                            local trailerPos = GetEntityCoords(trailerEntity)
                            if #(trailerPos - destCoords) < 15.0 then
                                ShowHelpText("PAYLOAD SECURED. RETURN ASSET TO DEPOT.")
                                if DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
                                
                                local depot = ConvoyConfig.TruckSpawn
                                deliveryBlip = AddBlipForCoord(depot.x, depot.y, depot.z)
                                SetBlipSprite(deliveryBlip, 477)
                                SetBlipColour(deliveryBlip, 2)
                                SetBlipRoute(deliveryBlip, true)
                                
                                SetEntityAsMissionEntity(trailerEntity, false, false)
                                Wait(2000)
                                DeleteVehicle(trailerEntity)
                                trailerEntity = nil
                                currentDestination = nil 
                            else
                                ShowHelpText("~r~TARGET VECTOR MISMATCH. MOVE PAYLOAD INTO ZONE.")
                            end
                        end
                    end
                end
            end
        elseif jobActive and not currentDestination and truckEntity then
            -- ASSET RETURN SEQUENCE
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local depotCoords = vector3(ConvoyConfig.TruckSpawn.x, ConvoyConfig.TruckSpawn.y, ConvoyConfig.TruckSpawn.z)
            local distToDepot = #(playerCoords - depotCoords)

            if distToDepot < 50.0 then
                sleep = 0
                DrawMarker(2, depotCoords.x, depotCoords.y, depotCoords.z + 1.5, 0,0,0, 180.0,0,0, 2.0, 2.0, 2.0, 0, 210, 255, 150, true, true, 2, false, nil, nil, false)
                
                if distToDepot < 8.0 then
                    ShowHelpText("PRESS ~INPUT_CONTEXT~ TO FINALIZE SQUAD CONTRACT")
                    if IsControlJustReleased(0, 38) then
                        if IsPedInVehicle(playerPed, truckEntity, false) then
                            -- Trigger Convoy Payment (Shared via server)
                            TriggerServerEvent('truckjob:pay', 2500) 
                            if DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
                            DeleteVehicle(truckEntity)
                            truckEntity = nil
                            jobActive = false
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ==========================================
-- [08] CLEANUP
-- ==========================================
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if truckEntity then DeleteVehicle(truckEntity) end
        if trailerEntity then DeleteVehicle(trailerEntity) end
        if DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
    end
end)
