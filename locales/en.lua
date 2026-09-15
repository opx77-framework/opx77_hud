--- @author DemiAutomatic
--- @file locales/en.lua
--- @description English player-facing text for the HUD resource.

OpxHud.Locale.register('en', {
	['hud.title'] = 'HUD',
	['hud.usage'] = 'usage: {command} [on|off]',
	['hud.commandHelp'] = 'Show or hide your HUD',
	['hud.commandArgument'] = 'omit to toggle',
	['hud.key.toggle'] = 'HUD: show or hide',

	['hud.label.cred'] = 'CRED',

	['hud.voice.state.idle'] = 'MIC',
	['hud.voice.state.detected'] = 'MIC',
	['hud.voice.state.talking'] = 'TX',
	['hud.voice.state.muted'] = 'MUTED',
	['hud.voice.state.offline'] = 'OFFLINE',
	['hud.voice.mode.whisper'] = 'WHISPER',
	['hud.voice.mode.normal'] = 'NORMAL',
	['hud.voice.mode.shout'] = 'SHOUT',
	['hud.voice.mode.proximity'] = 'RANGE',
	['hud.voice.distance'] = '{metres} M',
	['hud.voice.open'] = 'OPEN',

	['hud.vehicle.unit'] = 'KM/H',
	['hud.vehicle.rpm'] = 'RPM',
	['hud.vehicle.integrity'] = 'INTEGRITY',
	['hud.vehicle.airborne'] = 'AIRBORNE',
})
