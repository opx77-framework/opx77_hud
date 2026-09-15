---@meta

OpxHud.Keys = {}

--- A configured key: a key name, or false for none. Anything else is the default, with a
--- warning naming the config path.
---@param path string how the warning names it, e.g. "KEYS.TOGGLE"
---@param value any
---@param default string
---@return string|false
function OpxHud.Keys.Setting(path, value, default) end

--- Declares one mapping with `RegisterKeyMapping`, so the pause menu lists it under the
--- localised name and a player can rebind it. A press while another surface holds the
--- keyboard does nothing. A refusal is one log line.
---@param id string namespaced and stable: a player's rebind is stored under it
---@param nameKey string catalogue key of the name the pause menu lists
---@param key string|false false registers nothing
---@param onPressed fun()
---@return boolean registered
function OpxHud.Keys.Register(id, nameKey, key, onPressed) end
