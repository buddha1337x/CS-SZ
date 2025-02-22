-- CS-SZ/client/client.lua
QBCore = exports['qb-core']:GetCoreObject()

local safezones = {}  -- Synced safezones from the server

--[[-------------------------------------------------------------------------
    SAFEZONE CREATION MODE VARIABLES
---------------------------------------------------------------------------]]
local creationMode = false
local safezonePoints = {}  -- Array of vector3 for each marked point

--------------------------------------
-- FREECAM VARIABLES & FUNCTIONS
--------------------------------------
local freecamEnabled = false
local freecamEntity = nil
local speed = 1.2
local shiftSpeed = 4.0
local mouseSensitivity = 5.0

function RotationToDirection(rot)
    local radiansZ = math.rad(rot.z)
    local radiansX = math.rad(rot.x)
    local cosX = math.cos(radiansX)
    return vector3(-math.sin(radiansZ) * cosX, math.cos(radiansZ) * cosX, math.sin(radiansX))
end

function toggleFreecam()
    freecamEnabled = not freecamEnabled
    local playerPed = PlayerPedId()
    if freecamEnabled then
        local gameplayCamCoords = GetGameplayCamCoord()
        local gameplayCamRot = GetGameplayCamRot()
        freecamEntity = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", gameplayCamCoords.x, gameplayCamCoords.y, gameplayCamCoords.z, gameplayCamRot.x, gameplayCamRot.y, gameplayCamRot.z, 70.0)
        SetCamActive(freecamEntity, true)
        RenderScriptCams(true, true, 200, false, false)
        TaskStandStill(playerPed, -1)
    else
        local playerCoords = GetEntityCoords(playerPed)
        SetFocusPosAndVel(playerCoords.x, playerCoords.y, playerCoords.z, 0.0, 0.0, 0.0)
        SetCamActive(freecamEntity, false)
        RenderScriptCams(false, true, 0, false, false)
        DestroyCam(freecamEntity)
        freecamEntity = nil
        ClearPedTasks(playerPed)
        ClearFocus()
    end
end

-- Freecam movement and rotation handling
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if freecamEnabled and freecamEntity then
            local camCoords = GetCamCoord(freecamEntity)
            local camRot = GetCamRot(freecamEntity, 2)
            local direction = RotationToDirection(camRot)

            local horizontalMove = GetControlNormal(0, 1) * speed
            local verticalMove = GetControlNormal(0, 2) * speed

            if horizontalMove ~= 0.0 or verticalMove ~= 0.0 then
                SetCamRot(freecamEntity, camRot.x - verticalMove * mouseSensitivity, camRot.y, camRot.z - horizontalMove * mouseSensitivity)
            end

            local shift = IsDisabledControlPressed(0, 21)
            local moveSpeed = shift and shiftSpeed or speed
            local newCamCoords = camCoords

            if IsDisabledControlPressed(0, 32) then
                newCamCoords = camCoords + direction * moveSpeed
            elseif IsDisabledControlPressed(0, 33) then
                newCamCoords = camCoords - direction * moveSpeed
            elseif IsDisabledControlPressed(0, 34) then
                newCamCoords = camCoords + vector3(-direction.y, direction.x, 0.0) * moveSpeed
            elseif IsDisabledControlPressed(0, 35) then
                newCamCoords = camCoords + vector3(direction.y, -direction.x, 0.0) * moveSpeed
            end

            if IsDisabledControlPressed(0, 44) then
                newCamCoords = camCoords + vector3(0.0, 0.0, moveSpeed)
            elseif IsDisabledControlPressed(0, 36) then
                newCamCoords = camCoords - vector3(0.0, 0.0, moveSpeed)
            end

            SetCamCoord(freecamEntity, newCamCoords.x, newCamCoords.y, newCamCoords.z)
            TaskStandStill(PlayerPedId(), 10)
            SetFocusPosAndVel(newCamCoords.x, newCamCoords.y, newCamCoords.z, 0.0, 0.0, 0.0)
        end
    end
end)

