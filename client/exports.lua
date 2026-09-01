--- The public surface: control of the rectangle, not of the character drawn in it.

local Runtime = OpxHud.runtime

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
