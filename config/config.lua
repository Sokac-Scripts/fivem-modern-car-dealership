Config = {}

-- UI accent color: HEX ("#10b58c", "#0af") or RGB ({ 16, 181, 140 } / "16,181,140")
Config.AccentColor = "#10b58c"

-- 'auto', 'esx', 'qb', 'qbox' or 'standalone'
Config.Framework = 'auto'

-- 'auto', 'ox_target', 'qb-target' or 'key' (press E near the dealer)
Config.Target = 'auto'

-- Event used to hide your HUD while the dealership is open, e.g. 'myhud:toggleHud'
-- It is triggered with false when opening and true when closing
Config.HudEvent = nil

-- Where the vehicle spawns after a purchase
Config.BuySpawn = vector4(-221.8155, -1176.7878, 23.0145, 91.8175)

-- Test drive location and duration (seconds)
Config.TestDrive = {
    coords = vector4(-901.8328, -3192.9880, 13.9454, 52.9370),
    time = 30
}

-- Decorative vehicles inside the showroom (rotate = true makes them spin)
Config.DisplayVehicles = {
    { model = "mk8avante", coords = vector4(-176.5786, -1162.1935, 22.5590, 220.0542) },
    { model = "16m4gts", coords = vector4(-170.4828, -1162.2069, 22.4163, 220.4451) },
    { model = "dicyxxs90gte", coords = vector4(-185.0110, -1174.3469, 22.4703, 359.8300), rotate = true },
}

-- QBCore / Qbox: garage the purchased vehicle is saved to
Config.QB = {
    garage = 'pillboxgarage'
}

-- Standalone only (no framework): handle money and saving yourself
-- charge(source, price, method) -> return true if the player paid ('cash' or 'bank')
-- refund(source, price, method) -> called if saving fails after charging
-- save(source, data)            -> data = { model, plate, colors = { primary, secondary } }, return true on success
Config.Standalone = {
    charge = function(source, price, method)
        return true
    end,
    refund = function(source, price, method) end,
    save = function(source, data)
        return true
    end
}

-- Optional client hook after a purchase or test drive (vehicle keys, fuel...)
-- Config.OnVehicleBought = function(vehicle, plate) end
Config.OnVehicleBought = nil

-- Dealer NPC
Config.Ped = {
    model = "csb_car3guy1",
    coords = vector4(-196.8720, -1168.7892, 23.8812, 278.8438)
}

-- Vehicle list
-- model    spawn name (must exist on your server)
-- name     name shown in the UI
-- brand    vehicles with the same brand are grouped together
-- price    price in dollars
-- img      file from html/img/
-- engine, brakes, speed, accel   0-100, shown as bars
-- speedVal top speed in KMH
-- desc     optional description
Config.Vehicles = {
    {
        model = "sultan",
        name = "Sultan",
        brand = "Lamborghini",
        price = 850000,
        img = "sultan.png",
        engine = 95,
        brakes = 60,
        speed = 90,
        accel = 85,
        speedVal = 350
    },
    {
        model = "16m4gts",
        name = "M4 GTS",
        brand = "BMW",
        price = 850000,
        img = "16m4gts.png",
        engine = 95,
        brakes = 60,
        speed = 90,
        accel = 85,
        speedVal = 350
    },
    {
        model = "mk8avante",
        name = "Golf 8",
        brand = "Volkswagen",
        price = 850000,
        img = "mk8avante.png",
        engine = 95,
        brakes = 60,
        speed = 90,
        accel = 85,
        speedVal = 350
    },
}

