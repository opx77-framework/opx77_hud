--- The game's own HUD, hidden through `Open77.hud` so it is not drawn under this one.

OpxHud = OpxHud or {}

local Config = OPX_HUD_CONFIG

local Vanilla = {}
OpxHud.vanilla = Vanilla

local RESOURCE = GetCurrentResourceName()

--- Component -> the visibility it had before this file touched it; nil until `apply` has run.
---@type table<string, boolean>|nil
local found = nil

--- `Open77.hud`, resolved on each entry: this file loads before the session is up.
---@return table|nil
local function api()
  if type(Open77) ~= "table" then return nil end
  local hud = Open77.hud
  if type(hud) ~= "table" then return nil end
  if type(hud.setVisible) ~= "function" then return nil end
  return hud
end

--- The component names this client recognises, or nil when it will not say and nothing
--- is validated.
---@param hud table
---@return table<string, boolean>|nil
local function known(hud)
  if type(hud.components) ~= "function" then return nil end
  local ok, list = pcall(hud.components)
  if not ok or type(list) ~= "table" then return nil end
  local set = {}
  for index = 1, #list do
    local name = list[index]
    if type(name) == "string" then set[name] = true end
  end
  -- an empty answer is not a claim that there are no components; treat it as no answer
  if next(set) == nil then return nil end
  return set
end

--- The visibility a component has right now, or nil when the client will not say.
---@param hud table
---@param component string
---@return boolean|nil
local function visibility(hud, component)
  if type(hud.isVisible) ~= "function" then return nil end
  local ok, value = pcall(hud.isVisible, component)
  if not ok or type(value) ~= "boolean" then return nil end
  return value
end

--- Apply `Config.VANILLA`. Safe to call repeatedly; the record of what was found is kept once.
---@return integer applied
---@return string|nil reason when nothing could be applied at all
function Vanilla.apply()
  local wanted = Config.VANILLA
  if wanted == false or wanted == nil then return 0 end
  if type(wanted) ~= "table" then return 0, "config_not_a_table" end

  local hud = api()
  if hud == nil then return 0, "api_absent" end

  local set = known(hud)
  local first = found == nil
  if first then found = {} end

  local applied = 0
  for component, visible in pairs(wanted) do
    if type(component) ~= "string" or type(visible) ~= "boolean" then
      Open77.log.warn(("vanilla: ignoring %s -- a component name maps to true or false")
        :format(tostring(component)))
    elseif set ~= nil and not set[component] then
      Open77.log.warn(("vanilla: this client has no component named %q"):format(component))
    else
      if first then found[component] = visibility(hud, component) end
      local ok, reason = pcall(hud.setVisible, component, visible)
      if ok then
        applied = applied + 1
      else
        Open77.log.warn(("vanilla: %s could not be set -- %s"):format(component, tostring(reason)))
      end
    end
  end

  return applied
end

--- Put back what was found. Only components whose prior visibility the client reported.
---@return integer restored
function Vanilla.restore()
  if found == nil then return 0 end

  local hud = api()
  if hud == nil then return 0 end

  local restored = 0
  for component, visible in pairs(found) do
    if type(visible) == "boolean" and pcall(hud.setVisible, component, visible) then
      restored = restored + 1
    end
  end

  found = nil
  return restored
end

--- What this file did, for anyone debugging a HUD that will not go away.
---@return table
function Vanilla.snapshot()
  local hud = api()
  local live = nil
  if hud ~= nil and type(hud.state) == "function" then
    local ok, value = pcall(hud.state)
    if ok and type(value) == "table" then live = value end
  end
  return { available = hud ~= nil, found = found, state = live }
end

AddEventHandler("onClientResourceStart", function(name)
  if name ~= RESOURCE then return end

  local applied, reason = Vanilla.apply()
  if reason == "api_absent" then
    Open77.log.warn("vanilla: Open77.hud is missing on this client, so the game's own HUD")
    Open77.log.warn("  stays on screen underneath this one. It arrived with the ui.vanilla.hud")
    Open77.log.warn("  capability; a client older than that cannot hide it. Update, or set")
    Open77.log.warn("  VANILLA = false in config.lua to stop this warning.")
  elseif applied > 0 then
    Open77.log.info(("vanilla: %d component%s set"):format(applied, applied == 1 and "" or "s"))
  end
end)

-- the game brings its own HUD back at incarnation, which lands after this resource started
AddEventHandler("opx77:client:onPlayerLoaded", function()
  Vanilla.apply()
end)

AddEventHandler("onClientResourceStop", function(name)
  if name ~= RESOURCE then return end
  Vanilla.restore()
end)
