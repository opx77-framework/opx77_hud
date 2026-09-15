--- @author DemiAutomatic
--- @file client/vehicle.lua
--- @description Reads the local character's seat and vehicle telemetry for the vehicle read-out.

local Config = OPX_HUD_CONFIG

OpxHud.Vehicle = {}

local finite = OpxHud.State.Finite

--- @author DemiAutomatic
--- @type {string}
--- @description Seat whose occupant drives; the front-left seat holds the physics lease.
local DRIVER_SEAT = 'seat_front_left'

--- @author DemiAutomatic
--- @type {number}
--- @description Metres per second to kilometres per hour.
local KPH = 3.6

--- @author DemiAutomatic
--- @type {integer}
--- @description Highest speed drawn, so a physics spike never widens the read-out.
local MAX_KPH = 999

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether a vehicle table is configured at all; false builds no read-out.
OpxHud.Vehicle.enabled = type(Config.VEHICLE) == 'table'

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether a passenger sees the read-out too, not only the driver.
local PASSENGER = OpxHud.Vehicle.enabled and Config.VEHICLE.PASSENGER ~= false

--- @author DemiAutomatic
--- @method clampPercent
--- @description Answers a 0..1 ratio as a whole percent, 0..100.
--- @param ratio {number}
--- @returns {integer}
local function clampPercent(ratio)
	if ratio < 0 then ratio = 0 end
	if ratio > 1 then ratio = 1 end
	return math.floor(ratio * 100 + 0.5)
end

--- @author DemiAutomatic
--- @method gearLabel
--- @description Answers R, N or the forward gear number a snapshot reports.
--- @param vehicle {table}
--- @returns {string}
local function gearLabel(vehicle)
	local gear = finite(vehicle.gear) and math.floor(vehicle.gear) or 0
	if vehicle.reversing == true or gear < 0 then return 'R' end
	if gear == 0 then return 'N' end
	return tostring(gear)
end

--- @author DemiAutomatic
--- @method OpxHud.Vehicle.Sample
--- @description Answers the read-out for the vehicle the character sits in, or nil when on foot.
--- @returns {HudVehicleView|nil}
function OpxHud.Vehicle.Sample()
	if not OpxHud.Vehicle.enabled then return nil end
	local vehicles = Open77.vehicles
	if type(vehicles) ~= 'table' or type(vehicles.getPlayerSeat) ~= 'function'
		or type(vehicles.get) ~= 'function' then
		return nil
	end

	local seated, seat = pcall(vehicles.getPlayerSeat)
	if not seated or type(seat) ~= 'table' or seat.vehicleId == nil then return nil end
	local driver = seat.seat == nil or tostring(seat.seat) == DRIVER_SEAT
	if not driver and not PASSENGER then return nil end

	local read, vehicle = pcall(vehicles.get, seat.vehicleId)
	if not read or type(vehicle) ~= 'table' then return nil end

	local speed = finite(vehicle.speed) and math.abs(vehicle.speed) * KPH or 0
	speed = math.floor(speed + 0.5)
	if speed > MAX_KPH then speed = MAX_KPH end

	local rpm = nil
	if finite(vehicle.rpm) and finite(vehicle.rpmMax) and vehicle.rpmMax > 1 then
		rpm = clampPercent(vehicle.rpm / vehicle.rpmMax)
	end

	local integrity, tone = nil, nil
	if finite(vehicle.health) then
		integrity = clampPercent(vehicle.health)
		if integrity <= 15 then tone = 'bad' elseif integrity <= 33 then tone = 'warn' end
	end

	return {
		speed = speed,
		gear = gearLabel(vehicle),
		rpm = rpm,
		integrity = integrity,
		tone = tone,
		airborne = vehicle.onGround == false,
	}
end

--- @author DemiAutomatic
--- @method OpxHud.Vehicle.Signature
--- @description Reduces a read-out to a string, so an unchanged one is not sent.
--- @param view {HudVehicleView|nil}
--- @returns {string}
function OpxHud.Vehicle.Signature(view)
	if view == nil then return '\0' end
	return table.concat({
		tostring(view.speed), view.gear, tostring(view.rpm or ''),
		tostring(view.integrity or ''), view.tone or '', view.airborne and '1' or '0',
	}, '\1')
end
