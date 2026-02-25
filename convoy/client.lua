-- =================================================================================
-- convoy/client.lua -- FIXED FULL VERSION
-- =================================================================================

local ESX = exports['es_extended']:getSharedObject()

-- [01] GLOBAL VARIABLES
local jobActive = false
local truckEntity = nil
local trailerEntity = nil
local deliveryBlip = nil
local currentDestination = nil
local currentConvoyID = nil
local playerLevel = 1

print("[CONVOY DEBUG] Client script started successfully.")

-- ==========================================
-- UTILITIES
-- ==========================================

local function ShowHelpText(msg)
    AddTextEntry('ConvoyHelp', msg)
    BeginTextCommandDisplayHelp('ConvoyHelp')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function WaitForNetEntity(netId)
    local timeout = 0
    while not NetworkDoesNetworkIdExist(netId) do
        Wait(50)
        timeout = timeout + 50
        if timeout > 5000 then
            return nil
        end
    end

    local entity = NetToVeh(netId)

    timeout = 0
    while not DoesEntityExist(entity) do
        Wait(50)
        timeout = timeout + 50
        if timeout > 5000 then
            return nil
        end
    end

    return entity
end

-- ==========================================
-- NUI CALLBACKS
-- ==========================================

RegisterNUICallback('createConvoy', function(data, cb)
    print("[CONVOY DEBUG] NUI: createConvoy")
    TriggerServerEvent('truckjob:server:createConvoy')
    cb('ok')
end)

RegisterNUICallback('joinConvoy', function(data, cb)
    print("[CONVOY DEBUG] NUI: joinConvoy " .. data.convoyID)
    TriggerServerEvent('truckjob:server:joinConvoy', data.convoyID)
    cb('ok')
end)

RegisterNUICallback('selectJob', function(data, cb)
    print("[CONVOY DEBUG] NUI: selectJob")
    TriggerServerEvent('truckjob:server:selectJob', data)
    cb('ok')
end)

RegisterNUICallback('startConvoyJob', function(data, cb)

    print("[CONVOY DEBUG] start convoy pressed")

    SetNuiFocus(false, false)

    if currentConvoyID then
        TriggerServerEvent('truckjob:server:requestConvoyStart')
    else
        print("[CONVOY DEBUG] Player not in convoy")
    end

    cb('ok')

end)

RegisterNUICallback('leaveConvoy', function(_, cb)
    print("[CONVOY DEBUG] NUI: leaveConvoy")
    TriggerServerEvent('truckjob:server:leaveConvoy')
    currentConvoyID = nil
    cb('ok')
end)

-- ==========================================
-- SERVER → CLIENT EVENTS
-- ==========================================

RegisterNetEvent('truckjob:client:updateConvoyPlayers', function(members, convoyID)

    print("[CONVOY DEBUG] Joined convoy", convoyID)

    currentConvoyID = convoyID

    SendNUIMessage({
        action = "updateConvoyPlayers",
        convoyID = convoyID,
        members = members
    })

end)

RegisterNetEvent('truckjob:client:syncConvoyJob', function(jobData)

    print("[CONVOY DEBUG] Job synced")

    SendNUIMessage({
        action = "syncConvoyJob",
        jobData = jobData
    })

end)

RegisterNetEvent('truckjob:client:joinFailed', function()

    print("[CONVOY DEBUG] Join failed")

    currentConvoyID = nil

    SendNUIMessage({
        action = "resetConvoy"
    })

    lib.notify({
        title = 'LINK LOST',
        description = 'Convoy not found',
        type = 'error'
    })

end)

-- ==========================================
-- BEGIN MISSION
-- ==========================================

RegisterNetEvent('truckjob:convoy:client:beginMission', function(truckNetId, trailerNetId, jobType, destinationIndex)

    if jobActive then
        print("[CONVOY DEBUG] Job already active")
        return
    end

    print("[CONVOY DEBUG] Mission received")

    truckEntity = WaitForNetEntity(truckNetId)
    trailerEntity = WaitForNetEntity(trailerNetId)

    if not truckEntity or not trailerEntity then
        print("[CONVOY ERROR] Vehicles failed to network")
        return
    end

    SetEntityAsMissionEntity(truckEntity, true, true)
    SetEntityAsMissionEntity(trailerEntity, true, true)

    local destinations = ConvoyLocations.DeliveryPoints[jobType]

    if not destinations then
        print("[CONVOY ERROR] No destinations for type", jobType)
        return
    end

    local dest = destinations[destinationIndex]

    if not dest then
        print("[CONVOY ERROR] Destination invalid")
        return
    end

    currentDestination = dest

    deliveryBlip = AddBlipForCoord(dest.coords)

    SetBlipSprite(deliveryBlip, 478)
    SetBlipColour(deliveryBlip, 38)
    SetBlipRoute(deliveryBlip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Squad Objective: " .. dest.label)
    EndTextCommandSetBlipName(deliveryBlip)

    jobActive = true

    lib.notify({
        title='SQUAD DEPLOYMENT',
        description='Route synced. Trucks ready.',
        type='success'
    })

end)

-- ==========================================
-- DELIVERY LOOP
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

                DrawMarker(
                    1,
                    destCoords.x, destCoords.y, destCoords.z - 1.0,
                    0,0,0,
                    0,0,0,
                    5.0,5.0,1.0,
                    0,210,255,80,
                    false,false,2,false
                )

                if distance < 12.0 then

                    if IsVehicleAttachedToTrailer(truckEntity) then

                        ShowHelpText("Detach trailer")

                    else

                        local trailerPos = GetEntityCoords(trailerEntity)

                        if #(trailerPos - destCoords) < 15.0 then

                            ShowHelpText("Trailer delivered")

                            if DoesBlipExist(deliveryBlip) then
                                RemoveBlip(deliveryBlip)
                            end

                            local depot = ConvoyConfig.TruckSpawn

                            deliveryBlip = AddBlipForCoord(depot.x, depot.y, depot.z)

                            SetBlipSprite(deliveryBlip, 477)
                            SetBlipColour(deliveryBlip, 2)
                            SetBlipRoute(deliveryBlip, true)

                            DeleteVehicle(trailerEntity)
                            trailerEntity = nil
                            currentDestination = nil

                        end

                    end

                end

            end

        elseif jobActive and not currentDestination and truckEntity then

            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            local depot = vector3(
                ConvoyConfig.TruckSpawn.x,
                ConvoyConfig.TruckSpawn.y,
                ConvoyConfig.TruckSpawn.z
            )

            local dist = #(playerCoords - depot)

            if dist < 50.0 then

                sleep = 0

                DrawMarker(
                    2,
                    depot.x, depot.y, depot.z + 1.5,
                    0,0,0,
                    180.0,0,0,
                    2.0,2.0,2.0,
                    0,210,255,150,
                    true,true,2,false
                )

                if dist < 8.0 then

                    ShowHelpText("Press E to finish convoy")

                    if IsControlJustReleased(0,38) then

                        if IsPedInVehicle(playerPed, truckEntity, false) then

                            TriggerServerEvent('truckjob:solo:pay', 2500)

                            if DoesBlipExist(deliveryBlip) then
                                RemoveBlip(deliveryBlip)
                            end

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
-- CLEANUP
-- ==========================================

AddEventHandler('onResourceStop', function(resource)

    if resource ~= GetCurrentResourceName() then
        return
    end

    if truckEntity then
        DeleteVehicle(truckEntity)
    end

    if trailerEntity then
        DeleteVehicle(trailerEntity)
    end

    if DoesBlipExist(deliveryBlip) then
        RemoveBlip(deliveryBlip)
    end

end)
