--- opx77_hud -- the vanilla Cyberpunk HUD.
---
--- This resource draws its own gauges, its own money and job corner, and hosts opx77_status's
--- chip strip. Left alone, the game's own HUD keeps drawing underneath all of it: two health
--- bars, two clocks, two minimaps. So the resource that replaces the vanilla HUD is also the
--- resource that turns it off.
---
--- The switch is `Open77.hud`, and it is newer than every other API this framework touches:
--- it is absent from the published API reference and from `resource-runtime.md`'s capability
--- table, so nothing here can be checked against a document the way the rest of this
--- repository is. Every call is therefore made defensively -- the table is probed before it
--- is used, the component names are checked against what the client itself reports, and a
--- client that predates the API is a logged line rather than a script error. Two things
--- follow from that and are worth stating plainly rather than discovering later:
---
---   * the effect is presentation on this client only, like the rest of the `ui.vanilla`
---     family, so nothing here is authoritative and nothing is worth trusting on the server;
---   * whether the platform restores these components by itself when a resource stops is
---     undocumented and untested. This file does not rely on either answer: it records what
---     it found before it changed anything and puts it back on the way out.

OpxHud = OpxHud or {}

local Config = OPX_HUD_CONFIG

local Vanilla = {}
OpxHud.vanilla = Vanilla

local RESOURCE = GetCurrentResourceName()

--- What we found before touching anything: component -> the visibility it had. Restored on
--- stop, so an operator who removes this resource gets the game's HUD back without a
--- reconnect. `nil` until `apply` has run once.
---@type table<string, boolean>|nil
local found = nil

--- Resolved on each entry rather than cached at file scope: this file loads before the
--- session is up, and a table that does not exist yet at load time would be cached as absent
--- for the life of the resource.
---@return table|nil
local function api()
  if type(Open77) ~= "table" then return nil end
  local hud = Open77.hud
  if type(hud) ~= "table" then return nil end
  if type(hud.setVisible) ~= "function" then return nil end
  return hud
end

--- The component names this client actually recognises, as a set. `components()` is the only
--- honest source: the seven names this framework knows about are the ones that existed when
--- it was written, and a client that adds an eighth should not need a release here to hide it.
--- A client that cannot answer gets `nil`, and then nothing is validated and every configured
--- name is attempted -- which is the same position we would be in without the getter at all.
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

--- The visibility a component has right now, or `nil` when the client will not say. Asked one
--- component at a time through `isVisible` rather than in one `state()` call, because `state`
--- keys its answer however it likes and a name we failed to find there is indistinguishable
--- from a component that is genuinely hidden -- and this value decides what we restore.
---@param hud table
---@param component string
---@return boolean|nil
local function visibility(hud, component)
  if type(hud.isVisible) ~= "function" then return nil end
  local ok, value = pcall(hud.isVisible, component)
  if not ok or type(value) ~= "boolean" then return nil end
  return value
end

--- Apply `Config.VANILLA`. Safe to call repeatedly: the components the game restores by
--- itself at incarnation are set again, and the record of what was found is written once.
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

--- Put back what was found. Only components whose prior visibility the client actually
--- reported are touched: guessing `true` for the rest would turn on a component the player's
--- own settings had off.
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

--- What this file did, for `/hud` and for anyone debugging a HUD that will not go away.
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

--- The game brings its own HUD back at incarnation, which lands after this resource started.
--- Re-asserting on the core's loaded event costs seven calls at the one moment it is needed,
--- which is cheaper and quieter than a thread that keeps checking forever.
AddEventHandler("opx77:client:onPlayerLoaded", function()
  Vanilla.apply()
end)

AddEventHandler("onClientResourceStop", function(name)
  if name ~= RESOURCE then return end
  Vanilla.restore()
end)
