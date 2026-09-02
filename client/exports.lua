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

--- Shows or hides the HUD.
---@param value boolean
---@return table ok and the resulting visibility
exports("setVisible", function(value)
  return response(true, { visible = Runtime.setVisible(value) })
end)

--- Whether the HUD is up.
---@return table ok and the current visibility
exports("isVisible", function()
  return response(true, { visible = Runtime.isVisible() })
end)

--- What became of the game's own HUD on this client. Read-only.
---@return table `available` false on a client whose `Open77.hud` predates the API,
--- `found` the visibility each component had before this resource touched it, and
--- `state` whatever the client reports right now
exports("vanilla", function()
  return response(true, Vanilla.snapshot())
end)
