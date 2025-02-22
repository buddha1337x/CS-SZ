local Safezones = {}
local nextSafezoneId = 1

RegisterNetEvent("safezones:create")
AddEventHandler("safezones:create", function(safezoneData)
    local src = source
    safezoneData.id = nextSafezoneId
    nextSafezoneId = nextSafezoneId + 1
    table.insert(Safezones, safezoneData)
    TriggerClientEvent("safezones:sync", -1, Safezones)
    TriggerClientEvent("QBCore:Notify", src, "Safezone created.", "success")
end)

RegisterNetEvent("safezones:delete")
AddEventHandler("safezones:delete", function(safezoneId)
    local src = source
    for i, zone in ipairs(Safezones) do
        if zone.id == safezoneId then
            table.remove(Safezones, i)
            TriggerClientEvent("safezones:sync", -1, Safezones)
            TriggerClientEvent("QBCore:Notify", src, "Safezone deleted.", "error")
            return
        end
    end
    TriggerClientEvent("QBCore:Notify", src, "Safezone not found.", "error")
end)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    TriggerClientEvent("safezones:sync", src, Safezones)
end)
