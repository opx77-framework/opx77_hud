--- The server half: the chat command, which cannot be registered client-side.

local Config = OPX_HUD_CONFIG

local name = Config.COMMAND

if type(name) ~= "string" or name == "" then
  Open77.log.info("no command registered (OPX_HUD_CONFIG.COMMAND is off)")
  return
end

--- The scheduler clock in milliseconds; `monotonic` answers SECONDS. A non-finite reading is
--- dropped rather than propagated: a NaN would expire nothing, an infinity everything.
---
--- Holding the last reading is not a safe degradation: `lastSuggestedMs` is compared against
--- this clock, so a frozen one makes `atMs - previous` zero for anyone already suggested to,
--- which is below the floor -- no player would ever be sent the suggestion again, for the
--- rest of the process. `GetGameTimer` is the same scheduler clock, already in milliseconds.
---@return integer
local lastMs = 0
local clockWarned = false
local function nowMs()
  local read, seconds = pcall(Open77.time.monotonic)
  if read and type(seconds) == "number" and seconds == seconds and
    seconds >= 0 and seconds < math.huge then
    lastMs = math.floor(seconds * 1000)
    return lastMs
  end
  local ticked, ms = pcall(GetGameTimer)
  if ticked and type(ms) == "number" and ms == ms and ms >= 0 and ms < math.huge then
    if not clockWarned then
      clockWarned = true
      Open77.log.warn("Open77.time.monotonic unreadable; falling back to GetGameTimer")
    end
    lastMs = math.floor(ms)
  end
  return lastMs
end

--- `/<COMMAND> [on|off]`, omit the argument to toggle; answers the player who typed it.
--- Registered open: hiding your own HUD is not an operator action.
RegisterCommand(name, function(source, args, rawCommand)
  local player = tonumber(source) or 0
  if player <= 0 then
    Open77.log.info("/" .. name .. " is a player command")
    return
  end

  local wanted = args and args[1]
  local mode = "toggle"
  if wanted ~= nil then
    wanted = tostring(wanted):lower()
    if wanted == "on" or wanted == "show" then
      mode = "show"
    elseif wanted == "off" or wanted == "hide" then
      mode = "hide"
    else
      TriggerClientEvent("open77:command:result", player, rawCommand or "", false,
        locale("hud.usage", { command = "/" .. name }))
      return
    end
  end

  TriggerClientEvent("opx77_hud:visibility", player, mode)
end, false)

--- player -> when the suggestion was last sent them.
local lastSuggestedMs = {}

--- `chat:ready` is a net event and free for a client to send, so it is floored.
local SUGGEST_RATE_MS = 10000

RegisterNetEvent("chat:ready", function()
  local player = tonumber(source) or 0
  if player <= 0 then return end

  local atMs = nowMs()
  local previous = lastSuggestedMs[player]
  if previous ~= nil and atMs - previous < SUGGEST_RATE_MS then return end
  lastSuggestedMs[player] = atMs

  TriggerClientEvent("chat:addSuggestion", player, "/" .. name,
    locale("hud.commandHelp"),
    { { name = "on|off", help = locale("hud.commandArgument") } })
end)

--- Drop a departed player's rate-limit entry.
---
--- `source` is not populated for a host-fanned event, so the old `tonumber(source)` branch
--- was dead, and the `-1` behind it cleared a slot no player will ever hold. The event also
--- carries a `reason` now; a suggestion throttle has nothing to do with it.
---@param playerId any  a string, like every host event argument
local function forget(playerId)
  local player = tonumber(playerId)
  if player == nil then
    Open77.log.warn(("onPlayerDisconnected: unusable player id %q"):format(tostring(playerId)))
    return
  end
  lastSuggestedMs[player] = nil
end

-- the departure of an ADMITTED player. A connection refused at the door never reaches here;
-- that is `onPlayerRejected`, which this resource does not listen for.
AddEventHandler("onPlayerDisconnected", forget)
