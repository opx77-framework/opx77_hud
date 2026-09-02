--- The public export surface: control of the rectangle, not of the character drawn in it.
--- Every call answers a table carrying `ok` and never raises; the shapes are in types.lua.

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
---@return HudVisibility
exports("setVisible", function(value)
  return response(true, { visible = Runtime.setVisible(value) })
end)

--- Whether the HUD is up.
---@return HudVisibility
exports("isVisible", function()
  return response(true, { visible = Runtime.isVisible() })
end)

--- What became of the game's own HUD on this client. Read-only.
---@return HudVanilla
exports("vanilla", function()
  return response(true, Vanilla.snapshot())
end)
