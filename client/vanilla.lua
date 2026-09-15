--- @author DemiAutomatic
--- @file client/vanilla.lua
--- @description Hides the game's own HUD components this resource replaces.

local Config = OPX_HUD_CONFIG

OpxHud.Vanilla = {}
local Vanilla = OpxHud.Vanilla

--- @author DemiAutomatic
--- @type {string}
--- @description This resource's own name, for its lifecycle events.
local RESOURCE = GetCurrentResourceName()

--- @author DemiAutomatic
--- @type {table<string, boolean>|nil}
--- @description Visibility each component had before the first apply.
local found = nil

--- @author DemiAutomatic
--- @method api
--- @description Answers Open77.hud when it can set visibility, else nil.
--- @returns {table|nil}
local function api()
	local hud = Open77.hud
	if type(hud) ~= 'table' then return nil end
	if type(hud.setVisible) ~= 'function' then return nil end
	return hud
end

--- @author DemiAutomatic
--- @method known
--- @description Answers the component names this client reports, or nil.
--- @param hud {table}
--- @returns {table<string, boolean>|nil}
local function known(hud)
	local ok, list = pcall(hud.components)
	if not ok or type(list) ~= 'table' then return nil end
	local set = {}
	for index = 1, #list do
		local name = list[index]
		if type(name) == 'string' then set[name] = true end
	end
	if next(set) == nil then return nil end
	return set
end

--- @author DemiAutomatic
--- @method visibility
--- @description Answers a component's current visibility, or nil when unreported.
--- @param hud {table}
--- @param component {string}
--- @returns {boolean|nil}
local function visibility(hud, component)
	local ok, value = pcall(hud.isVisible, component)
	if not ok or type(value) ~= 'boolean' then return nil end
	return value
end

--- @author DemiAutomatic
--- @method OpxHud.Vanilla.Apply
--- @description Applies the VANILLA config, recording prior visibility once.
--- @returns {integer, string|nil}
function OpxHud.Vanilla.Apply()
	local wanted = Config.VANILLA
	if wanted == false or wanted == nil then return 0 end
	if type(wanted) ~= 'table' then return 0, 'config_not_a_table' end

	local hud = api()
	if hud == nil then return 0, 'api_absent' end

	local set = known(hud)
	local first = found == nil
	if first then found = {} end

	local applied = 0
	for component, visible in pairs(wanted) do
		if type(component) ~= 'string' or type(visible) ~= 'boolean' then
			Open77.log.warn(('vanilla: ignoring %s -- a component name maps to true or false')
				:format(tostring(component)))
		elseif set ~= nil and not set[component] then
			Open77.log.warn(('vanilla: this client has no component named %q'):format(component))
		else
			if first then found[component] = visibility(hud, component) end
			local ok, reason = pcall(hud.setVisible, component, visible)
			if ok then
				applied = applied + 1
			else
				Open77.log.warn(('vanilla: %s could not be set -- %s'):format(component, tostring(reason)))
			end
		end
	end

	return applied
end

--- @author DemiAutomatic
--- @method OpxHud.Vanilla.Snapshot
--- @description Reports what became of the game's own HUD.
--- @returns {HudVanilla}
function OpxHud.Vanilla.Snapshot()
	local hud = api()
	local live = nil
	if hud ~= nil then
		local ok, value = pcall(hud.state)
		if ok and type(value) == 'table' then live = value end
	end
	return { available = hud ~= nil, found = found, state = live }
end

--- @author DemiAutomatic
--- @event onClientResourceStart
--- @description Hides the configured game HUD components and logs the outcome.
--- @param name {string}
AddEventHandler('onClientResourceStart', function(name)
	if name ~= RESOURCE then return end

	local applied, reason = Vanilla.Apply()
	if reason == 'config_not_a_table' then
		Open77.log.warn('vanilla: VANILLA in config.lua is neither a table nor false, so the')
		Open77.log.warn("  game's own HUD was left exactly as it was.")
	elseif reason == 'api_absent' then
		Open77.log.warn("vanilla: Open77.hud is missing on this client, so the game's own HUD")
		Open77.log.warn('  stays on screen underneath this one. It arrived with the ui.vanilla.hud')
		Open77.log.warn('  capability; a client older than that cannot hide it. Update, or set')
		Open77.log.warn('  VANILLA = false in config.lua to stop this warning.')
	elseif applied > 0 then
		Open77.log.info(('vanilla: %d component%s set'):format(applied, applied == 1 and '' or 's'))
	end
end)

--- @author DemiAutomatic
--- @event opx77:client:onPlayerLoaded
--- @description Hides the game HUD again after the character incarnates.
AddEventHandler('opx77:client:onPlayerLoaded', function()
	Vanilla.Apply()
end)
