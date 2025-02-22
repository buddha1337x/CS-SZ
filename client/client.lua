local safezones = {}         
local safezoneCreationMode = false
local safezonePoints = {}    
local safezoneCam = nil      

--------------------------------------
-- Utility: Draw text on screen
--------------------------------------
function DrawTxt(x, y, text, scale)
    SetTextFont(0)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

--------------------------------------
-- Check if the current player is an admin
--------------------------------------
function isPlayerAdmin()
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and playerData.job and playerData.job.name then
        for _, rank in ipairs(Config.AdminRanks) do
            if playerData.job.name == rank then
                return true
            end
        end
    end
    return false
end

--------------------------------------
-- Safezone Creation Mode
--------------------------------------
function StartSafezoneCreationMode()
    if not isPlayerAdmin() then
        QBCore.Functions.Notify("You do not have permission.", "error")
        return
    end
    safezoneCreationMode = true
    safezonePoints = {}
    local playerPed = PlayerPedId()
    local pos = GetEntityCoords(playerPed)
    local camX, camY, camZ = pos.x, pos.y, pos.z + Config.SafezoneCameraHeight
    safezoneCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(safezoneCam, camX, camY, camZ)
    SetCamRot(safezoneCam, -90.0, 0.0, 0.0)
    RenderScriptCams(true, false, 0, true, true)
    QBCore.Functions.Notify("Safezone creation mode started. " .. Config.SafezoneCreationInstructions, "info")
end

function EndSafezoneCreationMode()
    safezoneCreationMode = false
    safezonePoints = {}
    if safezoneCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(safezoneCam, false)
        safezoneCam = nil
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if safezoneCreationMode then
            DrawTxt(0.45, 0.9, Config.SafezoneCreationInstructions, 0.6)
            if IsControlJustReleased(0, Config.SafezoneMarkKey) then
                local pos = GetEntityCoords(PlayerPedId())
                table.insert(safezonePoints, pos)
                QBCore.Functions.Notify("Point " .. #safezonePoints .. " marked.", "success")
                if #safezonePoints >= 2 then
                    local p1 = safezonePoints[1]
                    local p2 = safezonePoints[2]
                    local minX = math.min(p1.x, p2.x)
                    local maxX = math.max(p1.x, p2.x)
                    local minY = math.min(p1.y, p2.y)
                    local maxY = math.max(p1.y, p2.y)
                    local avgZ = (p1.z + p2.z) / 2
                    local safezoneData = {
                        minX = minX,
                        maxX = maxX,
                        minY = minY,
                        maxY = maxY,
                        z = avgZ
                    }
                    TriggerServerEvent("safezones:create", safezoneData)
                    QBCore.Functions.Notify("Safezone created.", "success")
                    EndSafezoneCreationMode()
                end
            end
        end
    end
end)

--------------------------------------
-- Register Admin Commands
--------------------------------------
RegisterCommand(Config.AdminCommand, function()
    StartSafezoneCreationMode()
end, false)

RegisterCommand(Config.AdminDeleteCommand, function()
    if not isPlayerAdmin() then
        QBCore.Functions.Notify("You do not have permission.", "error")
        return
    end
    local playerPos = GetEntityCoords(PlayerPedId())
    local nearestZone = nil
    local nearestDistance = 9999.0
    for _, zone in ipairs(safezones) do
        local centerX = (zone.minX + zone.maxX) / 2
        local centerY = (zone.minY + zone.maxY) / 2
        local dist = #(vector2(centerX, centerY) - vector2(playerPos.x, playerPos.y))
        if dist < nearestDistance then
            nearestDistance = dist
            nearestZone = zone
        end
    end
    if nearestZone and nearestDistance < 50.0 then 
        TriggerServerEvent("safezones:delete", nearestZone.id)
    else
        QBCore.Functions.Notify("No safezone nearby.", "error")
    end
end, false)

--------------------------------------
-- Sync safezones from the server
--------------------------------------
RegisterNetEvent("safezones:sync")
AddEventHandler("safezones:sync", function(safezoneData)
    safezones = safezoneData
end)

--------------------------------------
-- Safezone Enforcement
--------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local pos = GetEntityCoords(playerPed)
        local inZone = false
        for _, zone in ipairs(safezones) do
            if pos.x >= zone.minX and pos.x <= zone.maxX and pos.y >= zone.minY and pos.y <= zone.maxY and math.abs(pos.z - zone.z) <= Config.SafezoneZRange then
                inZone = true
                break
            end
        end
        if inZone then
            DrawTxt(0.45, 0.8, Config.SafezoneMessage, 0.7)
            if Config.SafezoneWeaponDisable then
                DisablePlayerFiring(playerPed, true)
            end
            if Config.SafezoneMeleeDisable then
                DisableControlAction(0, 24, true) -- Attack
                DisableControlAction(0, 25, true) -- Aim
            end
            if IsPedInAnyVehicle(playerPed, false) then
                local veh = GetVehiclePedIsIn(playerPed, false)
                local speed = GetEntitySpeed(veh)
                if speed > Config.SafezoneSpeedLimit then
                    SetVehicleForwardSpeed(veh, Config.SafezoneSpeedLimit)
                end
            end
        end
    end
end)

--------------------------------------
-- Draw Safezone Markers
--------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if Config.SafezoneDisplayMarker then
            for _, zone in ipairs(safezones) do
                local z = zone.z - 1.0
                local corner1 = vector3(zone.minX, zone.minY, z)
                local corner2 = vector3(zone.maxX, zone.minY, z)
                local corner3 = vector3(zone.maxX, zone.maxY, z)
                local corner4 = vector3(zone.minX, zone.maxY, z)
                local col = Config.SafezoneMarkerColor
                DrawLine(corner1.x, corner1.y, corner1.z, corner2.x, corner2.y, corner2.z, col.r, col.g, col.b, col.a)
                DrawLine(corner2.x, corner2.y, corner2.z, corner3.x, corner3.y, corner3.z, col.r, col.g, col.b, col.a)
                DrawLine(corner3.x, corner3.y, corner3.z, corner4.x, corner4.y, corner4.z, col.r, col.g, col.b, col.a)
                DrawLine(corner4.x, corner4.y, corner4.z, corner1.x, corner1.y, corner1.z, col.r, col.g, col.b, col.a)
            end
        end
    end
end)
