Config = {}

-- Safezone enforcement settings
Config.SafezoneMessage = "You are in a safezone."
Config.SafezoneWeaponDisable = true       -- Disallow firing weapons in a safezone
Config.SafezoneMeleeDisable = true          -- Disallow melee/punching in a safezone
Config.SafezoneSpeedLimit = 20.0            -- Speed limit in m/s within safezone
Config.SafezoneZRange = 10.0                -- Vertical tolerance when checking if inside safezone

-- Marker settings (for drawing the safezone boundaries)
Config.SafezoneDisplayMarker = true
Config.SafezoneMarkerColor = { r = 0, g = 255, b = 0, a = 150 }

-- Admin settings for safezone creation/deletion
Config.AdminCommand = "createsafezone"      -- Command to start safezone creation mode
Config.AdminDeleteCommand = "deletesafezone"  -- Command to delete the nearest safezone
Config.AdminRanks = { "admin", "superadmin" } -- Example admin job names (adjust as needed)

-- Camera & creation mode settings
Config.SafezoneCameraHeight = 15.0          -- How high above the player the creation camera should be placed
Config.SafezoneMarkKey = 38                 -- Key to mark a safezone point (38 = E key)
Config.SafezoneCreationInstructions = "Press ~INPUT_CONTEXT~ to mark a point for the safezone."
