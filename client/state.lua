--- What the HUD draws: the character opx77_core owns, and the needs opx77_status owns.

OpxHud = OpxHud or {}

local Config = OPX_HUD_CONFIG

local State = {}
OpxHud.state = State

--- The last snapshot opx77_core gave us, or nil when no character is loaded.
---@type table|nil
State.data = nil

--- Whether anything is drawn at all; the character being absent is separate.
---@type boolean
State.visible = true

--- The needs opx77_status last published, or nil while it has none for this character.
---@type table|nil
State.needs = nil

--- Whether opx77_status has answered for the live character. False blanks the gauges it
--- owns instead of drawing them at zero.
---@type boolean
State.needsReady = false

--- Adopt what opx77_status published. A refusal or `ready = false` clears the values.
---@param values table|nil
---@param ready boolean
function State.setNeeds(values, ready)
  State.needsReady = ready == true and type(values) == "table"
  State.needs = State.needsReady and values or nil
end

--- A number, not NaN, and neither infinity.
---@param value any
---@return boolean
function State.finite(value)
  -- `value == value` is the NaN check: NaN is the one value unequal to itself
  return type(value) == "number" and value == value
    and value > -math.huge and value < math.huge
end

local finite = State.finite

--- One need opx77_status owns, or nil while it has not answered for this character.
---@param key string
---@return number|nil
local function need(key)
  if not State.needsReady then return nil end
  local value = State.needs and State.needs[key]
  if not finite(value) then return nil end
  return value
end

--- Clamped to 0..100 and rounded.
---@param value any
---@return integer
local function percent(value)
  if not finite(value) then return 0 end
  if value < 0 then return 0 end
  if value > 100 then return 100 end
  return math.floor(value + 0.5)
end

--- Thousands separated by a space, sign kept in front of the digits.
---@param value any
---@return string
local function money(value)
  if not finite(value) then return "0" end
  local sign = value < 0 and "-" or ""
  local digits = tostring(math.floor(math.abs(value)))
  local grouped = digits:reverse():gsub("(%d%d%d)", "%1 "):reverse()
  return sign .. (grouped:gsub("^%s+", ""))
end

--- The colour role a bar takes, or nil for the default one.
---@param value integer
---@return string|nil
local function tone(value)
  if value <= 15 then return "bad" end
  if value <= 33 then return "warn" end
  return nil
end

--- The blocks built, in the order they are listed; anything but a list draws none.
local BLOCKS = type(Config.BLOCKS) == "table" and Config.BLOCKS or {}

--- The percent a need or cyber gauge is hidden above, or nil to always show it. Anything
--- that is not a number reads as `false`: a comparison against it would raise, not refuse.
local THRESHOLD = finite(Config.NEEDS_THRESHOLD) and Config.NEEDS_THRESHOLD or nil

--- One builder per name in `Config.BLOCKS`, each appending rows or nothing.
local blocks = {}

--- Health, and armour when the character has any.
---@param data table
---@param rows table
function blocks.vitals(data, rows)
  local metadata = data.metadata or {}
  local health = percent(metadata.health)
  rows[#rows + 1] = { kind = "bar", id = "health", icon = "health", pct = health,
                      value = tostring(health), tone = tone(health) }
  local armor = percent(metadata.armor)
  if armor > 0 then
    rows[#rows + 1] = { kind = "bar", id = "armor", icon = "armor", pct = armor,
                        value = tostring(armor) }
  end
end

--- The two needs drawn as gauges, in the order they appear.
local NEED_GAUGES = { "hunger", "thirst" }

--- Hunger and thirst, from opx77_status, hidden while comfortable and absent while it has
--- not answered.
---@param _ table
---@param rows table
function blocks.needs(_, rows)
  for index = 1, #NEED_GAUGES do
    local key = NEED_GAUGES[index]
    local raw = need(key)
    if raw ~= nil then
      local value = percent(raw)
      if THRESHOLD == nil or value <= THRESHOLD then
        rows[#rows + 1] = { kind = "bar", id = key, icon = key, pct = value,
                            value = tostring(value), tone = tone(value) }
      end
    end
  end
end

--- Stamina, from opx77_status, drawn only once it has answered.
---@param _ table
---@param rows table
function blocks.cyber(_, rows)
  local raw = need("stamina")
  if raw == nil then return end
  local value = percent(raw)
  if THRESHOLD == nil or value <= THRESHOLD then
    rows[#rows + 1] = { kind = "bar", id = "stamina", icon = "stamina", pct = value,
                        value = tostring(value), tone = tone(value) }
  end
end

--- Led with, in this order; the operator's other money types follow sorted.
local KNOWN_MONEY = { "EDDIES", "BANK" }

--- The same names as a set, built once rather than on every frame.
local KNOWN_SET = {}
for index = 1, #KNOWN_MONEY do KNOWN_SET[KNOWN_MONEY[index]] = true end

--- Every money type the character holds, KNOWN_MONEY first.
---@param data table
---@param rows table
function blocks.money(data, rows)
  local purse = data.money or {}
  -- allocated only for an operator who configured a money type beyond KNOWN_MONEY, and
  -- strings only: `table.sort` on mixed key types raises
  local extra
  for key in pairs(purse) do
    if type(key) == "string" and not KNOWN_SET[key] then
      extra = extra or {}
      extra[#extra + 1] = key
    end
  end
  if extra ~= nil then table.sort(extra) end

  local led = #KNOWN_MONEY
  local total = led + (extra ~= nil and #extra or 0)
  for index = 1, total do
    local key = index <= led and KNOWN_MONEY[index] or extra[index - led]
    local amount = purse[key]
    if finite(amount) and amount ~= 0 then
      rows[#rows + 1] = { kind = "text", id = key:lower(), label = key, value = money(amount) }
    end
  end
end

--- The job line from opx77_core, and street cred from opx77_status.
---@param data table
---@param rows table
function blocks.identity(data, rows)
  local job = data.job
  if type(job) == "table" and job.label then
    local grade = type(job.grade) == "table" and job.grade.name or nil
    rows[#rows + 1] = {
      kind = "text", id = "job", label = tostring(job.label), value = grade,
      tone = job.onDuty == true and "on" or nil,
    }
  end
  local cred = need("streetCred")
  if cred ~= nil and cred > 0 then
    rows[#rows + 1] = { kind = "text", id = "cred", label = locale("hud.label.cred"),
                        value = tostring(math.floor(cred)) }
  end
end

--- Everything the page draws, or nil when there is no character to draw for.
---@return table|nil
function State.view()
  if not State.visible or State.data == nil then return nil end
  local rows = {}
  for index = 1, #BLOCKS do
    local build = blocks[BLOCKS[index]]
    if build ~= nil then build(State.data, rows) end
  end
  return { rows = rows }
end

--- A cheap signature of a view, so main.lua can skip a message that moves nothing.
--- No view answers "\0": a rowless character and no character at all are different frames.
---@param view table|nil
---@return string
function State.signature(view)
  if view == nil then return "\0" end
  local rows = view.rows
  -- one flat list joined once: six fields per row, so the row count is read back from the
  -- field count and no separate row separator is needed
  local parts = {}
  local field = 0
  for index = 1, #rows do
    local row = rows[index]
    parts[field + 1] = row.id
    parts[field + 2] = row.label or ""
    parts[field + 3] = row.value or ""
    parts[field + 4] = row.pct ~= nil and tostring(row.pct) or ""
    parts[field + 5] = row.tone or ""
    parts[field + 6] = row.icon or ""
    field = field + 6
  end
  return table.concat(parts, "\1")
end
