--- The public surface: control of the rectangle, not of the character drawn in it.

local Runtime = OpxHud.runtime
local Vanilla = OpxHud.vanilla

---@param ok boolean
---@param values table|nil
---@return table
local function response(ok, values)
  values = values or {}
  values.ok = ok == true
  return values
end

--- A server that wants a key registers the mapping in its own resource and calls this.
---@param value boolean
---@return table ok and the resulting visibility
exports("setVisible", function(value)
  return response(true, { visible = Runtime.setVisible(value) })
end)

---@return table ok and the current visibility
exports("isVisible", function()
  return response(true, { visible = Runtime.isVisible() })
end)

--- What became of the game's own HUD on this client. Read-only, and the honest answer
--- rather than a copy of the configuration: `available` is false on a client whose
--- `Open77.hud` predates the API, `found` is the visibility each component had before this
--- resource touched it, and `state` is whatever the client reports right now.
---
--- Here so that "the vanilla minimap is still on screen" has an answer that does not involve
--- reading the log. Nothing may set these through an export: the game's HUD is this
--- resource's to hide because this resource draws the replacement, and a second opinion
--- arriving from somewhere else is how a player ends up with neither HUD.
---@return table
exports("vanilla", function()
  return response(true, Vanilla.snapshot())
end)
