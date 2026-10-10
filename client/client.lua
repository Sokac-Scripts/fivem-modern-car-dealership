local display = false
local previewVehicle = nil
local previewCamera = nil

local currentZoom = Config.Preview.fov
local rotateDir = nil

local spawnCoords = Config.Preview.coords

local function cleanupPreview()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
        previewVehicle = nil
    end
    if DoesCamExist(previewCamera) then
        RenderScriptCams(false, true, 500, true, true)
        SetCamActive(previewCamera, false)
        DestroyCam(previewCamera, true)
        previewCamera = nil
    end
end

function SetDisplay(bool)
    display = bool
    SetNuiFocus(bool, bool)
    SendNUIMessage({
        type = "ui",
        status = bool,
        vehicles = Config.Vehicles,
        accent = Config.AccentColor
    })

    if Config.HudEvent then
        TriggerEvent(Config.HudEvent, not bool)
    end

    if not bool then
        cleanupPreview()
    end
end

RegisterCommand("salon", function()
    SetDisplay(not display)
end)

RegisterNUICallback("closeUI", function(data, cb)
    SetDisplay(false)
    cb('ok')
end)

RegisterNUICallback("previewVehicle", function(data, cb)
    local model = data.model
    local hash = GetHashKey(model)

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        cb('error')
        return
    end

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end

    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end

    previewVehicle = CreateVehicle(hash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, false, false)
    SetEntityHeading(previewVehicle, spawnCoords.w)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityInvincible(previewVehicle, true)
    SetVehicleDoorsLocked(previewVehicle, 2)
    SetVehicleDirtLevel(previewVehicle, 0.0)
    SetEntityCollision(previewVehicle, false, false)

    if not DoesCamExist(previewCamera) then
        previewCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamActive(previewCamera, true)
        RenderScriptCams(true, true, 1000, true, true)
        currentZoom = Config.Preview.fov
        SetCamFov(previewCamera, currentZoom)
    end

    local camPos = GetOffsetFromEntityInWorldCoords(previewVehicle, Config.Preview.camera.x, Config.Preview.camera.y, Config.Preview.camera.z)
    SetCamCoord(previewCamera, camPos.x, camPos.y, camPos.z)
    PointCamAtEntity(previewCamera, previewVehicle, 0.0, 0.0, 0.0, true)

    SetModelAsNoLongerNeeded(hash)

    cb('ok')
end)

RegisterNUICallback("changeColor", function(data, cb)
    if previewVehicle and DoesEntityExist(previewVehicle) then
        ClearVehicleCustomPrimaryColour(previewVehicle)
        ClearVehicleCustomSecondaryColour(previewVehicle)

        SetVehicleCustomPrimaryColour(previewVehicle, data.primary[1], data.primary[2], data.primary[3])
        SetVehicleCustomSecondaryColour(previewVehicle, data.secondary[1], data.secondary[2], data.secondary[3])
    end
    cb('ok')
end)

RegisterNUICallback("controlVehicle", function(data, cb)
    if data.action == "rotate" then
        rotateDir = data.dir
    elseif data.action == "drag" then
        if previewVehicle and DoesEntityExist(previewVehicle) then
            SetEntityHeading(previewVehicle, GetEntityHeading(previewVehicle) - (data.dx or 0) * 0.4)
        end
    elseif data.action == "zoom" then
        if data.dir == "in" then
            currentZoom = math.max(20.0, currentZoom - 5.0)
        elseif data.dir == "out" then
            currentZoom = math.min(90.0, currentZoom + 5.0)
        end
        if DoesCamExist(previewCamera) then
            SetCamFov(previewCamera, currentZoom)
        end
    end
    cb('ok')
end)

local pendingBuy = nil

RegisterNUICallback("buyVehicle", function(data, cb)
    cb('ok')
    if pendingBuy then return end

    local model = data and data.vehicle and data.vehicle.model
    local hash = model and GetHashKey(model)

    if not hash or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        Bridge.Notify("Ovo vozilo trenutno nije dostupno (model '" .. tostring(model) .. "' ne postoji na serveru).")
        return
    end

    pendingBuy = { model = model, colors = data.colors }
    TriggerServerEvent('autosalon:server:buy', {
        model = model,
        payment = data.payment,
        colors = data.colors
    })
end)

RegisterNetEvent('autosalon:client:buyResult', function(success, msg, plate)
    local buy = pendingBuy
    pendingBuy = nil
    if not buy then return end

    if not success then
        Bridge.Notify(msg or "Kupnja nije uspjela.")
        return
    end

    SetDisplay(false)
    Bridge.Notify(msg or "Vozilo je uspjesno kupljeno!")

    DoScreenFadeOut(500)
    Wait(500)

    local faded = false
    local function fadeBack()
        if faded then return end
        faded = true
        DoScreenFadeIn(500)
    end
    SetTimeout(6000, fadeBack)

    local sc = Config.BuySpawn
    Bridge.SpawnVehicle(buy.model, vector3(sc.x, sc.y, sc.z), sc.w, function(vehicle)
        SetVehicleNumberPlateText(vehicle, plate)

        local c = buy.colors or {}
        local p, s = c.primary or { 255, 255, 255 }, c.secondary or c.primary or { 255, 255, 255 }
        ClearVehicleCustomPrimaryColour(vehicle)
        ClearVehicleCustomSecondaryColour(vehicle)
        SetVehicleCustomPrimaryColour(vehicle, p[1], p[2], p[3])
        SetVehicleCustomSecondaryColour(vehicle, s[1], s[2], s[3])

        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        Bridge.GiveKeys(vehicle, plate)

        Wait(500)
        fadeBack()
    end)
end)

local testDriving = false

