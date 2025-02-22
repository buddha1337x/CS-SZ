QBCore = exports['qb-core']:GetCoreObject()

local Safezones = {}
local nextSafezoneId = 1

--------------------------------------
-- Server Callback for ACE-based Admin Check
--------------------------------------
QBCore.Functions.CreateCallback('cs_sz:isAdmin', function(source, cb)
    if source == 0 then
        cb(false) -- txAdmin console is not allowed
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
    safezoneData.id = nextSafezoneId
    nextSafezoneId = nextSafezoneId + 1
    table.insert(Safezones, safezoneData)
    TriggerClientEvent("cs_sz:sync", -1, Safezones)
    TriggerClientEvent("QBCore:Notify", src, "Safezone created.", "success")
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
    for i, zone in ipairs(Safezones) do
        if zone.id == safezoneId then
            table.remove(Safezones, i)
            TriggerClientEvent("cs_sz:sync", -1, Safezones)
            TriggerClientEvent("QBCore:Notify", src, "Safezone deleted.", "error")
            return
        end
    end
    TriggerClientEvent("QBCore:Notify", src, "Safezone not found.", "error")
end)

--------------------------------------
-- Sync Safezones When a Player Connects
--------------------------------------
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    TriggerClientEvent("cs_sz:sync", src, Safezones)
end)
