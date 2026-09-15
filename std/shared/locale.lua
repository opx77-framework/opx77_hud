---@meta

OpxHud = {}

OpxHud.Locale = {}

--- Merges a language's strings into its catalogue. Later registrations of the same key win.
--- Operators' own `locales/<code>.lua` files call it, so it keeps its lowercase name.
---@param code string a language code such as "en"
---@param strings table<string, string> key -> text, with {placeholders}
function OpxHud.Locale.register(code, strings) end

--- Selects the catalogue player-facing text is read from. An unknown code is accepted and
--- falls back, because the catalogues register after this file loads.
---@param code string
---@return boolean applied false for anything but a non-empty string
function OpxHud.Locale.Set(code) end

--- The language code currently selected.
---@return string
function OpxHud.Locale.Current() end

--- Whether the active catalogue, or the `en` fallback, defines a key.
---@param key string
---@return boolean
function OpxHud.Locale.Exists(key) end

--- The translated text with `{name}` placeholders filled. Never nil: a missing translation
--- falls back to `en` and then to the key itself; a placeholder with no value stays as written.
---@param key string
---@param params table<string, string|number>|nil
---@return string
function OpxHud.Locale.Get(key, params) end

--- The shorthand every file below the catalogues uses.
---@type fun(key: string, params?: table<string, string|number>): string
locale = OpxHud.Locale.Get
