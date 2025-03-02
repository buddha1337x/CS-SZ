-- CS-SZ/client/client.lua
QBCore = exports['qb-core']:GetCoreObject()

local safezones = {}  -- Synced safezones from the server

Citizen.CreateThread(function()
    Wait(1000) -- Wait one second to ensure client scripts are fully loaded
    TriggerServerEvent("cs_sz:requestSync")
end)

--------------------------------------
-- CONVEX HULL UTILITY FUNCTIONS
--------------------------------------
local function cross(o, a, b)
    return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
end

local function ConvexHull(points)
    local n = #points
    if n <= 1 then 
        return points 
    end

    local pts = {}
    for i = 1, n do
        pts[i] = points[i]
    end

    table.sort(pts, function(a, b)
        if a.x == b.x then
            return a.y < b.y
        else
            return a.x < b.x
        end
    end)

    local lower = {}
    for i, p in ipairs(pts) do
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do
            table.remove(lower)
        end
        table.insert(lower, p)
    end

    local upper = {}
    for i = #pts, 1, -1 do
        local p = pts[i]
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do
            table.remove(upper)
        end
        table.insert(upper, p)
    end

    -- Remove duplicate endpoints
    table.remove(lower)
    table.remove(upper)

    for i, p in ipairs(upper) do
        table.insert(lower, p)
    end

    return lower
end

--------------------------------------
-- SAFEZONE UI CONTROL
--------------------------------------
local safezoneActive = false
function setSafezoneUI(state)
    if state ~= safezoneActive then
        safezoneActive = state
        SendNUIMessage({ action = state and "show" or "hide" })
    end
end

--------------------------------------
-- SAFEZONE CREATION MODE VARIABLES
--------------------------------------
local creationMode = false
local safezonePoints = {}  -- Current safezone boundary points (possibly auto-simplified)
local pointHistory = {}    -- History of points in insertion order

-- Whether to auto-simplify the safezone points (via convex hull)
local autoSimplify = true

--------------------------------------
-- FREECAM VARIABLES & FUNCTIONS
--------------------------------------
local freecamEnabled = false
local freecamEntity = nil
local speed = 1.2        -- base speed for freecam movement
local shiftSpeed = speed * 3.33  -- shift multiplier (approx from original values)
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
        freecamEntity = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", gameplayCamCoords.x, gameplayCamCoords.y, gameplayCamCoords.z,
            gameplayCamRot.x, gameplayCamRot.y, gameplayCamRot.z, 70.0)
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

-- Freecam movement, including scroll wheel speed adjustment
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if freecamEnabled and freecamEntity then
            local camCoords = GetCamCoord(freecamEntity)
            local camRot = GetCamRot(freecamEntity, 2)
            local direction = RotationToDirection(camRot)
            
            -- Adjust speed with mouse wheel (scroll up: 241, scroll down: 242)
            if IsControlJustPressed(0, 241) then
                speed = math.min(speed + 0.1, 10.0)
                shiftSpeed = speed * 3.33
            end
            if IsControlJustPressed(0, 242) then
                speed = math.max(speed - 0.1, 0.1)
                shiftSpeed = speed * 3.33
            end

            local horizontalMove = GetControlNormal(0, 1) * speed
            local verticalMove = GetControlNormal(0, 2) * speed

            if horizontalMove ~= 0.0 or verticalMove ~= 0.0 then
                local newPitch = camRot.x - verticalMove * mouseSensitivity
                newPitch = math.max(math.min(newPitch, 89.0), -89.0)
                local newRoll = camRot.z - horizontalMove * mouseSensitivity
                SetCamRot(freecamEntity, newPitch, camRot.y, newRoll, 2)
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

-- Display freecam speed in the top right corner when freecam is active.
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if freecamEnabled and freecamEntity then
            DrawTxt(0.85, 0.05, "Speed: " .. string.format("%.1f", speed), 0.4)
            local camCoords = GetCamCoord(freecamEntity)
            local camRot = GetCamRot(freecamEntity, 2)
            local direction = RotationToDirection(camRot)
            local rayEnd = camCoords + direction * 1000.0
            local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, rayEnd.x, rayEnd.y, rayEnd.z, -1, PlayerPedId(), 0)
            local _, hit, endCoords = GetShapeTestResult(rayHandle)
            if hit == 1 then
                local col = { r = 0, g = 255, b = 0, a = 200 }
                local rectWidth = 2.0
                local rectLength = 4.0
                local forward = direction
                local right = vector3(-forward.y, forward.x, 0.0)
                local center = endCoords
                local corner1 = center + right * (rectWidth / 2) - forward * (rectLength / 2)
                local corner2 = center - right * (rectWidth / 2) - forward * (rectLength / 2)
                local corner3 = center - right * (rectWidth / 2) + forward * (rectLength / 2)
                local corner4 = center + right * (rectWidth / 2) + forward * (rectLength / 2)
                DrawMarker(1, center.x, center.y, center.z, 0, 0, 0, 0, 0, 0, 0.15, 0.15, 0.15, 0, 255, 0, 255, false, false, 2, nil, nil, false)
            end
        end
    end
