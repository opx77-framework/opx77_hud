--- @author DemiAutomatic
--- @file shared/locale.lua
--- @description Locale catalogues and the global locale shorthand for player text.

OpxHud = OpxHud or {}

--- @author DemiAutomatic
--- @type {table<string, table<string, string>>}
--- @description Registered catalogues, by language code.
local catalogs = {}

--- @author DemiAutomatic
--- @type {string}
--- @description Language code player-facing text is read from.
local active = 'en'

--- @author DemiAutomatic
--- @type {string}
--- @description Language code a missing translation falls back to.
local FALLBACK = 'en'

OpxHud.Locale = {}
local Locale = OpxHud.Locale

--- @author DemiAutomatic
--- @method interpolate
--- @description Fills named placeholders, leaving unknown ones as written.
--- @param text {string}
--- @param params {table<string, string|number>|nil}
--- @returns {string}
local function interpolate(text, params)
	if not params then return text end
	return (text:gsub('{(%w+)}', function(name)
		local value = params[name]
		return value ~= nil and tostring(value) or ('{' .. name .. '}')
	end))
end

--- @author DemiAutomatic
--- @method OpxHud.Locale.register
--- @description Merges strings into the catalogue for one language code.
--- @param code {string}
--- @param strings {table<string, string>}
function OpxHud.Locale.register(code, strings)
	local catalog = catalogs[code]
	if not catalog then
		catalog = {}
		catalogs[code] = catalog
	end
	for key, text in pairs(strings) do catalog[key] = text end
end

--- @author DemiAutomatic
--- @method OpxHud.Locale.Set
--- @description Selects the catalogue player-facing text is read from.
--- @param code {string}
--- @returns {boolean}
function OpxHud.Locale.Set(code)
	if type(code) ~= 'string' or code == '' then return false end
	active = code
	return true
end

--- @author DemiAutomatic
--- @method OpxHud.Locale.Get
--- @description Answers translated text, falling back to English, then the key.
--- @param key {string}
--- @param params {table<string, string|number>|nil}
--- @returns {string}
function OpxHud.Locale.Get(key, params)
	local catalog = catalogs[active]
	local text = (catalog and catalog[key])
		or (catalogs[FALLBACK] and catalogs[FALLBACK][key])
		or key
	return interpolate(text, params)
end

--- @author DemiAutomatic
--- @type {fun(key: string, params: table|nil): string}
--- @description Global shorthand every file below the catalogues uses.
locale = OpxHud.Locale.Get

Locale.Set(OPX_HUD_CONFIG and OPX_HUD_CONFIG.LOCALE)