-- Draw a preview rectangle where the freecam is pointing.
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if freecamEnabled and freecamEntity then
            local camCoords = GetCamCoord(freecamEntity)
            local camRot = GetCamRot(freecamEntity, 2)
            local direction = RotationToDirection(camRot)
            local rayEnd = camCoords + direction * 1000.0
            local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, rayEnd.x, rayEnd.y, rayEnd.z, -1, PlayerPedId(), 0)
            local _, hit, endCoords = GetShapeTestResult(rayHandle)
            if hit == 1 then
                -- Define rectangle size
                local rectWidth = 2.0
                local rectLength = 4.0
                local forward = direction
                local right = vector3(-forward.y, forward.x, 0.0)
                local center = endCoords
                local corner1 = center + right * (rectWidth / 2) - forward * (rectLength / 2)
                local corner2 = center - right * (rectWidth / 2) - forward * (rectLength / 2)
                local corner3 = center - right * (rectWidth / 2) + forward * (rectLength / 2)
                local corner4 = center + right * (rectWidth / 2) + forward * (rectLength / 2)
                local col = { r = 0, g = 255, b = 0, a = 200 }
                DrawLine(corner1.x, corner1.y, corner1.z, corner2.x, corner2.y, corner2.z, col.r, col.g, col.b, col.a)
                DrawLine(corner2.x, corner2.y, corner2.z, corner3.x, corner3.y, corner3.z, col.r, col.g, col.b, col.a)
                DrawLine(corner3.x, corner3.y, corner3.z, corner4.x, corner4.y, corner4.z, col.r, col.g, col.b, col.a)
                DrawLine(corner4.x, corner4.y, corner4.z, corner1.x, corner1.y, corner1.z, col.r, col.g, col.b, col.a)
            end
        end
    end
end)

--------------------------------------
-- UTILITY: Draw Text on Screen
--------------------------------------
function DrawTxt(x, y, text, scale)
    SetTextFont(0)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

--------------------------------------
-- ADMIN PERMISSION CHECK (via Server Callback)
--------------------------------------
function checkAdmin(callback)
    QBCore.Functions.TriggerCallback('cs_sz:isAdmin', function(isAdmin)
        callback(isAdmin)
    end)
end

--------------------------------------
-- SAFEZONE CREATION MODE FUNCTIONS
--------------------------------------
function StartSafezoneCreationMode()
    checkAdmin(function(isAdmin)
        if not isAdmin then
            QBCore.Functions.Notify("You do not have permission.", "error")
            return
        end
        creationMode = true
        safezonePoints = {}
        if not freecamEnabled then
            toggleFreecam()  -- Enable freecam automatically
        end
        QBCore.Functions.Notify("Safezone creation mode started. Press ~g~G~w~ to mark a point. Press ~g~ENTER~w~ to confirm.", "info")
    end)
end

function EndSafezoneCreationMode()
    creationMode = false
    safezonePoints = {}
    if freecamEnabled then
        toggleFreecam()  -- Disable freecam when done
    end
end

-- Thread for safezone creation input & drawing markers for each marked point.
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if creationMode then
            DrawTxt(0.35, 0.90, "Safezone Creation Mode: Press ~g~G~w~ to mark a point, ~g~ENTER~w~ to confirm.", 0.45)

            -- Draw each marked point: a red dot with a vertical line (10 units tall)
            for _, point in ipairs(safezonePoints) do
                DrawMarker(1, point.x, point.y, point.z, 0,0,0, 0,0,0, 0.2,0.2,0.2, 255,0,0,255, false, false, 2, nil, nil, false)
                DrawLine(point.x, point.y, point.z, point.x, point.y, point.z + 10.0, 255, 0, 0, 255)
            end

            -- Press G to add a point (using freecam's current hit position if available)
            if IsControlJustReleased(0, 47) then  -- G key
                local markPos = nil
                if freecamEnabled and freecamEntity then
                    local camCoords = GetCamCoord(freecamEntity)
                    local camRot = GetCamRot(freecamEntity, 2)
                    local direction = RotationToDirection(camRot)
                    local rayEnd = camCoords + direction * 1000.0
                    local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, rayEnd.x, rayEnd.y, rayEnd.z, -1, PlayerPedId(), 0)
                    local _, hit, endCoords = GetShapeTestResult(rayHandle)
                    if hit == 1 then
                        markPos = endCoords
                    end
                end
                if not markPos then
                    markPos = GetEntityCoords(PlayerPedId())
                end
                table.insert(safezonePoints, markPos)
                QBCore.Functions.Notify("Point " .. #safezonePoints .. " marked.", "success")
            end

            -- Press ENTER to confirm safezone creation (ENTER key code: 191)
            if IsControlJustReleased(0, 191) then
                if #safezonePoints < 2 then
                    QBCore.Functions.Notify("Need at least two points to create a safezone.", "error")
                else
                    -- Calculate average Z for safezone height
                    local totalZ = 0.0
                    for _, pt in ipairs(safezonePoints) do
                        totalZ = totalZ + pt.z
                    end
                    local avgZ = totalZ / #safezonePoints
                    local safezoneData = {
                        points = safezonePoints,
                        z = avgZ
                    }
                    TriggerServerEvent("cs_sz:create", safezoneData)
                    QBCore.Functions.Notify("Safezone created.", "success")
                    EndSafezoneCreationMode()
                end
            end
        end
    end
end)

