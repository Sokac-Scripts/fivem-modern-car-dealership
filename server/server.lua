local MAX_DISTANCE = 60.0
local busy = {}

local function GeneratePlate()
    local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local numbers = "0123456789"

    for _ = 1, 20 do
        local plate = ""
        for i = 1, 3 do
            local rand = math.random(1, #letters)
            plate = plate .. string.sub(letters, rand, rand)
        end
        plate = plate .. " "
        for i = 1, 4 do
            local rand = math.random(1, #numbers)
            plate = plate .. string.sub(numbers, rand, rand)
        end

        if not Bridge.PlateExists(plate) then return plate end
    end
    return nil
end

local function FindVehicle(model)
    for _, v in ipairs(Config.Vehicles) do
        if v.model == model then return v end
    end
    return nil
end

local function ValidColor(c)
    if type(c) ~= "table" then return { 255, 255, 255 } end
    local out = {}
    for i = 1, 3 do
        local n = tonumber(c[i]) or 255
        out[i] = math.max(0, math.min(255, math.floor(n)))
    end
    return out
end

local function Reply(src, success, msg, plate)
    TriggerClientEvent('autosalon:client:buyResult', src, success, msg, plate)
end

RegisterNetEvent('autosalon:server:buy', function(data)
    local src = source

    if busy[src] then return Reply(src, false, "Kupnja je u tijeku, pricekajte.") end

    local player = Bridge.GetPlayer(src)
    if not player then return Reply(src, false, "Greska: igrac nije ucitan.") end

    if type(data) ~= "table" or type(data.model) ~= "string" then
        return Reply(src, false, "Neispravan zahtjev.")
    end

    local vehicleData = FindVehicle(data.model)
    if not vehicleData then return Reply(src, false, "Vozilo ne postoji u ponudi.") end

    if Bridge.GetDistanceToShop(src) > MAX_DISTANCE then
        return Reply(src, false, "Predaleko ste od autosalona.")
    end

    local method = data.payment == 'bank' and 'bank' or 'cash'
    local price = vehicleData.price
    local colors = {
        primary = ValidColor(data.colors and data.colors.primary),
        secondary = ValidColor(data.colors and data.colors.secondary)
    }

    busy[src] = true

    if Bridge.GetMoney(player, src, method) < price then
        busy[src] = nil
        return Reply(src, false, "Nemate dovoljno novca (" .. method .. ")!")
    end

    local plate = GeneratePlate()
    if not plate then
        busy[src] = nil
        return Reply(src, false, "Nije moguce generirati registarsku oznaku, pokusajte ponovo.")
    end

    if not Bridge.RemoveMoney(player, src, method, price, 'autosalon-vehicle') then
        busy[src] = nil
        return Reply(src, false, "Placanje nije uspjelo.")
    end

    local saved = Bridge.SaveVehicle(player, src, vehicleData.model, plate, colors)
    busy[src] = nil

    if saved then
        Reply(src, true, "Vozilo uspjesno kupljeno za $" .. price .. "!", plate)
    else

        Bridge.AddMoney(player, src, method, price, 'autosalon-refund')
        Reply(src, false, "Greska pri spremanju vozila, novac je vracen.")
    end
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
end)
