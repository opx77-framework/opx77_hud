--- The WebUI surface, and the links to opx77_core and opx77_status.

OpxHud = OpxHud or {}

local Config = OPX_HUD_CONFIG

--- Segments per gauge, and the re-read interval under the core's change events.
local GAUGE_SEGMENTS = 10
local POLL_MS = 5000

--- The surface the page is drawn on; a published strip offset is bounded by its height.
local SURFACE_WIDTH = 1920
local SURFACE_HEIGHT = 1080

local State = OpxHud.state
local finite = State.finite

local Runtime = {}
OpxHud.runtime = Runtime

local RESOURCE = GetCurrentResourceName()
local CORE = "opx77_core"
local STATUS = "opx77_status"

--- What opx77_status publishes; a satellite cannot read another resource's config.
local NEEDS_EVENT = "opx77:status:needs"
local EFFECTS_EVENT = "opx77:status:effects"

local page
local pageReady = false

--- The last signature sent to the page, so a change that moves nothing sends nothing.
local drawn = nil

---@return integer
local function nowMs()
  return math.floor(Open77.time.monotonic() * 1000)
end

--- Post one message to the page. Every caller is a forever-thread or an event handler, so a
--- raise from the host is logged rather than ending it.
---@param name string
---@param payload table
---@return boolean sent
local function send(name, payload)
  local ok, reason = pcall(page.send, page, name, payload)
  if not ok then Open77.log.error("page " .. name .. ": " .. tostring(reason)) end
  return ok
end

local function sendConfig()
  if page == nil or not pageReady then return end
  send("hud:config", {
    anchor = Config.ANCHOR,
    infoAnchor = Config.INFO_ANCHOR,
    width = Config.WIDTH,
    segments = GAUGE_SEGMENTS,
  })
end

--- The most chips a publisher may put on screen at once, and the largest "+N" past them
--- that still reads as a number.
local MAX_CHIPS = 12
local MAX_HIDDEN = 999

local effects = { chips = {}, hidden = 0, signature = "" }