--------------------------------------
-- POINT-IN-POLYGON UTILITY (2D, using ray-casting algorithm)
--------------------------------------
function IsPointInPolygon2D(point, poly)
    local inside = false
    local j = #poly
    for i = 1, #poly do
        local xi, yi = poly[i].x, poly[i].y
        local xj, yj = poly[j].x, poly[j].y
        if ((yi > point.y) ~= (yj > point.y)) and (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

--------------------------------------
-- ADMIN COMMANDS
--------------------------------------
RegisterCommand(Config.AdminCommand, function()
    StartSafezoneCreationMode()
end, false)

RegisterCommand(Config.AdminDeleteCommand, function()
    QBCore.Functions.TriggerCallback('cs_sz:isAdmin', function(isAdmin)
        if not isAdmin then
            QBCore.Functions.Notify("You do not have permission.", "error")
            return
        end
        local playerPos = GetEntityCoords(PlayerPedId())
        local nearestZone = nil
        local nearestDistance = 9999.0
        for _, zone in ipairs(safezones) do
            if zone.points then
                -- Use point-in-polygon for horizontal check
                if IsPointInPolygon2D({x = playerPos.x, y = playerPos.y}, zone.points) and math.abs(playerPos.z - zone.z) <= Config.SafezoneZRange then
                    nearestZone = zone
                    break
                end
            else
                -- Fallback: rectangular safezone check (if only two points were provided)
                local centerX = (zone.minX + zone.maxX) / 2
                local centerY = (zone.minY + zone.maxY) / 2
                local dist = #(vector2(centerX, centerY) - vector2(playerPos.x, playerPos.y))
                if dist < nearestDistance then
                    nearestDistance = dist
                    nearestZone = zone
                end
            end
        end
        if nearestZone then
            TriggerServerEvent("cs_sz:delete", nearestZone.id)
        else
            QBCore.Functions.Notify("No safezone nearby.", "error")
        end
    end)
end, false)

--------------------------------------
-- Sync Safezones from Server
--------------------------------------
RegisterNetEvent("cs_sz:sync")
AddEventHandler("cs_sz:sync", function(safezoneData)
    safezones = safezoneData
end)

--------------------------------------
-- SAFEZONE ENFORCEMENT (continuous check)
--------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local pos = GetEntityCoords(playerPed)
        local inZone = false
        for _, zone in ipairs(safezones) do
            if zone.points then
                if IsPointInPolygon2D({x = pos.x, y = pos.y}, zone.points) and math.abs(pos.z - zone.z) <= Config.SafezoneZRange then
                    inZone = true
                    break
                end
            else
                if pos.x >= zone.minX and pos.x <= zone.maxX and pos.y >= zone.minY and pos.y <= zone.maxY and math.abs(pos.z - zone.z) <= Config.SafezoneZRange then
                    inZone = true
                    break
                end
            end
        end
        if inZone then
            DrawTxt(0.45, 0.8, Config.SafezoneMessage, 0.7)
            if Config.SafezoneWeaponDisable then
                DisablePlayerFiring(playerPed, true)
            end
            if Config.SafezoneMeleeDisable then
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
            end
            if IsPedInAnyVehicle(playerPed, false) then
                local veh = GetVehiclePedIsIn(playerPed, false)
                local vehSpeed = GetEntitySpeed(veh)
                if vehSpeed > Config.SafezoneSpeedLimit then
                    SetVehicleForwardSpeed(veh, Config.SafezoneSpeedLimit)
                end
            end
        end
    end
end)

--------------------------------------
-- DRAW SAFEZONE MARKERS (for created safezones)
--------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if Config.SafezoneDisplayMarker then
            for _, zone in ipairs(safezones) do
                if zone.points then
                    for i = 1, #zone.points do
                        local pt1 = zone.points[i]
                        local pt2 = zone.points[(i % #zone.points) + 1]
                        DrawLine(pt1.x, pt1.y, pt1.z, pt2.x, pt2.y, pt2.z, Config.SafezoneMarkerColor.r, Config.SafezoneMarkerColor.g, Config.SafezoneMarkerColor.b, Config.SafezoneMarkerColor.a)
                    end
                else
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
    end
end)
