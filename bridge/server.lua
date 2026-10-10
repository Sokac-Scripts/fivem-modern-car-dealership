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
    ESX = exports['es_extended']:getSharedObject()
elseif Bridge.framework == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local hasDb = started('oxmysql')

local function dbScalar(q, p)  return exports.oxmysql:scalar_async(q, p or {}) end
local function dbQuery(q, p)   return exports.oxmysql:query_async(q, p or {}) end
local function dbInsert(q, p)  return exports.oxmysql:insert_async(q, p or {}) end

local SCHEMAS = {
    esx = {
        table = 'owned_vehicles',
        create = [[
            CREATE TABLE IF NOT EXISTS `owned_vehicles` (
                `owner` VARCHAR(60) NOT NULL,
                `plate` VARCHAR(12) NOT NULL,
                `vehicle` LONGTEXT,
                `type` VARCHAR(20) NOT NULL DEFAULT 'vehicle',
                `garage` VARCHAR(60) NULL DEFAULT 'OUT',
                PRIMARY KEY (`plate`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]],
        columns = {
            owner = "VARCHAR(60) NOT NULL",
            plate = "VARCHAR(12) NOT NULL",
            vehicle = "LONGTEXT",
            type = "VARCHAR(20) NOT NULL DEFAULT 'vehicle'",
            garage = "VARCHAR(60) NULL DEFAULT 'OUT'",
        }
    },
    qb = {
        table = 'player_vehicles',
        create = [[
            CREATE TABLE IF NOT EXISTS `player_vehicles` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `license` VARCHAR(50) DEFAULT NULL,
                `citizenid` VARCHAR(50) DEFAULT NULL,
                `vehicle` VARCHAR(50) DEFAULT NULL,
                `hash` VARCHAR(50) DEFAULT NULL,
                `mods` LONGTEXT,
                `plate` VARCHAR(15) NOT NULL,
                `garage` VARCHAR(50) DEFAULT NULL,
                `state` INT(11) DEFAULT 1,
                PRIMARY KEY (`id`),
                KEY `plate` (`plate`),
                KEY `citizenid` (`citizenid`)
            ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4
        ]],
        columns = {
            license = "VARCHAR(50) DEFAULT NULL",
            citizenid = "VARCHAR(50) DEFAULT NULL",
            vehicle = "VARCHAR(50) DEFAULT NULL",
            hash = "VARCHAR(50) DEFAULT NULL",
            mods = "LONGTEXT",
            plate = "VARCHAR(15) NOT NULL",
            garage = "VARCHAR(50) DEFAULT NULL",
            state = "INT(11) DEFAULT 1",
        }
    }
}
SCHEMAS.qbox = SCHEMAS.qb

CreateThread(function()
    local schema = SCHEMAS[Bridge.framework]
    if not schema then
        print('^3[autosalon]^7 Standalone: baza se ne koristi (spremanje vozila rjesava Config.Standalone.save).')
        return
    end
    if not hasDb then
        print('^1[autosalon]^7 oxmysql nije pokrenut - kupnja vozila nece moci spremiti vozilo u bazu!')
        return
    end

    local tbl = dbScalar("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?", { schema.table })
    if not tbl or tbl == 0 then
        print(("^3[autosalon]^7 Tablica '%s' ne postoji, kreiram je..."):format(schema.table))
        dbQuery(schema.create)
        print(("^2[autosalon]^7 Tablica '%s' je kreirana."):format(schema.table))
        return
    end

    local cols = dbQuery("SELECT column_name AS name FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ?", { schema.table })
    local have = {}
    for _, c in ipairs(cols or {}) do have[string.lower(c.name)] = true end

    local added = 0
    for name, def in pairs(schema.columns) do
        if not have[name] then
            added = added + 1
            print(("^3[autosalon]^7 Nedostaje stupac '%s' u %s, dodajem..."):format(name, schema.table))
            dbQuery(("ALTER TABLE `%s` ADD COLUMN `%s` %s"):format(schema.table, name, def))
        end
    end

    if added == 0 then
        print(("^2[autosalon]^7 Baza OK: tablica '%s' i svi potrebni stupci postoje."):format(schema.table))
    else
        print(("^2[autosalon]^7 Dodano %d stupaca u '%s'."):format(added, schema.table))
    end
end)

function Bridge.GetPlayer(src)
    if Bridge.framework == 'esx' then
        return ESX.GetPlayerFromId(src)
    elseif Bridge.framework == 'qb' then
        return QBCore.Functions.GetPlayer(src)
    elseif Bridge.framework == 'qbox' then
        return exports.qbx_core:GetPlayer(src)
    end
    return { source = src }
end

local function accountName(method)
    if Bridge.framework == 'esx' then
        return method == 'bank' and 'bank' or 'money'
    end
    return method == 'bank' and 'bank' or 'cash'
end

function Bridge.GetMoney(player, src, method)
    if Bridge.framework == 'esx' then
        return player.getAccount(accountName(method)).money
    elseif Bridge.framework == 'qb' or Bridge.framework == 'qbox' then
        return (player.PlayerData.money[accountName(method)]) or 0
    end
    return math.huge
end

function Bridge.RemoveMoney(player, src, method, amount, reason)
    if Bridge.framework == 'esx' then
        player.removeAccountMoney(accountName(method), amount)
        return true
    elseif Bridge.framework == 'qb' or Bridge.framework == 'qbox' then
        return player.Functions.RemoveMoney(accountName(method), amount, reason or 'autosalon-vehicle')
    end
    local s = Config.Standalone
    if s and s.charge then return s.charge(src, amount, method) == true end
    return true
end

function Bridge.AddMoney(player, src, method, amount, reason)
    if Bridge.framework == 'esx' then
        player.addAccountMoney(accountName(method), amount)
    elseif Bridge.framework == 'qb' or Bridge.framework == 'qbox' then
        player.Functions.AddMoney(accountName(method), amount, reason or 'autosalon-refund')
    else
        local s = Config.Standalone
        if s and s.refund then s.refund(src, amount, method) end
    end
end

local usedPlates = {}

function Bridge.PlateExists(plate)
    local schema = SCHEMAS[Bridge.framework]
    if schema and hasDb then
        return dbScalar(("SELECT 1 FROM `%s` WHERE plate = ? LIMIT 1"):format(schema.table), { plate }) ~= nil
    end
    return usedPlates[plate] == true
end

function Bridge.SaveVehicle(player, src, model, plate, colors)
    local hash = GetHashKey(model)

    if Bridge.framework == 'esx' then
        if not hasDb then return false end
        local props = { model = hash, plate = plate, color1 = colors.primary, color2 = colors.secondary }
        local id = dbInsert('INSERT INTO owned_vehicles (owner, plate, vehicle, type, garage) VALUES (?, ?, ?, ?, ?)', {
            player.identifier, plate, json.encode(props), 'vehicle', 'OUT'
        })
        return id ~= nil

    elseif Bridge.framework == 'qb' or Bridge.framework == 'qbox' then
        if not hasDb then return false end
        local pd = player.PlayerData
        local mods = {
            customPrimaryColor = colors.primary,
            customSecondaryColor = colors.secondary
        }
        local id = dbInsert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            pd.license, pd.citizenid, model, tostring(hash), json.encode(mods), plate,
            (Config.QB and Config.QB.garage) or 'pillboxgarage', 0
        })
        return id ~= nil
    end

    usedPlates[plate] = true
    local s = Config.Standalone
    if s and s.save then
        local ok, res = pcall(s.save, src, { model = model, plate = plate, colors = colors })
        return ok and res ~= false
    end
    return true
end

function Bridge.GetDistanceToShop(src)
    if not Config.Ped then return 0.0 end
    local pc = GetEntityCoords(GetPlayerPed(src))
    local c = Config.Ped.coords
    return #(pc - vector3(c.x, c.y, c.z))
end
