---@meta

OpxHud.Voice = {}

--- Number of segments the input meter is cut into, sent to the page in `hud:config`.
---@type integer
OpxHud.Voice.segments = 8

--- Whether `OPX_HUD_CONFIG.VOICE` is a table; false builds no indicator and leaves open-voice alone.
---@type boolean
OpxHud.Voice.enabled = true

--- Reads open-voice's `getState` and `getModes` and open77_voice's `getPushToTalkKey` once.
--- Must run inside a coroutine; a stopped or refusing resource leaves what was known.
function OpxHud.Voice.Pull() end

--- Raises `open-voice:setHudVisible`, so open-voice's own line is hidden while this indicator
--- stands in for it and given back on this resource's stop. Does nothing unless
--- `VOICE.HIDE_OPEN_VOICE` is on. Voice chat and the reach cycle are untouched.
---@param visible boolean
function OpxHud.Voice.SetOpenVoiceHud(visible) end

--- The indicator for the voice state right now, from `Open77.voice.status()` and the reach mode
--- open-voice last applied. Nil while disabled or on a client without the voice API.
---@return HudVoiceView|nil
function OpxHud.Voice.Sample() end

--- A string reduction of an indicator, so an unchanged one is not sent. A nil one answers "\0".
---@param view HudVoiceView|nil
---@return string
function OpxHud.Voice.Signature(view) end