end)

--------------------------------------
-- UTILITY: Draw Text on Screen (fallback)
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
        pointHistory = {}  -- reset history on new creation
        if not freecamEnabled then
            toggleFreecam()  -- Enable freecam automatically
        end
        local initialText = "Safezone Creation Mode: Press <span style='color:green;'>G</span> to mark a point, " ..
            "<span style='color:green;'>ENTER</span> to confirm, " ..
            "<span style='color:green;'>H</span> to toggle Auto-Simplify (currently: " .. (autoSimplify and "Enabled" or "Disabled") .. "), " ..
            "and <span style='color:green;'>U</span> to undo the last point."
        QBCore.Functions.Notify("Safezone creation mode started.", "info")
        SendNUIMessage({
            action = "showCreationMode",
            text = initialText
        })
    end)
end

function EndSafezoneCreationMode()
    creationMode = false
    safezonePoints = {}
    pointHistory = {}
    if freecamEnabled then
        toggleFreecam()  -- Disable freecam when done
    end
    SendNUIMessage({ action = "hideCreationMode" })
end

-- Thread for safezone creation: marking points and confirming
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if creationMode then
            for i, point in ipairs(safezonePoints) do
                DrawMarker(1, point.x, point.y, point.z, 0, 0, 0, 0, 0, 0, 0.2, 0.2, 0.2, 255, 0, 0, 255, false, false, 2, nil, nil, false)
                DrawLine(point.x, point.y, point.z, point.x, point.y, point.z + Config.SafezoneWallHeight, 255, 0, 0, 255)
            end

            if #safezonePoints >= 2 then
                for i = 1, #safezonePoints do
                    local p1 = safezonePoints[i]
                    local nextIndex = (i % #safezonePoints) + 1
                    local p2 = safezonePoints[nextIndex]

                    local bottomA = vector3(p1.x, p1.y, p1.z)
                    local bottomB = vector3(p2.x, p2.y, p2.z)
                    local topA = vector3(p1.x, p1.y, p1.z + Config.SafezoneWallHeight)
                    local topB = vector3(p2.x, p2.y, p2.z + Config.SafezoneWallHeight)

                    DrawPoly(bottomA, bottomB, topA, 255, 0, 0, 200)
                    DrawPoly(topA, bottomB, topB, 255, 0, 0, 200)
                    DrawPoly(topA, bottomB, bottomA, 255, 0, 0, 200)
                    DrawPoly(topB, bottomB, topA, 255, 0, 0, 200)
                end
            end

            if IsControlJustReleased(0, 74) then  -- H key to toggle auto-simplification
                autoSimplify = not autoSimplify
                local stateText = autoSimplify and "Enabled" or "Disabled"
                QBCore.Functions.Notify("Auto-Simplify is now " .. stateText, "info")
                local updatedText = "Safezone Creation Mode: Press <span style='color:green;'>G</span> to mark a point, " ..
                    "<span style='color:green;'>ENTER</span> to confirm, " ..
                    "<span style='color:green;'>H</span> to toggle Auto-Simplify (currently: " .. stateText .. "), " ..
                    "and <span style='color:green;'>U</span> to undo the last point."
                SendNUIMessage({ action = "updateCreationModeText", text = updatedText })
            end

            if IsControlJustReleased(0, 303) then  -- U key to undo last point
                if #pointHistory > 0 then
                    table.remove(pointHistory)
                    QBCore.Functions.Notify("Last point undone.", "info")
                    if autoSimplify then
                        safezonePoints = ConvexHull(pointHistory)
                    else
                        safezonePoints = pointHistory
                    end
                    local updatedText = "Safezone Creation Mode: Press <span style='color:green;'>G</span> to mark a point, " ..
                        "<span style='color:green;'>ENTER</span> to confirm, " ..
                        "<span style='color:green;'>H</span> to toggle Auto-Simplify (currently: " .. (autoSimplify and "Enabled" or "Disabled") .. "), " ..
                        "and <span style='color:green;'>U</span> to undo the last point."
                    SendNUIMessage({ action = "updateCreationModeText", text = updatedText })
                else
                    QBCore.Functions.Notify("No points to undo.", "error")
                end
            end

            if IsControlJustReleased(0, 47) then  -- G key to mark a point
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
                table.insert(pointHistory, markPos)
                if autoSimplify then
                    safezonePoints = ConvexHull(pointHistory)
                else
                    safezonePoints = pointHistory
                end
                PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", false)
            end

            if IsControlJustReleased(0, 191) then  -- ENTER key to confirm safezone creation.
                if #safezonePoints == 0 then
                    QBCore.Functions.Notify("No points created, exiting safezone creation mode.", "error")
                    EndSafezoneCreationMode()
                elseif #safezonePoints < 2 then
                    QBCore.Functions.Notify("Need at least two points to create a safezone.", "error")
                else
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
                    PlaySoundFrontend(-1, "Enter_1st", "GTAO_FM_Events_Soundset", false)
                    EndSafezoneCreationMode()
                end
            end
        end
    end
end)

