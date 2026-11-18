-- install hammerspoon cli
local brewPrefixOutput, _, _, _ = hs.execute("brew --prefix", true)
local brewPrefix = string.gsub(brewPrefixOutput, "%s+", "")
require("hs.ipc")
local ipc = hs.ipc.cliInstall(brewPrefix)

-- Make all our animations really fast
hs.window.animationDuration = 0

-- Load SpoonInstall, so we can easily load our other Spoons
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true
Install = spoon.SpoonInstall

-- Draw pretty rounded corners on all screens
-- Install:andUse("RoundedCorners", {
--     start = true,
--     config = {
--         radius = 12,
--     },
-- })

-- use as a replacement for ReloadConfiguration for now
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "r", function()
    hs.reload()
end)
-- TODO: why is this infinitely reloading?
-- Install:andUse("ReloadConfiguration", {
--     start = true,
--     hotKeys = {
--         reloadConfiguration = { { "cmd", "ctrl", "shift" }, "r" },
--     },
-- })

-- kanata (darwin/kanata.nix) handles Caps Lock once its daemon is installed;
-- running both would send Escape twice.
if not hs.fs.attributes("/Library/LaunchDaemons/org.nixos.kanata.plist") then
    caps2esc = require("caps2esc")
end
