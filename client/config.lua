Config = {}

-- Safezone enforcement settings
Config.SafezoneMessage = "You are in a safezone."
Config.SafezoneWeaponDisable = true       -- Disallow firing weapons in a safezone
Config.SafezoneMeleeDisable = true          -- Disallow melee/punching in a safezone
Config.SafezoneSpeedLimit = 20.0            -- Speed limit (m/s) within a safezone
Config.SafezoneZRange = 10.0                -- Vertical tolerance when checking if inside safezone

-- Marker settings (for drawing safezone boundaries)
Config.SafezoneDisplayMarker = true
Config.SafezoneMarkerColor = { r = 0, g = 255, b = 0, a = 150 }

-- Admin settings for safezone creation/deletion
Config.AdminCommand = "createsafezone"      -- Command to start safezone creation mode
Config.AdminDeleteCommand = "deletesafezone"  -- Command to delete the nearest safezone

-- Camera & creation mode settings
Config.SafezoneCameraHeight = 15.0          -- Height above the player for the creation camera
Config.SafezoneMarkKey = 38                 -- Key to mark a safezone point (38 = E key)
Config.SafezoneCreationInstructions = "Press ~INPUT_CONTEXT~ to mark a point for the safezone."