RegisterNUICallback("testDrive", function(data, cb)
    cb('ok')

    if testDriving then
        Bridge.Notify("Testna voznja je vec u tijeku.")
        return
    end

    local model = data and data.model
    local hash = model and GetHashKey(model)
    if not hash or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        Bridge.Notify("Ovo vozilo trenutno nije dostupno za testnu voznju.")
        return
    end

    testDriving = true
    SetDisplay(false)
    DoScreenFadeOut(500)
    Wait(500)

    local testCoords = Config.TestDrive.coords
    local playerPed = PlayerPedId()
    local startCoords = GetEntityCoords(playerPed)
    local startHeading = GetEntityHeading(playerPed)

    local function returnPlayer(vehicle)
        DoScreenFadeOut(500)
        Wait(500)

        if vehicle and DoesEntityExist(vehicle) then
            TaskLeaveVehicle(playerPed, vehicle, 16)
            Wait(200)
            Bridge.DeleteVehicle(vehicle)
        end

        local r = Config.Ped and Config.Ped.coords
        if r then
            SetEntityCoords(playerPed, r.x + 1.5, r.y, r.z, false, false, false, true)
            SetEntityHeading(playerPed, r.w)
        else
            SetEntityCoords(playerPed, startCoords.x, startCoords.y, startCoords.z, false, false, false, true)
            SetEntityHeading(playerPed, startHeading)
        end

        Wait(500)
        DoScreenFadeIn(500)
        testDriving = false
    end

    SetEntityCoords(playerPed, testCoords.x, testCoords.y, testCoords.z, false, false, false, true)
    Wait(1000)

    local spawned = false
    local spawnedVehicle = nil

    Bridge.SpawnVehicle(model, vector3(testCoords.x, testCoords.y, testCoords.z), testCoords.w, function(vehicle)
        spawned = true
        spawnedVehicle = vehicle
        TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
        SetVehicleNumberPlateText(vehicle, "TEST")
        SetVehicleDirtLevel(vehicle, 0.0)
        Bridge.GiveKeys(vehicle, "TEST")

        Wait(500)
        DoScreenFadeIn(500)
        Bridge.Notify("Testna voznja je pocela. Imate " .. Config.TestDrive.time .. " sekundi!")
    end)

    local waited = 0
    while not spawned and waited < 8000 do
        Wait(100)
        waited = waited + 100
    end

    if not spawned then
        Bridge.Notify("Testna voznja nije uspjela (vozilo se nije stvorilo).")
        returnPlayer(nil)
        return
    end

    local timeLeft = Config.TestDrive.time
    Wait(1500)
    while timeLeft > 0 do
        Wait(1000)
        timeLeft = timeLeft - 1

        if not DoesEntityExist(spawnedVehicle) or GetVehiclePedIsIn(playerPed, false) ~= spawnedVehicle then
            Bridge.Notify("Napustili ste vozilo. Testna voznja je zavrsena.")
            break
        end

        if timeLeft == 10 then
            Bridge.Notify("Ostalo vam je jos 10 sekundi!")
        end
    end

    if timeLeft <= 0 then
        Bridge.Notify("Testna voznja je istekla.")
    end

    returnPlayer(spawnedVehicle)
end)

CreateThread(function()
    while true do
        Wait(0)
        if display and previewVehicle and DoesEntityExist(previewVehicle) then
            if rotateDir == "left" then
                local heading = GetEntityHeading(previewVehicle)
                SetEntityHeading(previewVehicle, heading + 1.5)
            elseif rotateDir == "right" then
                local heading = GetEntityHeading(previewVehicle)
                SetEntityHeading(previewVehicle, heading - 1.5)
            end
        else
            Wait(250)
        end
    end
end)

local npcPed = nil

CreateThread(function()
    if not Config.Ped then return end

    local model = GetHashKey(Config.Ped.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    npcPed = CreatePed(4, model, Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z - 1.0, Config.Ped.coords.w, false, true)
    FreezeEntityPosition(npcPed, true)
    SetEntityInvincible(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)

    Bridge.AddInteraction(npcPed, 'Otvori Autosalon', function()
        SetDisplay(true)
    end)
end)

local displayVehicles = {}
local rotatingVehicles = {}

local staticDisplayVehicles = Config.DisplayVehicles or {}

CreateThread(function()
    for _, data in ipairs(staticDisplayVehicles) do
        local displayModel = GetHashKey(data.model)

        if IsModelInCdimage(displayModel) then
            RequestModel(displayModel)
            while not HasModelLoaded(displayModel) do
                Wait(10)
            end

            local veh = CreateVehicle(displayModel, data.coords.x, data.coords.y, data.coords.z - 0.5, data.coords.w, false, false)
            SetEntityHeading(veh, data.coords.w)
            SetVehicleOnGroundProperly(veh)
            FreezeEntityPosition(veh, true)
            SetEntityInvincible(veh, true)
            SetVehicleDoorsLocked(veh, 2)
            SetVehicleDirtLevel(veh, 0.0)

            SetModelAsNoLongerNeeded(displayModel)
            table.insert(displayVehicles, veh)

            if data.rotate then
                table.insert(rotatingVehicles, veh)
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if #rotatingVehicles > 0 then
            for _, veh in ipairs(rotatingVehicles) do
                if DoesEntityExist(veh) then
                    local heading = GetEntityHeading(veh)
                    SetEntityHeading(veh, heading + 0.3)
                end
            end
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for _, veh in ipairs(displayVehicles) do
        if DoesEntityExist(veh) then
            DeleteEntity(veh)
        end
    end

    if npcPed and DoesEntityExist(npcPed) then
        DeleteEntity(npcPed)
    end

    cleanupPreview()
end)
