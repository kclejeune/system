-- Caps Lock as Ctrl when held, Escape when tapped alone; the same semantics as
-- keyd's `overload(control, esc)`. Adapted from arbelt's gist:
-- https://gist.github.com/arbelt/b91e1f38a0880afb316dd5b5732759f1
--
-- Requires Caps Lock mapped to left Ctrl first (nix-darwin
-- `system.keyboard.remapCapsLockToControl`).
--
-- A tap sends Escape on release only if nothing else was pressed in between:
-- no key, mouse button, or other modifier. The tap has no time limit, matching keyd.
local types = hs.eventtap.event.types
local LEFT_CTRL = hs.keycodes.map.ctrl

local ctrlDown = false
local sendEscape = false

local function escapeEvents()
    -- Explicit empty flags: these events are posted while the system still
    -- considers Ctrl held, and must not arrive as Ctrl+Escape.
    return {
        hs.eventtap.event.newKeyEvent({}, "escape", true),
        hs.eventtap.event.newKeyEvent({}, "escape", false),
    }
end

local function onFlagsChanged(evt)
    if evt:getKeyCode() ~= LEFT_CTRL then
        -- Another modifier changed during the hold (e.g. Ctrl+Shift): treat it
        -- as a chord, not a tap.
        if ctrlDown then
            sendEscape = false
        end
        return false
    end

    local ctrl = evt:getFlags().ctrl == true
    if ctrl and not ctrlDown then
        ctrlDown = true
        sendEscape = true
    elseif not ctrl and ctrlDown then
        ctrlDown = false
        if sendEscape then
            sendEscape = false
            -- Pass the Ctrl release through so apps never see Ctrl stuck down,
            -- and post Escape alongside it.
            return false, escapeEvents()
        end
    end
    return false
end

local function onOtherInput()
    sendEscape = false
    return false
end

local flagsTap = hs.eventtap.new({ types.flagsChanged }, onFlagsChanged)
local otherTap = hs.eventtap.new({
    types.keyDown,
    types.leftMouseDown,
    types.rightMouseDown,
    types.otherMouseDown,
    types.scrollWheel,
}, onOtherInput)

local function resync()
    ctrlDown = hs.eventtap.checkKeyboardModifiers().ctrl == true
    sendEscape = false
end

local function ensureRunning()
    for _, tap in ipairs({ flagsTap, otherTap }) do
        if not tap:isEnabled() then
            resync()
            tap:start()
        end
    end
end

-- macOS disables event taps on callback timeouts, Secure Input, and sometimes
-- across sleep, and Hammerspoon does not re-enable them.
local watchdog = hs.timer.doEvery(2, ensureRunning)
local wakeWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake or event == hs.caffeinate.watcher.screensDidUnlock then
        resync()
        flagsTap:stop()
        otherTap:stop()
        ensureRunning()
    end
end)

resync()
flagsTap:start()
otherTap:start()
wakeWatcher:start()

-- Returned (and held in a global by init.lua) so nothing is garbage collected.
return {
    flagsTap = flagsTap,
    otherTap = otherTap,
    watchdog = watchdog,
    wakeWatcher = wakeWatcher,
}
