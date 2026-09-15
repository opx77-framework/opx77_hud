---@meta

OpxHud.Vehicle = {}

--- Whether `OPX_HUD_CONFIG.VEHICLE` is a table; false builds no read-out.
---@type boolean
OpxHud.Vehicle.enabled = true

--- The read-out for the vehicle the local character sits in, from `Open77.vehicles.getPlayerSeat`
--- and `Open77.vehicles.get`. Nil on foot, from a passenger seat when `VEHICLE.PASSENGER` is
--- false, while disabled, or on a client without the vehicle API.
---@return HudVehicleView|nil
function OpxHud.Vehicle.Sample() end

--- A string reduction of a read-out, so an unchanged one is not sent. A nil read-out answers "\0".
---@param view HudVehicleView|nil
---@return string
function OpxHud.Vehicle.Signature(view) end
