-- This module is adapted from https://gist.github.com/arbelt/b91e1f38a0880afb316dd5b5732759f1
-- Many thanks to @arbelt!
-- Sends "escape" if "caps lock" is held for a short interval, and no other keys are pressed.
-- note: this requires caps lock to be mapped to ctrl, either by macOS settings, or another tool such as Karabiner
sendEscape = false
lastMods = {}

local controlKeyHandler = function()
	sendEscape = false
end

controlKeyTimer = hs.timer.delayed.new(0.1, controlKeyHandler)

controlHandler = function(evt)
	local newMods = evt:getFlags()
	if lastMods["ctrl"] == newMods["ctrl"] then
		return false
	end
	if not lastMods["ctrl"] then
		lastMods = newMods
		sendEscape = true
		controlKeyTimer:start()
	else
		lastMods = newMods
		controlKeyTimer:stop()
		if sendEscape then
			return true,
				{
					hs.eventtap.event.newKeyEvent({}, "escape", true),
					hs.eventtap.event.newKeyEvent({}, "escape", false),
				}
		end
	end
	return false
end

controlTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, controlHandler)
controlTap:start()
