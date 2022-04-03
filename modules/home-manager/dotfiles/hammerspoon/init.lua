require("yabai")

-- install hammerspoon cli
local brewPrefixOutput, _, _, _ = hs.execute("brew --prefix", true)
local brewPrefix = string.gsub(brewPrefixOutput, "%s+", '')
require("hs.ipc")
local ipc = hs.ipc.cliInstall(brewPrefix)
print(string.format("ipc: %s", ipc))

-- Make all our animations really fast
hs.window.animationDuration = 0.1
hs.hotkey.bind({"cmd", "ctrl", "shift"}, "r", function()
    hs.reload()
end)

-- Load SpoonInstall, so we can easily load our other Spoons
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true
Install = spoon.SpoonInstall

-- Draw pretty rounded corners on all screens
Install:andUse("RoundedCorners", {
    start = true,
    config = {
        radius = 12
    }
})
