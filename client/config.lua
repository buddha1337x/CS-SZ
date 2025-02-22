Config = {}

-- Safezone enforcement settings
Config.SafezoneMessage = "You are in a safezone."
Config.SafezoneWeaponDisable = true       -- Disallow firing weapons in a safezone
Config.SafezoneMeleeDisable = true          -- Disallow melee/punching in a safezone
Config.SafezoneSpeedLimit = 20.0            -- Speed limit (m/s) within a safezone
Config.SafezoneZRange = 10.0                -- Vertical tolerance when checking if inside safezone

-- Marker & Wall settings (for drawing safezone boundaries in admin outline mode)
Config.SafezoneDisplayMarker = false        -- Default: outlines are hidden (admins toggle with /safezones)
Config.SafezoneMarkerColor = { r = 0, g = 255, b = 0, a = 150 }
Config.SafezoneWallHeight = 10.0            -- Height of the wall along each safezone edge
Config.SafezoneWallColor = { r = 0, g = 200, b = 0, a = 150 }

-- Admin settings for safezone creation/deletion
Config.AdminCommand = "createsafezone"      -- Command to start safezone creation mode
Config.AdminDeleteCommand = "deletesafezone"  -- Command to delete the nearest safezone