--- Push a frame, or hide.
---@param force boolean|nil skip the signature test, for a page whose DOM is new
local function draw(force)
  if page == nil or not pageReady then return end
  local view = State.view()
  -- the effects join the signature: a chip appearing is a repaint even when no gauge moved
  local signature = State.signature(view) .. "\2" .. effects.signature
  if not force and signature == drawn then return end
  local sent
  -- the whole surface is one element's `open` class, chip strip included, so hiding is
  -- decided on State.visible rather than on the view
  if not State.visible or (view == nil and #effects.chips == 0) then
    sent = send("hud:hide", {})
  else
    view = view or { rows = {} }
    view.chips = effects.chips
    view.hidden = effects.hidden
    view.stripAnchor = effects.anchor
    view.stripOffset = effects.offset
    sent = send("hud:frame", view)
  end
  -- a message that did not land leaves the page drawing an older frame
  drawn = sent and signature or nil
end

--- One export call. Coroutine only: `await` has no synchronous form.
---@param resource string
---@param name string
---@return table|nil result
---@return string|nil reason
---@return boolean answered true when the resource ran the export, so a refusal is authoritative
local function call(resource, name, ...)
  if GetResourceState(resource) ~= "running" then return nil, "not_running", false end
  local promise, reason = Open77.exports.call(resource, name, ...)
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
  local result, reason, answered = call(CORE, "GetPlayerData")
  if result == nil then
    -- only a refusal clears the HUD: a call that never landed says nothing about the character
    if answered then State.data = nil end
    return false, reason
  end
  State.data = result.data
  return true
end

--- Catch up on the needs opx77_status holds. Every later change arrives on NEEDS_EVENT,
--- so this runs once rather than on a timer. Coroutine only.
---@return boolean ok
local function pullNeeds()
  local result, _, answered = call(STATUS, "needs")
  if result == nil then
    -- a refusal is authoritative: no character, or the status server has not answered yet
    if answered then State.setNeeds(nil, false) end
    return false
  end
  State.setNeeds(result.values, result.ready == true)
  return true
end

--- When the core is next re-read, on the client clock.
local nextPullAtMs = 0

--- One turn of the boot loop. Coroutine only, and always called through `pcall`: a raise from
--- a host call here would end the loop for the session.
local function tick()
  local atMs = nowMs()
  if atMs < nextPullAtMs then return end
  nextPullAtMs = atMs + POLL_MS
  pull()
  draw()
end

AddEventHandler("opx77:client:onPlayerLoaded", function(playerData)
  if type(playerData) ~= "table" then return end
  State.data = playerData
  draw()
end)

AddEventHandler("opx77:client:playerDataChanged", function(playerData)
  if type(playerData) ~= "table" then return end
  State.data = playerData
  draw()
end)

--- The needs opx77_status owns. It pushes; nothing here polls them.
AddEventHandler(NEEDS_EVENT, function(payload)
  if type(payload) ~= "table" then return end
  State.setNeeds(payload.values, payload.ready == true)
  draw()
end)

--- The count of effects past the strip's cut, as the page can draw it. NaN, infinity and a
--- negative all read as none.
---@param value any
---@return integer
local function hiddenCount(value)
  local number = tonumber(value)
  if not finite(number) or number <= 0 then return 0 end
  if number > MAX_HIDDEN then return MAX_HIDDEN end
  return math.floor(number)
end

--- The corner the strip is placed in, or nil to leave it in the HUD's own.
---@param value any
---@return string|nil
local function anchorOf(value)
  if type(value) ~= "string" or #value > 32 then return nil end
  return value
end

--- Pixels the strip sits above the corner, or nil for the page's own placement.
---@param value any
---@return number|nil
local function offsetOf(value)
  local number = tonumber(value)
  if not finite(number) or number < 0 or number > SURFACE_HEIGHT then return nil end
  return number
end

--- Status chips from opx77_status, carried into the next frame rather than sent on their own.
AddEventHandler(EFFECTS_EVENT, function(payload)
  if type(payload) ~= "table" then return end
  -- bounded: any resource can raise this name, and the page keeps one element per chip id
  local chips = {}
  local kept = 0
  local offered = payload.chips
  if type(offered) == "table" then
    local count = #offered
    if count > MAX_CHIPS then count = MAX_CHIPS end
    for index = 1, count do
      local chip = offered[index]
      if type(chip) == "table" and chip.id ~= nil then
        kept = kept + 1
        chips[kept] = chip
      end
    end
  end

  local hidden = hiddenCount(payload.hidden)
  local anchor = anchorOf(payload.anchor)
  local offset = offsetOf(payload.offset)

  local marks = {}
  for index = 1, kept do
    local chip = chips[index]
    marks[index] = tostring(chip.id) .. "\1" .. tostring(chip.label) .. "\1" ..
      tostring(chip.tone or "")
  end
  -- signed on the values the frame carries, never on the raw payload
  effects = {
    chips = chips,
    hidden = hidden,
    anchor = anchor,
    offset = offset,
    signature = table.concat(marks, "\3") .. "\4" .. tostring(hidden) .. "\4" ..
      tostring(anchor or "") .. "\4" .. tostring(offset or ""),
  }
  draw()
end)

AddEventHandler("opx77:client:onPlayerUnloaded", function()
  State.data = nil
  State.setNeeds(nil, false)
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

--- Shows or hides the HUD.
---@param value boolean
---@return boolean visible
function Runtime.setVisible(value)
  local wanted = value ~= false
  if State.visible == wanted then return State.visible end
  State.visible = wanted
  -- forced: visibility is not part of the signature, so an otherwise identical frame is skipped
  draw(true)
  return State.visible
end

--- Whether the HUD is up.
---@return boolean visible
function Runtime.isVisible()
  return State.visible
end

AddEventHandler("onClientResourceStart", function(name)
  if name ~= RESOURCE then return end

  local reason
  page, reason = WebUI.create({
    entry = "web/index.html",
    layer = "hud",
    width = SURFACE_WIDTH,
    height = SURFACE_HEIGHT,
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
    local ok, failure = pcall(pullNeeds)
    if not ok then Open77.log.error("needs: " .. tostring(failure)) end
    while page ~= nil do
      ok, failure = pcall(tick)
      if not ok then Open77.log.error("loop: " .. tostring(failure)) end
      Wait(500)
    end
  end)
end)

AddEventHandler("onClientResourceStop", function(name)
  -- opx77_status takes its chip strip down on the way out but raises no farewell for the
  -- needs, so the gauges it owns leave the frame here rather than staying at their last value
  if name == STATUS then
    State.setNeeds(nil, false)
    draw()
    return
  end
  if name ~= RESOURCE then return end
  page, pageReady, drawn = nil, false, nil
end)
