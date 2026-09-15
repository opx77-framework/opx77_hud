---@meta

OpxHud.State = {}

--- The last `PlayerData` snapshot opx77_core gave, or nil while no character is loaded.
---@type PlayerData|nil
OpxHud.State.data = nil

--- Whether the surface is shown at all; the character being absent is separate.
---@type boolean
OpxHud.State.visible = true

--- Whether opx77_medic has the player down. Kept apart from `visible`, the player's own choice:
--- while down nothing is drawn whatever `visible` says, and a revival puts back what they had.
---@type boolean
OpxHud.State.down = false

--- The needs opx77_status last published for the live character, or nil while it has not
--- answered with `ready = true`: the gauges it owns then leave the frame instead of reading zero.
---@type NeedValues|nil
OpxHud.State.needs = nil

--- Adopts what opx77_status published. Anything but `ready == true` with a table clears them.
---@param values NeedValues|nil
---@param ready boolean
function OpxHud.State.SetNeeds(values, ready) end

--- Whether a value is a number that is neither NaN nor an infinity.
---@param value any
---@return boolean
function OpxHud.State.Finite(value) end

--- The rows every configured block builds, in `BLOCKS` order, or nil while the surface is
--- hidden or no character is loaded. Chips are added by client/main.lua.
---@return HudFrame|nil
function OpxHud.State.View() end

--- A string reduction of a view (id, label, value, pct, tone and icon of every row), so an
--- unchanged frame is not sent. A nil view answers "\0".
---@param view HudFrame|nil
---@return string
function OpxHud.State.Signature(view) end
