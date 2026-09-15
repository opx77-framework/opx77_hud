--- @author DemiAutomatic
--- @file config.lua
--- @description Layout, command, key and game HUD settings for the player HUD.
--- @field LOCALE {string} Catalogue for player-facing text; en or fr.
--- @field ANCHOR {string} Gauge corner: bottom-left, bottom-right, top-left or top-right.
--- @field WIDTH {integer} Gauge block width in pixels on the 1920-wide surface.
--- @field INFO_ANCHOR {string} Money, job and cred corner; same four values as ANCHOR.
--- @field BLOCKS {string[]} Blocks built, in order; remove one to drop it.
--- @field NEEDS_THRESHOLD {integer|false} Hide need and cyber gauges above this percent; false always shows.
--- @field COMMAND {string|false} Chat command showing and hiding the HUD; false registers none.
--- @field NOTIFY {boolean} Refusal as an opx77_notify toast; false for a chat line.
--- @field KEYS {table} Default keys each player can rebind in the pause menu.
--- @field KEYS.TOGGLE {string|false} Show or hide key; false registers no mapping.
--- @field VANILLA {table<string, boolean>|false} Game HUD components: false hides, true shows.

OPX_HUD_CONFIG = {
	LOCALE = 'en',
	ANCHOR = 'bottom-left',
	WIDTH = 210,
	INFO_ANCHOR = 'top-right',
	BLOCKS = { 'vitals', 'cyber', 'needs', 'money', 'identity' },
	NEEDS_THRESHOLD = 90,
	COMMAND = 'hud',
	NOTIFY = true,
	KEYS = {
		TOGGLE = 'F8',
	},
	VANILLA = {
		minimap = false,
		compass = false,
		clock = false,
		health = false,
		stamina = false,
		weapon = false,
		speedometer = false,
	},
}
