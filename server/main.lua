--- The server half: the chat command, which cannot be registered client-side.

local Config = OPX_HUD_CONFIG

local name = Config.COMMAND

if type(name) ~= "string" or name == "" then
  Open77.log.info("no command registered (OPX_HUD_CONFIG.COMMAND is off)")
  return
end

---@return integer
local function nowMs()
  return math.floor(Open77.time.monotonic() * 1000)
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
---@param playerId any
local function forget(playerId)
  lastSuggestedMs[tonumber(playerId) or tonumber(source) or -1] = nil
end

-- the only departure event this platform raises
AddEventHandler("onPlayerDisconnected", forget)
