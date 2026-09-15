--- @author DemiAutomatic
--- @file client/vitals.lua
--- @description Reads live health and armour from the game, not from the saved character.

OpxHud.Vitals = {}

local finite = OpxHud.State.Finite

--- @author DemiAutomatic
--- @method firstFinite
--- @description Answers the first of two values that is a finite number, or nil.
--- @param first {any}
--- @param second {any}
--- @returns {number|nil}
local function firstFinite(first, second)
	if finite(first) then return first end
	if finite(second) then return second end
	return nil
end

--- @author DemiAutomatic
--- @method OpxHud.Vitals.Sample
--- @description Reads Open77.stats once: health as a percent of its maximum, armour in points.
--- @returns {HudVitals|nil, string|nil}
function OpxHud.Vitals.Sample()
	local stats = Open77.stats
	if type(stats) ~= 'table' or type(stats.get) ~= 'function' then return nil, 'api_absent' end
	local read, state = pcall(stats.get)
	if not read then return nil, tostring(state) end
	if type(state) ~= 'table' or type(state.health) ~= 'table' then return nil, nil end

	local health = state.health
	local value = firstFinite(health.value, health.current)
	if value == nil then return nil, nil end
	local maximum = firstFinite(health.maximum, health.max)
	if maximum == nil or maximum <= 0 then maximum = 100 end
	if value < 0 then value = 0 end

	local armor = finite(state.armor) and state.armor or 0
	if armor < 0 then armor = 0 end

	return { health = value / maximum * 100, armor = armor }, nil
end
