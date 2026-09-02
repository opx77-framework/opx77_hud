--- The server half: the chat command, which cannot be registered client-side.

local Config = OPX_HUD_CONFIG

local name = Config.COMMAND

if type(name) ~= "string" or name == "" then
  Open77.log.info("no command registered (OPX_HUD_CONFIG.COMMAND is off)")
  return
end

--- Answers the player who typed it; `source` is the authenticated connection.
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
        "usage: " .. name .. " [on|off]")
      return
    end
  end

  TriggerClientEvent("opx77_hud:visibility", player, mode)
-- open to every player: hiding your own HUD is not an operator action
end, false)

-- floored: `chat:ready` is a net event, free for a client to send and answered every time
local lastSuggestedMs = {}

RegisterNetEvent("chat:ready", function()
  local player = tonumber(source) or 0
  if player <= 0 then return end

  local atMs = math.floor(Open77.time.monotonic() * 1000)
  local previous = lastSuggestedMs[player]
  if previous ~= nil and atMs - previous < 10000 then return end
  lastSuggestedMs[player] = atMs

  TriggerClientEvent("chat:addSuggestion", player, "/" .. name,
    "Show or hide your HUD", { { name = "on|off", help = "omit to toggle" } })
end)

--- The one departure event this platform raises. `playerDropped` occurs in the shipped
--- server binary only inside the platform's own embedded Lua bootstrap, which registers a
--- handler for a name no assembly ever emits, so a second handler here would be dead code
--- that made this cleanup look doubly covered.
---@param playerId number|string|nil
local function forget(playerId)
  lastSuggestedMs[tonumber(playerId) or tonumber(source) or -1] = nil
end

AddEventHandler("onPlayerDisconnected", forget)
