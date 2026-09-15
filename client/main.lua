--- @author DemiAutomatic
--- @file client/main.lua
--- @description The WebUI surface, its frames, and the opx77_core, opx77_status and opx77_medic links.

local Config = OPX_HUD_CONFIG

--- @author DemiAutomatic
--- @type {integer}
--- @description Number of segments a gauge is cut into.
local GAUGE_SEGMENTS = 10

--- @author DemiAutomatic
--- @type {integer}
--- @description Width of the surface the page is composited on.
local SURFACE_WIDTH = 1920

--- @author DemiAutomatic
--- @type {integer}
--- @description Height of the surface, which bounds a published strip offset.
local SURFACE_HEIGHT = 1080

local State = OpxHud.State
local finite = State.Finite
local Keys = OpxHud.Keys

--- @author DemiAutomatic
--- @type {string}
--- @description Stable id of the show and hide mapping.
local KEY_TOGGLE = 'opx77_hud.toggle'

OpxHud.Runtime = {}
local Runtime = OpxHud.Runtime

--- @author DemiAutomatic
--- @type {string}
--- @description This resource's own name, for its lifecycle events.
local RESOURCE = GetCurrentResourceName()

--- @author DemiAutomatic
--- @type {string}
--- @description Resource holding the character snapshot.
local CORE = 'opx77_core'

--- @author DemiAutomatic
--- @type {string}
--- @description Resource holding the needs and the status chips.
local STATUS = 'opx77_status'

--- @author DemiAutomatic
--- @type {string}
--- @description Resource raising toasts for the command's answers.
local NOTIFY = 'opx77_notify'

--- @author DemiAutomatic
--- @type {string}
--- @description Resource deciding whether the player is down.
local MEDIC = 'opx77_medic'

--- @author DemiAutomatic
--- @type {string}
--- @description Local event opx77_status raises with the needs.
local NEEDS_EVENT = 'opx77:status:needs'

--- @author DemiAutomatic
--- @type {string}
--- @description Local event opx77_status raises with the status chips.
local EFFECTS_EVENT = 'opx77:status:effects'

--- @author DemiAutomatic
--- @type {string}
--- @description Local event opx77_medic raises on every down state change.
local MEDIC_EVENT = 'opx77:medic:stateChanged'

--- @author DemiAutomatic
--- @type {table|nil}
--- @description The WebUI surface, nil until created or after this stop.
local page

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether the page has raised hud:ready.
local pageReady = false

--- @author DemiAutomatic
--- @type {string|nil}
--- @description Signature of the last frame the page accepted.
local drawn = nil

--- @author DemiAutomatic
--- @method send
--- @description Posts one message to the page, logging a host raise.
--- @param name {string}
--- @param payload {table}
--- @returns {boolean}
local function send(name, payload)
	local ok, reason = pcall(page.send, page, name, payload)
	if not ok then Open77.log.error('page ' .. name .. ': ' .. tostring(reason)) end
	return ok
end

--- @author DemiAutomatic
--- @type {integer}
--- @description Most chips kept from one effects payload.
local MAX_CHIPS = 12

--- @author DemiAutomatic
--- @type {integer}
--- @description Largest overflow count that still reads as a number.
local MAX_HIDDEN = 999

--- @author DemiAutomatic
--- @type {table}
--- @description Bounded status chips carried into the next frame, with their signature.
local effects = { chips = {}, hidden = 0, signature = '' }

