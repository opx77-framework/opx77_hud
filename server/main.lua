--- @author DemiAutomatic
--- @file server/main.lua
--- @description The server half: the show and hide chat command and its suggestion.

local Config = OPX_HUD_CONFIG

--- @author DemiAutomatic
--- @type {string|false}
--- @description The configured command name, or false for none.
local name = Config.COMMAND

if type(name) ~= 'string' or name == '' then
	Open77.log.info('no command registered (OPX_HUD_CONFIG.COMMAND is off)')
	return
end

--- @author DemiAutomatic
--- @type {integer}
--- @description Last finite clock reading in milliseconds.
local lastMs = 0

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether the clock fallback has already been logged.
local clockWarned = false

--- @author DemiAutomatic
--- @method nowMs
--- @description Scheduler milliseconds, falling back to GetGameTimer on a bad reading.
--- @returns {integer}
local function nowMs()
	local read, seconds = pcall(Open77.time.monotonic)
	if read and type(seconds) == 'number' and seconds == seconds and
		seconds >= 0 and seconds < math.huge then
		lastMs = math.floor(seconds * 1000)
		return lastMs
	end
	local ticked, ms = pcall(GetGameTimer)
	if ticked and type(ms) == 'number' and ms == ms and ms >= 0 and ms < math.huge then
		if not clockWarned then
			clockWarned = true
			Open77.log.warn('Open77.time.monotonic unreadable; falling back to GetGameTimer')
		end
		lastMs = math.floor(ms)
	end
	return lastMs
end

--- @author DemiAutomatic
--- @command OPX_HUD_CONFIG.COMMAND
--- @description Resolves on, off or toggle and sends it to the caller.
--- @param source {integer|string}
--- @param args {string[]|nil}
--- @param rawCommand {string}
RegisterCommand(name, function(source, args, rawCommand)
	local player = tonumber(source) or 0
	if player <= 0 then
		Open77.log.info('/' .. name .. ' is a player command')
		return
	end

	local wanted = args and args[1]
	local mode = 'toggle'
	if wanted ~= nil then
		wanted = tostring(wanted):lower()
		if wanted == 'on' or wanted == 'show' then
			mode = 'show'
		elseif wanted == 'off' or wanted == 'hide' then
			mode = 'hide'
		else
			TriggerClientEvent('opx77_hud:notice', player, 'warning',
				locale('hud.usage', { command = '/' .. name }))
			return
		end
	end

	TriggerClientEvent('opx77_hud:visibility', player, mode)
end, false)

--- @author DemiAutomatic
--- @type {table<integer, integer>}
--- @description When the suggestion was last sent, per player.
local lastSuggestedMs = {}

--- @author DemiAutomatic
--- @type {integer}
--- @description Milliseconds before one player is sent the suggestion again.
local SUGGEST_RATE_MS = 10000

--- @author DemiAutomatic
--- @event chat:ready
--- @description Sends the command's chat suggestion to a player, rate limited.
RegisterNetEvent('chat:ready', function()
	local player = tonumber(source) or 0
	if player <= 0 then return end

	local atMs = nowMs()
	local previous = lastSuggestedMs[player]
	if previous ~= nil and atMs - previous < SUGGEST_RATE_MS then return end
	lastSuggestedMs[player] = atMs

	TriggerClientEvent('chat:addSuggestion', player, '/' .. name,
		locale('hud.commandHelp'),
		{ { name = 'on|off', help = locale('hud.commandArgument'), optional = true } })
end)

--- @author DemiAutomatic
--- @method forget
--- @description Drops a departed player's suggestion rate limit entry.
--- @param playerId {string}
local function forget(playerId)
	local player = tonumber(playerId)
	if player == nil then
		Open77.log.warn(('onPlayerDisconnected: unusable player id %q'):format(tostring(playerId)))
		return
	end
	lastSuggestedMs[player] = nil
end

--- @author DemiAutomatic
--- @event onPlayerDisconnected
--- @description Forgets a departing player's suggestion rate limit.
AddEventHandler('onPlayerDisconnected', forget)
