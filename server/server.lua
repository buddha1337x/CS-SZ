-- CS-SZ/server/server.lua
QBCore = exports['qb-core']:GetCoreObject()

-- Custom serialization: convert a table of points to a string like "x,y,z;x,y,z;..."
local function serializePoints(points)
    local parts = {}
    for i, point in ipairs(points) do
        table.insert(parts, string.format("%.2f,%.2f,%.2f", point.x, point.y, point.z))
    end
    return table.concat(parts, ";")
end

-- Custom deserialization: convert a string back into a table of points
local function deserializePoints(str)
    local points = {}
    for part in string.gmatch(str, "[^;]+") do
        local x, y, z = part:match("([^,]+),([^,]+),([^,]+)")
        if x and y and z then
            table.insert(points, { x = tonumber(x), y = tonumber(y), z = tonumber(z) })
        end
    end
    return points
end

-- Utility function to load safezones from SQL
local function loadSafezonesFromSQL(cb)
    MySQL.Async.fetchAll("SELECT * FROM safezones", {}, function(result)
        print("SQL fetch result: " .. json.encode(result))
        local safezones = {}
        for i = 1, #result do
            local zone = result[i]
            zone.points = deserializePoints(zone.points)
            zone.z = tonumber(zone.data)  -- we store the average z in the data column
            table.insert(safezones, zone)
        end
        if cb then
            cb(safezones)
        end
    end)
end

-- On resource start, load safezones and sync them to all players
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        loadSafezonesFromSQL(function(safezones)
            TriggerClientEvent("cs_sz:sync", -1, safezones)
            print("Safezones loaded from SQL: " .. #safezones .. " zones")
        end)
    end
end)

--------------------------------------
-- Server Callback for ACE-based Admin Check
--------------------------------------
QBCore.Functions.CreateCallback('cs_sz:isAdmin', function(source, cb)
    if source == 0 then
        cb(false)
    else
        cb(IsPlayerAceAllowed(source, "CS-SZ"))
    end
end)

--------------------------------------
-- Create Safezone
--------------------------------------
RegisterNetEvent("cs_sz:create")
AddEventHandler("cs_sz:create", function(safezoneData)
    local src = source
    if not IsPlayerAceAllowed(src, "CS-SZ") then
        TriggerClientEvent("QBCore:Notify", src, "You do not have permission.", "error")
        return
    end

    -- Serialize the points table and convert average z to string
    local pointsStr = serializePoints(safezoneData.points)
    local dataStr = tostring(safezoneData.z)

    print("Inserting safezone with points: " .. pointsStr .. " and data: " .. dataStr)
    MySQL.Async.execute(
        "INSERT INTO safezones (points, data) VALUES (@points, @data)",
        {
            ["@points"] = pointsStr,
            ["@data"] = dataStr
        },
        function(rowsChanged)
            print("Rows changed after insert: " .. tostring(rowsChanged))
            loadSafezonesFromSQL(function(safezones)
                TriggerClientEvent("cs_sz:sync", -1, safezones)
                TriggerClientEvent("QBCore:Notify", src, "Safezone created.", "success")
            end)
        end
    )
end)

--------------------------------------
-- Delete Safezone
--------------------------------------
RegisterNetEvent("cs_sz:delete")
AddEventHandler("cs_sz:delete", function(safezoneId)
    local src = source
    if not IsPlayerAceAllowed(src, "CS-SZ") then
        TriggerClientEvent("QBCore:Notify", src, "You do not have permission.", "error")
        return
    end

    MySQL.Async.execute("DELETE FROM safezones WHERE id = @id", {["@id"] = safezoneId}, function(rowsChanged)
        if rowsChanged > 0 then
            loadSafezonesFromSQL(function(safezones)
                TriggerClientEvent("cs_sz:sync", -1, safezones)
                TriggerClientEvent("QBCore:Notify", src, "Safezone deleted.", "error")
            end)
        else
            TriggerClientEvent("QBCore:Notify", src, "Safezone not found.", "error")
        end
    end)
end)

--------------------------------------
-- Sync Safezones When a Player Connects
--------------------------------------
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    loadSafezonesFromSQL(function(safezones)
        TriggerClientEvent("cs_sz:sync", src, safezones)
    end)
end)

--------------------------------------
-- New: Request Sync from Client (for already-connected players after a resource restart)
--------------------------------------
RegisterNetEvent("cs_sz:requestSync")
AddEventHandler("cs_sz:requestSync", function()
    local src = source
    loadSafezonesFromSQL(function(safezones)
        TriggerClientEvent("cs_sz:sync", src, safezones)
    end)
end)