--- @author DemiAutomatic
--- @method draw
--- @description Sends a frame or hides the surface when the picture changed.
--- @param force {boolean|nil} Skip the signature test.
local function draw(force)
	if page == nil or not pageReady then return end
	local view = State.View()
	local signature = State.Signature(view) .. '\2' .. effects.signature
	if not force and signature == drawn then return end
	local sent
	if not State.visible or State.down or (view == nil and #effects.chips == 0) then
		sent = send('hud:hide', {})
	else
		view = view or { rows = {} }
		view.chips = effects.chips
		view.hidden = effects.hidden
		view.stripAnchor = effects.anchor
		view.stripOffset = effects.offset
		sent = send('hud:frame', view)
	end
	drawn = sent and signature or nil
end

--- @author DemiAutomatic
--- @method call
--- @description Calls another resource's export from a coroutine, at three levels.
--- @param resource {string}
--- @param name {string}
--- @returns {table|nil, string|nil, boolean}
local function call(resource, name, ...)
	if GetResourceState(resource) ~= 'running' then return nil, 'not_running', false end
	local promise, reason = Open77.exports.call(resource, name, ...)
	if not promise then return nil, tostring(reason or 'not_dispatched'), false end
	local result, callError = promise:await()
	if callError then return nil, tostring(callError), false end
	if type(result) ~= 'table' then return nil, 'malformed_answer', true end
	if result.ok ~= true then return nil, tostring(result.error or 'refused'), true end
	return result, nil, true
end

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether a toast failure has already been logged.
local notifyReported = false

--- @author DemiAutomatic
--- @method chatLine
--- @description Writes an answer as a chat line when no toast is possible.
--- @param kind {string} info, success, warning or error.
--- @param message {string}
local function chatLine(kind, message)
	TriggerEvent('chat:addMessage', {
		type = (kind == 'info' or kind == 'success') and 'info' or 'error',
		author = locale('hud.title'),
		text = message,
	})
end

--- @author DemiAutomatic
--- @method notify
--- @description Tells the player something by toast, or by chat line otherwise.
--- @param kind {string} info, success, warning or error.
--- @param message {string}
local function notify(kind, message)
	if Config.NOTIFY == false then return chatLine(kind, message) end
	CreateThread(function()
		local _, failure = call(NOTIFY, 'show', {
			id = 'opx77_hud.answer',
			replace = true,
			type = kind,
			title = locale('hud.title'),
			message = message,
			durationMs = 5000,
		})
		if failure == nil then return end
		if not notifyReported then
			notifyReported = true
			Open77.log.warn(('no toast (%s): answers go to the chat box instead'):format(failure))
		end
		chatLine(kind, message)
	end)
end

--- @author DemiAutomatic
--- @method pull
--- @description Reads the character snapshot from opx77_core once, from a coroutine.
local function pull()
	local result, _, answered = call(CORE, 'GetPlayerData')
	if result == nil then
		if answered then State.data = nil end
		return
	end
	State.data = result.data
end

--- @author DemiAutomatic
--- @method pullNeeds
--- @description Reads the needs from opx77_status once, from a coroutine.
local function pullNeeds()
	local result, _, answered = call(STATUS, 'getNeeds')
	if result == nil then
		if answered then State.SetNeeds(nil, false) end
		return
	end
	State.SetNeeds(result.values, result.ready == true)
end

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether a medic state event landed since this resource started.
local medicHeard = false

--- @author DemiAutomatic
--- @method setDown
--- @description Takes the surface off screen while down, and back after.
--- @param value {boolean}
local function setDown(value)
	local down = value == true
	if State.down == down then return end
	State.down = down
	draw(true)
end

--- @author DemiAutomatic
--- @method pullDown
--- @description Reads the down state from opx77_medic once, from a coroutine.
local function pullDown()
	local result = call(MEDIC, 'isDown')
	if result == nil or medicHeard then return end
	setDown(result.down == true)
end

--- @author DemiAutomatic
--- @event opx77:client:onPlayerLoaded
--- @description Adopts the loaded character's snapshot and redraws.
--- @param playerData {PlayerData}
AddEventHandler('opx77:client:onPlayerLoaded', function(playerData)
	if type(playerData) ~= 'table' then return end
	State.data = playerData
	draw()
end)

--- @author DemiAutomatic
--- @event opx77:client:playerDataChanged
--- @description Adopts the replacement character snapshot and redraws.
--- @param playerData {PlayerData}
AddEventHandler('opx77:client:playerDataChanged', function(playerData)
	if type(playerData) ~= 'table' then return end
	State.data = playerData
	draw()
end)

--- @author DemiAutomatic
--- @event opx77:status:needs
--- @description Adopts the needs opx77_status pushed and redraws.
--- @param payload {NeedsSnapshot}
AddEventHandler(NEEDS_EVENT, function(payload)
	if type(payload) ~= 'table' then return end
	State.SetNeeds(payload.values, payload.ready == true)
	draw()
end)

--- @author DemiAutomatic
--- @method hiddenCount
--- @description Bounds the overflow count to 0..MAX_HIDDEN, floored.
--- @param value {any}
--- @returns {integer}
local function hiddenCount(value)
	local number = tonumber(value)
	if not finite(number) or number <= 0 then return 0 end
	if number > MAX_HIDDEN then return MAX_HIDDEN end
	return math.floor(number)
end

--- @author DemiAutomatic
--- @method anchorOf
--- @description Answers a short string strip corner, or nil.
--- @param value {any}
--- @returns {string|nil}
local function anchorOf(value)
	if type(value) ~= 'string' or #value > 32 then return nil end
	return value
end

--- @author DemiAutomatic
--- @method offsetOf
--- @description Answers a strip offset within the surface height, or nil.
--- @param value {any}
--- @returns {number|nil}
local function offsetOf(value)
	local number = tonumber(value)
	if not finite(number) or number < 0 or number > SURFACE_HEIGHT then return nil end
	return number
end

--- @author DemiAutomatic
--- @event opx77:status:effects
--- @description Bounds the published status chips and carries them into a frame.
--- @param payload {StatusEffectsEvent}
AddEventHandler(EFFECTS_EVENT, function(payload)
	if type(payload) ~= 'table' then return end
	local chips = {}
	local kept = 0
	local offered = payload.chips
	if type(offered) == 'table' then
		local count = #offered
		if count > MAX_CHIPS then count = MAX_CHIPS end
		for index = 1, count do
			local chip = offered[index]
			if type(chip) == 'table' and chip.id ~= nil then
				kept = kept + 1
				chips[kept] = chip
			end
		end
	end

	local hidden = hiddenCount(payload.hidden)
	local anchor = anchorOf(payload.anchor)
	local offset = offsetOf(payload.offset)

	local marks = {}
	local field = 0
	for index = 1, kept do
		local chip = chips[index]
		marks[field + 1] = tostring(chip.id)
		marks[field + 2] = tostring(chip.label)
		marks[field + 3] = tostring(chip.tone or '')
		field = field + 3
	end
	marks[field + 1] = tostring(hidden)
	marks[field + 2] = tostring(anchor or '')
	marks[field + 3] = tostring(offset or '')

	effects = {
		chips = chips,
		hidden = hidden,
		anchor = anchor,
		offset = offset,
		signature = table.concat(marks, '\1'),
	}
	draw()
end)

--- @author DemiAutomatic
--- @event opx77:medic:stateChanged
--- @description Hides or restores the surface, never touching the player's choice.
--- @param payload {MedicStateChanged}
AddEventHandler(MEDIC_EVENT, function(payload)
	if type(payload) ~= 'table' then return end
	medicHeard = true
	setDown(payload.down == true)
end)

--- @author DemiAutomatic
--- @method unload
--- @description Drops the character and its needs, and redraws.
local function unload()
	State.data = nil
	State.SetNeeds(nil, false)
	draw()
end

--- @author DemiAutomatic
--- @event opx77:client:onPlayerUnloaded
--- @description Drops the character and its needs, and redraws.
AddEventHandler('opx77:client:onPlayerUnloaded', unload)

--- @author DemiAutomatic
--- @event opx77_hud:visibility
--- @description Applies the mode the server half resolved for the command.
--- @param mode {string} show, hide or toggle.
RegisterNetEvent('opx77_hud:visibility', function(mode)
	if mode == 'show' then
		Runtime.SetVisible(true)
	elseif mode == 'hide' then
		Runtime.SetVisible(false)
	elseif mode == 'toggle' then
		Runtime.SetVisible(not State.visible)
	end
end)

--- @author DemiAutomatic
--- @event opx77_hud:notice
--- @description Shows the command's refusal the server half already translated.
--- @param kind {string}
--- @param message {string}
RegisterNetEvent('opx77_hud:notice', function(kind, message)
	if type(message) ~= 'string' or message == '' then return end
	if kind ~= 'info' and kind ~= 'success' and kind ~= 'warning' and kind ~= 'error' then
		kind = 'info'
	end
	notify(kind, message)
end)

--- @author DemiAutomatic
--- @method OpxHud.Runtime.SetVisible
--- @description Shows or hides the surface, kept off screen while down.
--- @param value {boolean}
--- @returns {boolean}
function OpxHud.Runtime.SetVisible(value)
	local wanted = value ~= false
	if State.visible == wanted then return State.visible end
	State.visible = wanted
	draw(true)
	return State.visible
end

--- @author DemiAutomatic
--- @event onClientResourceStart
--- @description Registers the show and hide key mapping on this start.
--- @param name {string}
AddEventHandler('onClientResourceStart', function(name)
	if name ~= RESOURCE then return end
	local keys = Config.KEYS
	if keys ~= nil and type(keys) ~= 'table' then
		Open77.log.warn('config: KEYS must be a table; using the default key')
		keys = nil
	end
	keys = keys or {}
	Keys.Register(KEY_TOGGLE, 'hud.key.toggle', Keys.Setting('KEYS.TOGGLE', keys.TOGGLE, 'F8'),
		function() Runtime.SetVisible(not State.visible) end)
end)

--- @author DemiAutomatic
--- @event onClientResourceStart
--- @description Creates the surface, wires its channels and catches up once.
--- @param name {string}
AddEventHandler('onClientResourceStart', function(name)
	if name ~= RESOURCE then return end

	local reason
	page, reason = WebUI.create({
		entry = 'web/index.html',
		layer = 'hud',
		width = SURFACE_WIDTH,
		height = SURFACE_HEIGHT,
		fps = 30,
		zIndex = 705,
		transparent = true,
		visible = true,
	})
	if page == nil then
		Open77.log.error('WebUI surface failed: ' .. tostring(reason))
		return
	end

	page:on('hud:ready', function()
		pageReady = true
		if page == nil then return end
		send('hud:config', {
			anchor = Config.ANCHOR,
			infoAnchor = Config.INFO_ANCHOR,
			width = Config.WIDTH,
			segments = GAUGE_SEGMENTS,
		})
		draw(true)
	end)

	page:on('hud:diag', function(payload)
		if type(payload) ~= 'table' then return end
		Open77.log.info('page: ' .. tostring(payload.text or ''))
	end)

	CreateThread(function()
		pullDown()
		pullNeeds()
		pull()
		draw()
	end)
end)

--- @author DemiAutomatic
--- @event onClientResourceStop
--- @description Unloads on core stop, blanks needs, lifts down, forgets the page.
--- @param name {string}
AddEventHandler('onClientResourceStop', function(name)
	if name == CORE then return unload() end
	if name == MEDIC then return setDown(false) end
	if name == STATUS then
		State.SetNeeds(nil, false)
		draw()
		return
	end
	if name ~= RESOURCE then return end
	page, pageReady, drawn = nil, false, nil
end)
