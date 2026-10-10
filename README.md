# 🚗 Modern Car Dealership for FiveM

A clean, modern vehicle dealership with a fully custom NUI. Players browse cars by brand, preview them in 3D, pick a color, test drive and buy - all from one screen.

**Works on ESX, QBCore, Qbox and standalone.** The framework is detected automatically.

## ✨ Features

- 🏷️ Brand carousel with logos; vehicles are grouped by brand
- 🎥 Live 3D preview with scripted camera, mouse drag rotation and scroll zoom
- 📊 Vehicle details: engine, brakes, speed and acceleration bars, price, description
- 🎨 Color mode with a palette, applied live to the preview car and saved on purchase
- 🏁 Test drive with a timer, safe fallbacks and automatic return to the dealership
- 💳 Purchase flow: Cash or Bank, plus a confirmation step
- 🔊 Smooth animations and synthesized sound effects (no audio files)
- 📱 Fully responsive UI (16:9, 4:3, ultrawide)
- 🖌️ Easy theming: set the accent color in the config with HEX or RGB

## 🔒 Security

- Price and model are always read from the server config, never trusted from the client
- Distance check, anti double-buy, unique plates
- Automatic refund if saving the vehicle fails

## 🧩 Framework support

| | ESX | QBCore | Qbox | Standalone |
|---|---|---|---|---|
| Money (cash/bank) | ✅ | ✅ | ✅ | via config hooks |
| Vehicle saved to DB | `owned_vehicles` | `player_vehicles` | `player_vehicles` | via config hooks |
| Notifications | ✅ | ✅ | ✅ | native |
| Vehicle keys | custom hook | `qb-vehiclekeys` | `qbx_vehiclekeys` | custom hook |

- Interaction with the dealer: `ox_target`, `qb-target` or the **E** key (auto-detected)
- On start the script checks the database table for your framework and creates it or adds missing columns

## 📦 Installation

1. Download or clone this repository into your `resources` folder.
2. Make sure your framework and `oxmysql` are started (oxmysql is not needed for standalone).
3. Add to your `server.cfg`:
   ```
   ensure autosalon
   ```
4. Add your vehicles in `config/config.lua` and put one image per vehicle in `html/img/`.

## ⚙️ Configuration

Everything is in [`config/config.lua`](config/config.lua):

| Option | Description |
|---|---|
| `Config.Framework` | `auto`, `esx`, `qb`, `qbox` or `standalone` |
| `Config.Target` | `auto`, `ox_target`, `qb-target` or `key` |
| `Config.AccentColor` | UI color, HEX (`"#8db510"`, `"#0af"`) or RGB (`{141,181,16}`) |
| `Config.Ped` | Dealer NPC model and position |
| `Config.BuySpawn` | Where the vehicle appears after purchase |
| `Config.TestDrive` | Test drive location and duration (seconds) |
| `Config.DisplayVehicles` | Decorative vehicles inside the showroom |
| `Config.HudEvent` | Optional event to hide your HUD while the dealership is open |
| `Config.QB.garage` | Garage the vehicle is saved to (QBCore / Qbox) |
| `Config.Standalone` | `charge`, `refund` and `save` hooks for standalone use |
| `Config.OnVehicleBought` | Optional client hook (keys, fuel, etc.) |
| `Config.Vehicles` | The vehicle list |

### Adding a vehicle

```lua
{
    model = "sultan",        -- spawn name (must exist on your server)
    name = "Sultan",
    brand = "Audi",          -- vehicles with the same brand are grouped together
    price = 850000,
    img = "sultan.png",      -- image from html/img/
    engine = 95, brakes = 60, speed = 90, accel = 85,   -- 0-100, shown as bars
    speedVal = 350,          -- top speed in KMH
    desc = "Optional description."
},
```

Brands with a built-in logo: Lamborghini, BMW, Audi, Mercedes, Porsche, Volkswagen. Other brands show a circle with the first letter.

## 🎮 Controls

| Key | Action |
|---|---|
| ⬅️ ➡️ | Change brand |
| ⬆️ ⬇️ | Change vehicle |
| Enter / X | Select (open details) |
| Ctrl | Color mode |
| Tab | Test drive |
| Delete / Backspace / Esc | Back |
| A / D or mouse drag | Rotate the vehicle |
| Mouse wheel | Zoom |

You can also open the dealership with the `/salon` command.

## 🧰 Standalone example

```lua
Config.Standalone = {
    charge = function(source, price, method)
        -- take the money with your own system, return true if paid
        return true
    end,
    refund = function(source, price, method) end,
    save = function(source, data)
        -- data = { model, plate, colors = { primary, secondary } }
        return true
    end
}
```

## ⚠️ Notes

- Vehicle models and images in the default config are examples - replace them with your own.
- On QBCore/Qbox the chosen color is stored in `mods` as `customPrimaryColor` / `customSecondaryColor`. The vehicle is colored correctly at purchase, but your garage script may not restore it.

## 📄 License

Add your license here (e.g. MIT).
