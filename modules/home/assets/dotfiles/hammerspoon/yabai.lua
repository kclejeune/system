local yabaiOutput, _, _, _ = hs.execute("which yabai", true)
local yabai = string.gsub(yabaiOutput, "%s+", "")

local function execYabai(args)
    local command = string.format("%s %s", yabai, args)
    print(string.format("yabai: %s", command))
    os.execute(command)
end

-- "directions" for vim keybindings
local directions = {
    h = "west",
    l = "east",
    k = "north",
    j = "south",
}
for key, direction in pairs(directions) do
    -- focus windows
    -- cmd + ctrl
    hs.hotkey.bind({ "cmd", "ctrl" }, key, function()
        execYabai(string.format("-m window --focus %s", direction))
    end)
    -- move windows
    -- cmd + shift
    hs.hotkey.bind({ "cmd", "shift" }, key, function()
        execYabai(string.format("-m window --warp %s", direction))
    end)
    -- swap windows
    -- alt + shift
    hs.hotkey.bind({ "shift", "alt" }, key, function()
        execYabai(string.format("-m window --swap %s", direction))
    end)
end

-- window float settings
-- alt + shift
local floating = {
    -- full
    up = "1:1:0:0:1:1",
    -- left half
    left = "1:2:0:0:1:1",
    -- right half
    right = "1:2:1:0:1:1",
}
for key, gridConfig in pairs(floating) do
    hs.hotkey.bind({ "alt", "shift" }, key, function()
        execYabai(string.format("--grid %s", gridConfig))
    end)
end
-- balance window size
hs.hotkey.bind({ "alt", "shift" }, "0", function()
    execYabai("-m space --balance")
end)

-- layout settings
local layouts = {
    a = "bsp",
    d = "float",
}
for key, layout in pairs(layouts) do
    hs.hotkey.bind({ "alt", "shift" }, key, function()
        execYabai(string.format("-m space --layout %s", layout))
    end)
end

-- toggle settings
local toggleArgs = {
    a = "-m space --toggle padding; yabai -m space --toggle gap",
    d = "-m window --toggle zoom-parent",
    e = "-m window --toggle split",
    f = "-m window --toggle zoom-fullscreen",
    o = "-m window --toggle topmost",
    r = "-m space --rotate 90",
    s = "-m window --toggle sticky",
    x = "-m space --mirror x-axis",
    y = "-m space --mirror y-axis",
}
for key, args in pairs(toggleArgs) do
    hs.hotkey.bind({ "alt" }, key, function()
        execYabai(args)
    end)
end

-- throw/focus monitors
local targets = {
    x = "recent",
    z = "prev",
    c = "next",
}
for key, target in pairs(targets) do
    hs.hotkey.bind({ "ctrl", "alt" }, key, function()
        execYabai(string.format("-m display --focus %s", target))
    end)
    hs.hotkey.bind({ "ctrl", "cmd" }, key, function()
        execYabai(string.format("-m window --display %s", target))
        execYabai(string.format("-m display --focus %s", target))
    end)
end
-- numbered monitors
for i = 1, 5 do
    hs.hotkey.bind({ "ctrl", "alt" }, tostring(i), function()
        execYabai(string.format("-m display --focus %s", i))
    end)
    hs.hotkey.bind({ "ctrl", "cmd" }, tostring(i), function()
        execYabai(string.format("-m window --display %s", i))
        execYabai(string.format("-m display --focus %s", i))
    end)
end

return {
    yabai = yabai,
    execYabai = execYabai,
}
