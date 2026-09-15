--- @author DemiAutomatic
--- @file client/exports.lua
--- @description The three client exports, each answering a table carrying ok.

local State = OpxHud.State
local Runtime = OpxHud.Runtime
local Vanilla = OpxHud.Vanilla

--- @author DemiAutomatic
--- @method answer
--- @description Marks an answer table ok and returns it.
--- @param values {table}
--- @returns {HudResponse}
local function answer(values)
	values.ok = true
	return values
end

--- @author DemiAutomatic
--- @export setVisible
--- @description Shows or hides the HUD, answering the choice and down.
--- @param value {boolean}
--- @returns {HudVisibility}
exports('setVisible', function(value)
	return answer({ visible = Runtime.SetVisible(value), down = State.down })
end)

--- @author DemiAutomatic
--- @export isVisible
--- @description Answers whether the HUD is chosen shown, and whether down.
--- @returns {HudVisibility}
exports('isVisible', function()
	return answer({ visible = State.visible, down = State.down })
end)

--- @author DemiAutomatic
--- @export vanilla
--- @description Reports what became of the game's own HUD, read-only.
--- @returns {HudVanilla}
exports('vanilla', function()
	return answer(Vanilla.Snapshot())
end)
