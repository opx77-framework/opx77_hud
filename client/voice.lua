--- @author DemiAutomatic
--- @file client/voice.lua
--- @description The microphone indicator: native voice state, open-voice reach modes, and the open-voice line it replaces.

local Config = OPX_HUD_CONFIG

OpxHud.Voice = {}
local Voice = OpxHud.Voice

local finite = OpxHud.State.Finite

--- @author DemiAutomatic
--- @type {string}
--- @description This resource's own name, for its lifecycle events.
local RESOURCE = GetCurrentResourceName()

--- @author DemiAutomatic
--- @type {string}
--- @description Open77's reach-mode companion, which owns whisper, normal and shout and draws its own line.
local OPEN_VOICE = 'open-voice'

--- @author DemiAutomatic
--- @type {string}
--- @description Open77's voice driver, which owns capture, push-to-talk and its key.
local VOICE_DRIVER = 'open77_voice'

--- @author DemiAutomatic
--- @type {number}
--- @description Input level above which the microphone reads as picking up a voice.
local DETECT_LEVEL = 0.025

--- @author DemiAutomatic
--- @type {integer}
--- @description Longest key name kept from another resource.
local MAX_KEY = 12

--- @author DemiAutomatic
--- @type {integer}
--- @description Most reach modes kept from open-voice, as many as it accepts itself.
local MAX_MODES = 8

--- @author DemiAutomatic
--- @type {integer}
--- @description Number of segments the input meter is cut into.
OpxHud.Voice.segments = 8

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether a voice table is configured at all; false builds no indicator.
OpxHud.Voice.enabled = type(Config.VOICE) == 'table'

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether the open-voice line is hidden while this indicator stands in for it.
local HIDE_OPEN_VOICE = Voice.enabled and Config.VOICE.HIDE_OPEN_VOICE ~= false

--- @author DemiAutomatic
--- @type {table}
--- @description The reach mode open-voice last applied: name, label and distance, each possibly nil.
local reach = {}

--- @author DemiAutomatic
--- @type {string[]}
--- @description Reach mode names in open-voice's cycling order.
local modes = {}

--- @author DemiAutomatic
--- @type {string|nil}
--- @description Key open-voice cycles the reach with, nil without it.
local cycleKey = nil

--- @author DemiAutomatic
--- @type {string|nil}
--- @description Push-to-talk key open77_voice samples, nil until it answered.
local pushToTalkKey = nil

--- @author DemiAutomatic
--- @method keyName
--- @description Answers a short key name in capitals, or nil.
--- @param value {any}
--- @returns {string|nil}
local function keyName(value)
	if type(value) ~= 'string' or value == '' or #value > MAX_KEY or value:find('[%s%c]') then
		return nil
	end
	return value:upper()
end

--- @author DemiAutomatic
--- @method setReach
--- @description Adopts one reach mode as open-voice reported it.
--- @param name {any}
--- @param distance {any}
--- @param label {any}
local function setReach(name, distance, label)
	if type(name) ~= 'string' or name == '' or #name > 24 then return end
	reach = {
		name = name:lower(),
		label = type(label) == 'string' and label:sub(1, 32) or nil,
		distance = finite(distance) and distance > 0 and distance or nil,
	}
end

