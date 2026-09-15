--- @author DemiAutomatic
--- @file client/exports.lua
--- @description The three client exports, each answering a table carrying ok.

local Runtime = OpxHud.Runtime
local Vanilla = OpxHud.Vanilla

--- @author DemiAutomatic
--- @method response
--- @description Sets ok on an answer table and returns it.
--- @param ok {boolean}
--- @param values {table|nil}
--- @returns {HudResponse}
local function response(ok, values)
	values = values or {}
	values.ok = ok == true
	return values
end

--- @author DemiAutomatic
--- @export setVisible
--- @description Shows or hides the HUD and answers the resulting visibility.
--- @param value {boolean}
--- @returns {HudVisibility}
exports('setVisible', function(value)
	return response(true, { visible = Runtime.SetVisible(value) })
end)

--- @author DemiAutomatic
--- @export isVisible
--- @description Answers whether the HUD is shown.
--- @returns {HudVisibility}
exports('isVisible', function()
	return response(true, { visible = Runtime.IsVisible() })
end)

--- @author DemiAutomatic
--- @export vanilla
--- @description Reports what became of the game's own HUD, read-only.
--- @returns {HudVanilla}
exports('vanilla', function()
	return response(true, Vanilla.Snapshot())
end)