--------------------------------------
-- DRAW SAFEZONE OUTLINES & WALLS (ADMIN ONLY, toggled with /safezones)
--------------------------------------
local showSafezoneOutlines = false
RegisterCommand("safezones", function()
    if IsPlayerAceAllowed("CS-SZ") then
        showSafezoneOutlines = not showSafezoneOutlines
        if showSafezoneOutlines then
            QBCore.Functions.Notify("Safezone outlines enabled.", "success")
        else
            QBCore.Functions.Notify("Safezone outlines disabled.", "error")
        end
    else
        QBCore.Functions.Notify("You do not have permission to view safezone outlines.", "error")
    end
end, false)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if showSafezoneOutlines then
            for _, zone in ipairs(safezones) do
                if zone.points then
                    for i = 1, #zone.points do
                        local pt1 = zone.points[i]
                        local pt2 = zone.points[(i % #zone.points) + 1]
                        DrawLine(pt1.x, pt1.y, pt1.z, pt2.x, pt2.y, pt2.z, Config.SafezoneMarkerColor.r, Config.SafezoneMarkerColor.g, Config.SafezoneMarkerColor.b, Config.SafezoneMarkerColor.a)
                        local bottomA = vector3(pt1.x, pt1.y, pt1.z)
                        local bottomB = vector3(pt2.x, pt2.y, pt2.z)
                        local topA = vector3(pt1.x, pt1.y, pt1.z + Config.SafezoneWallHeight)
                        local topB = vector3(pt2.x, pt2.y, pt2.z + Config.SafezoneWallHeight)
                        local col = Config.SafezoneWallColor
                        DrawPoly(bottomA, bottomB, topA, col.r, col.g, col.b, col.a)
                        DrawPoly(topA, bottomB, topB, col.r, col.g, col.b, col.a)
                    end
                end
            end
        end
    end
end)

--------------------------------------
-- ADMIN COMMANDS (for creation & deletion)
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
        for _, zone in ipairs(safezones) do
            if zone.points then
                if IsPointInPolygon2D({x = playerPos.x, y = playerPos.y}, zone.points) and math.abs(playerPos.z - zone.z) <= Config.SafezoneZRange then
                    nearestZone = zone
                    break
                end
            else
                local centerX = (zone.minX + zone.maxX) / 2
                local centerY = (zone.minY + zone.maxY) / 2
                local dist = #(vector2(centerX, centerY) - vector2(playerPos.x, playerPos.y))
                if dist < 50.0 then
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
-- SYNC SAFEZONES FROM SERVER
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
        setSafezoneUI(inZone)
        if inZone then
            if Config.SafezoneWeaponDisable then
                DisablePlayerFiring(playerPed, true)
                SetPlayerCanDoDriveBy(player, false)
                DisableControlAction(2, 37, true)
            end
            if Config.SafezoneMeleeDisable then
                DisableControlAction(0, 106, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 69, true)
                DisableControlAction(0, 70, true)
                DisableControlAction(0, 92, true)
                DisableControlAction(0, 114, true)
                DisableControlAction(0, 257, true)
                DisableControlAction(0, 331, true)
                DisableControlAction(0, 68, true)
                DisableControlAction(0, 257, true)
                DisableControlAction(0, 263, true)
                DisableControlAction(0, 264, true)
                SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
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
-- POINT-IN-POLYGON UTILITY (2D ray-casting algorithm)
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