--- @author DemiAutomatic
--- @method adoptModes
--- @description Keeps the reach mode names of an open-voice getModes answer, in order.
--- @param list {table}
local function adoptModes(list)
	local names = {}
	for index = 1, math.min(#list, MAX_MODES) do
		local mode = list[index]
		if type(mode) ~= 'table' or type(mode.name) ~= 'string' then return end
		names[index] = mode.name:lower()
	end
	modes = names
end

--- @author DemiAutomatic
--- @method ask
--- @description Calls another resource's export from a coroutine, answering its raw result or nil.
--- @param resource {string}
--- @param name {string}
--- @returns {any}
local function ask(resource, name)
	if GetResourceState(resource) ~= 'running' then return nil end
	local called, promise = pcall(Open77.exports.call, resource, name)
	if not called or not promise then return nil end
	local result, callError = promise:await()
	if callError then return nil end
	return result
end

--- @author DemiAutomatic
--- @method OpxHud.Voice.Pull
--- @description Reads the reach mode, its cycle and the push-to-talk key once, from a coroutine.
function OpxHud.Voice.Pull()
	if not Voice.enabled then return end
	local state = ask(OPEN_VOICE, 'getState')
	if type(state) == 'table' and state.configured == true then
		setReach(state.mode, state.distance, state.label)
		cycleKey = keyName(state.cycleKey)
	end
	local list = ask(OPEN_VOICE, 'getModes')
	if type(list) == 'table' then adoptModes(list) end
	local key = keyName(ask(VOICE_DRIVER, 'getPushToTalkKey'))
	if key ~= nil then pushToTalkKey = key end
end

--- @author DemiAutomatic
--- @method OpxHud.Voice.SetOpenVoiceHud
--- @description Shows or hides the open-voice line, when configured to stand in for it.
--- @param visible {boolean}
function OpxHud.Voice.SetOpenVoiceHud(visible)
	if not HIDE_OPEN_VOICE then return end
	pcall(TriggerEvent, 'open-voice:setHudVisible', visible == true)
	if GetResourceState(OPEN_VOICE) ~= 'running' then return end
	pcall(Open77.exports.call, OPEN_VOICE, 'setHudVisible', visible == true)
end

--- @author DemiAutomatic
--- @method formatDistance
--- @description Formats a reach in metres: one decimal under ten when fractional, whole otherwise.
--- @param metres {number}
--- @returns {string}
local function formatDistance(metres)
	if metres < 10 and metres ~= math.floor(metres) then return ('%.1f'):format(metres) end
	return tostring(math.floor(metres + 0.5))
end

--- @author DemiAutomatic
--- @method modeLabel
--- @description Answers the translated reach mode name, open-voice's own label, or the proximity word.
--- @returns {string}
local function modeLabel()
	if reach.name == nil then return locale('hud.voice.mode.proximity') end
	local key = 'hud.voice.mode.' .. reach.name
	local text = locale(key)
	if text ~= key then return text end
	return reach.label or reach.name:upper()
end

--- @author DemiAutomatic
--- @method stateOf
--- @description Answers the indicator state a native voice status reads as, and its input level.
--- @param status {table|nil}
--- @returns {HudVoiceState, number}
local function stateOf(status)
	if status == nil then return 'offline', 0 end
	local level = status.inputLevel
	if not finite(level) then level = status.microphoneActivity end
	if not finite(level) or level < 0 then level = 0 end
	if level > 1 then level = 1 end
	if status.available ~= true then return 'offline', 0 end
	if status.captureEnabled ~= true then return 'muted', 0 end
	if status.transmitting == true then return 'talking', level end
	if status.localTalking == true or level > DETECT_LEVEL then return 'detected', level end
	return 'idle', level
end

--- @author DemiAutomatic
--- @method OpxHud.Voice.Sample
--- @description Answers the indicator for the voice state right now, or nil without a voice API.
--- @returns {HudVoiceView|nil}
function OpxHud.Voice.Sample()
	if not Voice.enabled then return nil end
	local api = Open77.voice
	if type(api) ~= 'table' or type(api.status) ~= 'function' then return nil end
	local read, status = pcall(api.status)
	if not read or type(status) ~= 'table' then status = nil end

	local state, level = stateOf(status)

	local metres = reach.distance
	if metres == nil and status ~= nil then
		if finite(status.proximityDistance) and status.proximityDistance > 0 then
			metres = status.proximityDistance
		elseif finite(status.defaultProximityDistance) and status.defaultProximityDistance > 0 then
			metres = status.defaultProximityDistance
		end
	end

	local index = nil
	if reach.name ~= nil then
		for position = 1, #modes do
			if modes[position] == reach.name then index = position end
		end
	end

	local activation = pushToTalkKey
	if status ~= nil and status.voiceActivation == true then activation = locale('hud.voice.open') end

	local heard = 0
	if status ~= nil and finite(status.activeTalkers) and status.activeTalkers > 0 then
		heard = math.min(99, math.floor(status.activeTalkers))
	end

	return {
		state = state,
		caption = locale('hud.voice.state.' .. state),
		lit = math.floor(level * Voice.segments + 0.5),
		mode = modeLabel(),
		distance = metres ~= nil and locale('hud.voice.distance', { metres = formatDistance(metres) }) or nil,
		index = index,
		count = index ~= nil and #modes or nil,
		key = cycleKey,
		activation = activation,
		heard = heard,
	}
end

--- @author DemiAutomatic
--- @method OpxHud.Voice.Signature
--- @description Reduces an indicator to a string, so an unchanged one is not sent.
--- @param view {HudVoiceView|nil}
--- @returns {string}
function OpxHud.Voice.Signature(view)
	if view == nil then return '\0' end
	return table.concat({
		view.state, view.caption, tostring(view.lit), view.mode, view.distance or '',
		tostring(view.index or ''), tostring(view.count or ''), view.key or '',
		view.activation or '', tostring(view.heard),
	}, '\1')
end

--- @author DemiAutomatic
--- @event open-voice:modeChanged
--- @description Adopts the reach mode open-voice applied, reading its mode list if still unknown.
--- @param mode {string}
--- @param distance {number}
--- @param label {string}
AddEventHandler('open-voice:modeChanged', function(mode, distance, label)
	if not Voice.enabled then return end
	setReach(mode, distance, label)
	if #modes > 0 then return end
	CreateThread(function()
		local list = ask(OPEN_VOICE, 'getModes')
		if type(list) == 'table' then adoptModes(list) end
		local state = ask(OPEN_VOICE, 'getState')
		if type(state) == 'table' then cycleKey = keyName(state.cycleKey) or cycleKey end
	end)
end)

--- @author DemiAutomatic
--- @event open77:voice:pushToTalkKeyChanged
--- @description Adopts the push-to-talk key open77_voice switched to.
--- @param key {string}
AddEventHandler('open77:voice:pushToTalkKeyChanged', function(key)
	local name = keyName(key)
	if name ~= nil then pushToTalkKey = name end
end)

--- @author DemiAutomatic
--- @event onClientResourceStart
--- @description Hides the open-voice line and reads the voice links, on this start or theirs.
--- @param name {string}
AddEventHandler('onClientResourceStart', function(name)
	if not Voice.enabled then return end
	if name ~= RESOURCE and name ~= OPEN_VOICE and name ~= VOICE_DRIVER then return end
	if name ~= VOICE_DRIVER then
		Voice.SetOpenVoiceHud(false)
		-- Again once open-voice has had time to build its page, which may ignore an early hide.
		CreateThread(function()
			for _ = 1, 3 do
				Wait(3000)
				Voice.SetOpenVoiceHud(false)
			end
		end)
	end
	CreateThread(Voice.Pull)
end)

--- @author DemiAutomatic
--- @event onClientResourceStop
--- @description Gives the open-voice line back on this stop, and forgets a stopped voice link.
--- @param name {string}
AddEventHandler('onClientResourceStop', function(name)
	if not Voice.enabled then return end
	if name == RESOURCE then
		Voice.SetOpenVoiceHud(true)
	elseif name == OPEN_VOICE then
		reach, modes, cycleKey = {}, {}, nil
	elseif name == VOICE_DRIVER then
		pushToTalkKey = nil
	end
end)
