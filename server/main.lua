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

	local atMs = GetGameTimer()
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
