--- The WebUI surface, and the link to opx77_core.

OpxHud = OpxHud or {}

local Config = OPX_HUD_CONFIG

--- How many blocks a gauge is cut into, how often the core is re-read as a net under its
--- change events, and how long a bar animates a change over. Cadence and visual detail, not
--- operator decisions.
local GAUGE_SEGMENTS = 10
local POLL_MS = 5000
local TWEEN_MS = 220
local State = OpxHud.state

local Runtime = {}
OpxHud.runtime = Runtime

local RESOURCE = GetCurrentResourceName()
local CORE = "opx77_core"

local page
local pageReady = false

--- The last signature sent to the page, so a change that moves nothing sends nothing.
local drawn = nil

local function nowMs()
  return math.floor(Open77.time.monotonic() * 1000)
end

local function sendConfig()
  if page == nil or not pageReady then return end
  page:send("hud:config", {
    anchor = Config.ANCHOR,
    infoAnchor = Config.INFO_ANCHOR,
    width = Config.WIDTH,
    tween = TWEEN_MS,
    segments = GAUGE_SEGMENTS,
  })
end

--- What opx77_status published last. It owns the effects; this surface draws them.
--- The most chips a publisher may put on screen at once.
local MAX_CHIPS = 12

local effects = { chips = {}, hidden = 0 }

--- Push a frame, or hide.
---@param force boolean|nil skip the signature test, for a page whose DOM is new
local function draw(force)
  if page == nil or not pageReady then return end
  local view = State.view()
  -- the effects join the signature: a chip appearing is a repaint even when no gauge moved
  local signature = State.signature(view) .. "\2" .. tostring(effects.signature or "")
  if not force and signature == drawn then return end
  drawn = signature
  if view == nil and #effects.chips == 0 then
    page:send("hud:hide", {})
    return
  end
  view = view or { rows = {}, info = {} }
  view.chips = effects.chips
  view.hidden = effects.hidden
  view.stripAnchor = effects.anchor
  view.stripOffset = effects.offset
  page:send("hud:frame", view)
end

--- One call to opx77_core. Coroutine only: `await` has no synchronous form.
---@param name string
---@return table|nil result
---@return string|nil reason
---@return boolean answered true when the core ran the export, so a refusal is authoritative
local function core(name, ...)
  if GetResourceState(CORE) ~= "running" then return nil, "core_not_running", false end
  local promise, reason = Open77.exports.call(CORE, name, ...)
  if not promise then return nil, tostring(reason or "not_dispatched"), false end
  local result, callError = promise:await()
  if callError then return nil, tostring(callError), false end
  if type(result) ~= "table" then return nil, "malformed_answer", true end
  if result.ok == false then return nil, tostring(result.error or "refused"), true end
  return result, nil, true
end

--- Adopt whatever the core last knew. Coroutine only.
---@return boolean ok
---@return string|nil reason
local function pull()
  local result, reason, answered = core("GetPlayerData")
  if result == nil then
    -- only a refusal clears the HUD: a call that never landed says nothing about the character
    if answered then State.data = nil end
    return false, reason
  end
  State.data = result.data
  return true
end

AddEventHandler("opx77:client:playerLoaded", function(playerData)
  if type(playerData) ~= "table" then return end
  State.data = playerData
  draw()
end)

AddEventHandler("opx77:client:playerDataChanged", function(playerData)
  if type(playerData) ~= "table" then return end
  State.data = playerData
  draw()
end)

--- The payload is carried into the next frame rather than sent on its own, so the page never
--- has two sources deciding when it repaints.
AddEventHandler("opx77:status:effects", function(payload)
  if type(payload) ~= "table" then return end
  -- bounded: any resource on this machine can raise this name, and the page keeps one
  -- element per unique chip id forever
  local chips = {}
  if type(payload.chips) == "table" then
    for index, chip in ipairs(payload.chips) do
      if index > MAX_CHIPS then break end
      if type(chip) == "table" and chip.id ~= nil then chips[#chips + 1] = chip end
    end
  end
  local marks = {}
  for _, chip in ipairs(chips) do
    marks[#marks + 1] = tostring(chip.id) .. "\1" .. tostring(chip.label) .. "\1" ..
      tostring(chip.tone or "")
  end
  effects = {
    chips = chips,
    hidden = tonumber(payload.hidden) or 0,
    anchor = payload.anchor,
    offset = payload.offset,
    signature = table.concat(marks, "\3") .. "\4" .. tostring(payload.hidden or 0),
  }
  draw()
end)

AddEventHandler("opx77:client:playerUnloaded", function()
  State.data = nil
  draw()
end)

--- The answer to `/hud`, from this resource's own server half.
---@param mode string "show" | "hide" | "toggle"
RegisterNetEvent("opx77_hud:visibility", function(mode)
  if mode == "show" then
    Runtime.setVisible(true)
  elseif mode == "hide" then
    Runtime.setVisible(false)
  elseif mode == "toggle" then
    Runtime.setVisible(not State.visible)
  end
end)

---@param value boolean
---@return boolean visible
function Runtime.setVisible(value)
  local wanted = value ~= false
  if State.visible == wanted then return State.visible end
  State.visible = wanted
  draw()
  return State.visible
end

---@return boolean visible
function Runtime.isVisible()
  return State.visible
end

--- Queue a re-read of the character; the frame follows a moment later.
function Runtime.refresh()
  CreateThread(function()
    pull()
    draw()
  end)
end

--- Whether the HUD is showing, whether a character is loaded, and how many rows that came to.
---@return table
function Runtime.snapshot()
  local view = State.view()
  return {
    visible = State.visible,
    loaded = State.data ~= nil,
    rows = view and #view.rows or 0,
  }
end

AddEventHandler("onClientResourceStart", function(name)
  if name ~= RESOURCE then return end

  local reason
  page, reason = WebUI.create({
    entry = "web/index.html",
    layer = "hud",
    width = 1920,
    height = 1080,
    fps = 30,
    zIndex = 705,
    transparent = true,
    -- created visible: a surface created hidden never uploads a frame once shown
    visible = true,
  })
  if page == nil then
    Open77.log.error("WebUI surface failed: " .. tostring(reason))
    return
  end

  page:on("hud:ready", function()
    pageReady = true
    sendConfig()
    -- forced: the page is new, so `drawn` describes a DOM that no longer exists
    draw(true)
  end)

  page:on("hud:diag", function(payload)
    if type(payload) ~= "table" then return end
    Open77.log.info("page: " .. tostring(payload.text or ""))
  end)

  CreateThread(function()
    local nextPullAtMs = 0
    while page ~= nil do
      local atMs = nowMs()
      if atMs >= nextPullAtMs then
        nextPullAtMs = atMs + POLL_MS
        pull()
        draw()
      end
      Wait(500)
    end
  end)
end)

AddEventHandler("onClientResourceStop", function(name)
  if name ~= RESOURCE then return end
  page, pageReady, drawn = nil, false, nil
end)
