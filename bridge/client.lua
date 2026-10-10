Bridge = {}

local function started(name)
    return GetResourceState(name) == 'started'
end

local function detectFramework()
    local cfg = Config.Framework
    if cfg and cfg ~= 'auto' then return cfg end
    if started('qbx_core') then return 'qbox' end
    if started('qb-core') then return 'qb' end
    if started('es_extended') then return 'esx' end
    return 'standalone'
end

Bridge.framework = detectFramework()

local ESX, QBCore

if Bridge.framework == 'esx' then
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok then ESX = obj end
elseif Bridge.framework == 'qb' then
    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok then QBCore = obj end
end

print(('^2[autosalon]^7 Framework: ^3%s^7'):format(Bridge.framework))

function Bridge.Notify(msg)
    if Bridge.framework == 'esx' and ESX then
        ESX.ShowNotification(msg)
    elseif Bridge.framework == 'qb' and QBCore then
        QBCore.Functions.Notify(msg, 'primary')
    elseif Bridge.framework == 'qbox' then
        exports.qbx_core:Notify(msg, 'inform')
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

function Bridge.SpawnVehicle(model, coords, heading, cb)
    CreateThread(function()
        local hash = type(model) == 'number' and model or GetHashKey(model)
        if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return end

        RequestModel(hash)
        local t = GetGameTimer()
        while not HasModelLoaded(hash) do
            Wait(10)
            if GetGameTimer() - t > 8000 then return end
        end

        local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading or 0.0, true, false)
        local tries = 0
        while not DoesEntityExist(veh) and tries < 100 do
            Wait(10)
            tries = tries + 1
        end
        if not DoesEntityExist(veh) then
            SetModelAsNoLongerNeeded(hash)
            return
        end

        SetVehicleOnGroundProperly(veh)
        SetModelAsNoLongerNeeded(hash)
        if cb then cb(veh) end
    end)
end

function Bridge.DeleteVehicle(veh)
    if veh and DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end
end

function Bridge.GiveKeys(veh, plate)
    if Config.OnVehicleBought then
        pcall(Config.OnVehicleBought, veh, plate)
    end
    if started('qbx_vehiclekeys') then
        pcall(function() exports.qbx_vehiclekeys:GiveKeys(veh) end)
    elseif started('qb-vehiclekeys') then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end
end

function Bridge.AddInteraction(ped, label, onUse)
    local mode = Config.Target or 'auto'
    if mode == 'auto' then
        if started('ox_target') then mode = 'ox_target'
        elseif started('qb-target') then mode = 'qb-target'
        else mode = 'key' end
    end

    if mode == 'ox_target' then
        exports.ox_target:addLocalEntity(ped, {
            { name = 'open_autosalon', icon = 'fas fa-car', label = label, onSelect = onUse }
        })
    elseif mode == 'qb-target' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = { { type = 'client', icon = 'fas fa-car', label = label, action = onUse } },
            distance = 2.5
        })
    else

        CreateThread(function()
            while true do
                local sleep = 500
                if DoesEntityExist(ped) then
                    local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped))
                    if dist < 2.5 then
                        sleep = 0
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('Pritisni ~INPUT_CONTEXT~ - ' .. label)
                        EndTextCommandDisplayHelp(0, false, true, -1)
                        if IsControlJustPressed(0, 38) then onUse() end
                    end
                end
                Wait(sleep)
            end
        end)
    end
end
