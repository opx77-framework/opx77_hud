--- What the HUD draws, derived from the character opx77_core owns.

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

---@param value any
---@return boolean
local function finite(value)
  return type(value) == "number" and value == value
    and value > -math.huge and value < math.huge
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

--- One builder per name in `Config.BLOCKS`, each appending rows or nothing.
local blocks = {}

---@param data table
---@param rows table
function blocks.vitals(data, rows)
  local metadata = data.metadata or {}
  local health = percent(metadata.health)
  rows[#rows + 1] = { kind = "bar", id = "health", label = "HP", icon = "health",
                      pct = health, value = tostring(health), tone = tone(health) }
  local armor = percent(metadata.armor)
  if armor > 0 then
    rows[#rows + 1] = { kind = "bar", id = "armor", label = "ARMOR", icon = "armor",
                        pct = armor, value = tostring(armor) }
  end
end

--- The two needs and the word each is drawn under. A constant, not a literal inside the
--- loop: written there it was three tables allocated on every frame this block builds.
local NEED_GAUGES = {
  { key = "hunger", label = "FOOD" },
  { key = "thirst", label = "HYDRATION" },
}

--- Hunger and thirst, owned by opx77_status and drawn here. Hidden while comfortable, so a
--- full bar does not sit on screen saying nothing.
---@param data table
---@param rows table
function blocks.needs(data, rows)
  local metadata = data.metadata or {}
  local threshold = Config.NEEDS_THRESHOLD
  for index = 1, #NEED_GAUGES do
    local key, label = NEED_GAUGES[index].key, NEED_GAUGES[index].label
    if finite(metadata[key]) then
      local value = percent(metadata[key])
      if threshold == false or value <= threshold then
        rows[#rows + 1] = { kind = "bar", id = key, label = label, icon = key,
                            pct = value, value = tostring(value), tone = tone(value) }
      end
    end
  end
end

--- Stamina, drawn only once a gameplay file has put it in metadata.
---@param data table
---@param rows table
function blocks.cyber(data, rows)
  local metadata = data.metadata or {}
  local threshold = Config.NEEDS_THRESHOLD
  if not finite(metadata.stamina) then return end
  local value = percent(metadata.stamina)
  if threshold == false or value <= threshold then
    rows[#rows + 1] = { kind = "bar", id = "stamina", label = "STAMINA", icon = "stamina",
                        pct = value, value = tostring(value), tone = tone(value) }
  end
end

--- Led with, in this order; the operator's other money types follow sorted.
local KNOWN_MONEY = { "EDDIES", "BANK" }

---@param data table
---@param rows table
function blocks.money(data, rows)
  local purse = data.money or {}
  local seen = {}
  local order = {}
  local ordered = 0
  for index = 1, #KNOWN_MONEY do
    local key = KNOWN_MONEY[index]
    seen[key] = true
    ordered = ordered + 1
    order[ordered] = key
  end
  -- strings only: `table.sort` on mixed types raises, and so does `:lower()` on a number --
  -- both inside the one thread that repairs this surface
  local extra = {}
  for key in pairs(purse) do
    if type(key) == "string" and not seen[key] then extra[#extra + 1] = key end
  end
  table.sort(extra)
  for index = 1, #extra do
    ordered = ordered + 1
    order[ordered] = extra[index]
  end

  for index = 1, ordered do
    local key = order[index]
    local amount = purse[key]
    if finite(amount) and amount ~= 0 then
      rows[#rows + 1] = { kind = "text", id = key:lower(), label = key, value = money(amount) }
    end
  end
end

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
  local cred = data.metadata and data.metadata.streetCred
  if finite(cred) and cred > 0 then
    rows[#rows + 1] = { kind = "text", id = "cred", label = "CRED",
                        value = tostring(math.floor(cred)) }
  end
end

--- Everything the page draws, or nil when there is no character to draw for.
---@return table|nil
function State.view()
  if not State.visible or State.data == nil then return nil end
  local rows = {}
  local names = Config.BLOCKS
  for index = 1, #names do
    local build = blocks[names[index]]
    if build ~= nil then build(State.data, rows) end
  end
  return { rows = rows }
end

--- A cheap signature of a view, so main.lua can skip a message that moves nothing.
---@param view table|nil
---@return string
function State.signature(view)
  if view == nil then return "" end
  local rows = view.rows
  local parts = {}
  for index = 1, #rows do
    local row = rows[index]
    parts[index] = table.concat({
      row.id, row.label or "", row.value or "", tostring(row.pct or ""), row.tone or "",
      row.icon or "",
    }, "\1")
  end
  return table.concat(parts, "\2")
end
