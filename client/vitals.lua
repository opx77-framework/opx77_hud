--- @author DemiAutomatic
--- @file client/vitals.lua
--- @description Reads live health, stamina and armour from the game, not from the saved character.

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
--- @method share
--- @description A pool as a percent of its maximum: a pool table, or a flat value beside its maximum.
--- @param pool {any} A table with value/current and maximum/max, or a number.
--- @param flatMaximum {any} The maximum when the pool is a number.
--- @returns {number|nil}
local function share(pool, flatMaximum)
	local value, maximum
	if type(pool) == 'table' then
		value = firstFinite(pool.value, pool.current)
		maximum = firstFinite(pool.maximum, pool.max)
		if value == nil and finite(pool.fraction) then return math.max(0, pool.fraction) * 100 end
	elseif finite(pool) then
		value, maximum = pool, flatMaximum
	end
	if value == nil then return nil end
	if not finite(maximum) or maximum <= 0 then maximum = 100 end
	return math.max(0, value) / maximum * 100
end

--- @author DemiAutomatic
--- @method bodyHealth
--- @description The local body's health points as the game shows them, or nil.
--- @returns {number|nil}
local function bodyHealth()
	local character = Open77.character
	if type(character) ~= 'table' or type(character.state) ~= 'function' then return nil end
	local read, body = pcall(character.state)
	if not read or type(body) ~= 'table' or not finite(body.health) then return nil end
	return body.health
end

--- @author DemiAutomatic
--- @method OpxHud.Vitals.Sample
--- @description Reads the body and Open77.stats once: health and stamina as percents of their maximums, armour in points.
--- @returns {HudVitals|nil, string|nil}
function OpxHud.Vitals.Sample()
	local stats = Open77.stats
	if type(stats) ~= 'table' or type(stats.get) ~= 'function' then return nil, 'api_absent' end
	local read, state = pcall(stats.get)
	if not read then return nil, tostring(state) end
	if type(state) ~= 'table' then return nil, nil end

	-- The client documents pool tables and the server flat numbers; either shape is read.
	local health = share(state.health, state.maxHealth)
	if health == nil then return nil, nil end
	-- Damage the server never hears of (falls, npcs) only lowers the body, so the body wins,
	-- measured against the canonical maximum.
	local body = bodyHealth()
	if body ~= nil then
		local pool = state.health
		local maximum = type(pool) == 'table' and firstFinite(pool.maximum, pool.max) or state.maxHealth
		health = share(body, maximum)
	end
	local armor = finite(state.armor) and math.max(0, state.armor) or 0
	return { health = health, armor = armor, stamina = share(state.stamina, state.maxStamina) }, nil
end

