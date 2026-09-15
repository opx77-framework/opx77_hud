--- The rebindable key. It is declared to the host with RegisterKeyMapping, so the pause menu's
--- keybinds tab lists it under the localised name given here and a player rebinds it there.
--- Nothing here reads a key itself.

OpxHud = OpxHud or {}

OpxHud.Keys = {}
local Keys = OpxHud.Keys

--- A configured key: a key name, or false for none. Anything else is the default, said once.
---@param path string  how the warning names it, e.g. "KEYS.TOGGLE"
---@param value any
---@param default string
---@return string|false
function OpxHud.Keys.Setting(path, value, default)
	if value == false then return false end
	if value == nil then return default end
	if type(value) == 'string' and #value > 0 and #value <= 32 and not value:find('[%s%c]') then
		return value
	end
	Open77.log.warn(('config: %s must be a key name or false; using %q'):format(path, default))
	return default
end

--- Whether another surface holds the keyboard: chat's composer, an opx77_input form, the pause
--- menu. A key typed into one of them must not act behind it.
---@return boolean
local function captured()
	local input = type(Open77) == 'table' and Open77.input or nil
	if type(input) ~= 'table' or type(input.isCaptured) ~= 'function' then return false end
	local read, answer = pcall(input.isCaptured)
	return read and answer == true
end

--- Declare one mapping. A refusal is one log line; the command it stands for still works.
---@param id string       namespaced by this resource, and stable: a rebind is stored under it
---@param nameKey string  catalogue key of the name the pause menu lists
---@param key string|false
---@param onPressed fun()
---@return boolean registered
function OpxHud.Keys.Register(id, nameKey, key, onPressed)
	if key == false then return false end
	if type(RegisterKeyMapping) ~= 'function' then
		Open77.log.warn(('key mapping %s not registered: this client build has no ' ..
			'RegisterKeyMapping'):format(id))
		return false
	end
	local function pressed()
		if captured() then return end
		local ran, failure = pcall(onPressed)
		if not ran then Open77.log.error(('key %s: %s'):format(id, tostring(failure))) end
	end
	-- two documented shapes: the key guide answers `true, key`, the API reference the key alone;
	-- either one is a registration, and `false|nil, reason` is a refusal
	local called, ok, answer = pcall(RegisterKeyMapping, id, locale(nameKey), key, pressed)
	local effective = type(ok) == 'string' and ok ~= '' and ok or
		(ok == true and type(answer) == 'string' and answer ~= '' and answer) or nil
	if not called or (ok ~= true and effective == nil) then
		Open77.log.warn(('key mapping %s (%s) not registered: %s'):format(id, key,
			tostring(called and answer or ok)))
		return false
	end
	return true
end
