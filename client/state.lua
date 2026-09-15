--- @author DemiAutomatic
--- @file client/state.lua
--- @description Character and needs snapshots, and the rows the page draws.

local Config = OPX_HUD_CONFIG

OpxHud.State = {}
local State = OpxHud.State

--- @author DemiAutomatic
--- @type {PlayerData|nil}
--- @description Last opx77_core snapshot, nil while no character is loaded.
OpxHud.State.data = nil

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether the surface is shown at all, whatever it holds.
OpxHud.State.visible = true

--- @author DemiAutomatic
--- @type {NeedValues|nil}
--- @description Needs opx77_status last published for the live character.
OpxHud.State.needs = nil

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether opx77_status has answered for the live character.
OpxHud.State.needsReady = false

--- @author DemiAutomatic
--- @method OpxHud.State.SetNeeds
--- @description Adopts published needs, clearing them unless ready with a table.
--- @param values {NeedValues|nil}
--- @param ready {boolean}
function OpxHud.State.SetNeeds(values, ready)
	State.needsReady = ready == true and type(values) == 'table'
	State.needs = State.needsReady and values or nil
end

--- @author DemiAutomatic
--- @method OpxHud.State.Finite
--- @description Whether a value is a number, neither NaN nor infinite.
--- @param value {any}
--- @returns {boolean}
function OpxHud.State.Finite(value)
	return type(value) == 'number' and value == value
		and value > -math.huge and value < math.huge
end

local finite = State.Finite

--- @author DemiAutomatic
--- @method need
--- @description Answers one finite need, or nil while opx77_status has not answered.
--- @param key {string}
--- @returns {number|nil}
local function need(key)
	if not State.needsReady then return nil end
	local value = State.needs and State.needs[key]
	if not finite(value) then return nil end
	return value
end

--- @author DemiAutomatic
--- @method percent
--- @description Clamps a value to 0..100 and rounds it.
--- @param value {any}
--- @returns {integer}
local function percent(value)
	if not finite(value) then return 0 end
	if value < 0 then return 0 end
	if value > 100 then return 100 end
	return math.floor(value + 0.5)
end

--- @author DemiAutomatic
--- @method money
--- @description Formats an amount with space-separated thousands and its sign.
--- @param value {any}
--- @returns {string}
local function money(value)
	if not finite(value) then return '0' end
	local sign = value < 0 and '-' or ''
	local digits = tostring(math.floor(math.abs(value)))
	local grouped = digits:reverse():gsub('(%d%d%d)', '%1 '):reverse()
	return sign .. (grouped:gsub('^%s+', ''))
end

--- @author DemiAutomatic
--- @method tone
--- @description Answers the colour role a gauge percent takes, or nil.
--- @param value {integer}
--- @returns {HudTone|nil}
local function tone(value)
	if value <= 15 then return 'bad' end
	if value <= 33 then return 'warn' end
	return nil
end

--- @author DemiAutomatic
--- @type {HudBlock[]}
--- @description Blocks built in listed order; anything but a list builds none.
local BLOCKS = type(Config.BLOCKS) == 'table' and Config.BLOCKS or {}

--- @author DemiAutomatic
--- @type {number|nil}
--- @description Percent a need or cyber gauge hides above, nil always shows.
local THRESHOLD = finite(Config.NEEDS_THRESHOLD) and Config.NEEDS_THRESHOLD or nil

--- @author DemiAutomatic
--- @method buildVitals
--- @description Appends the health gauge, and armour when above zero.
--- @param data {PlayerData}
--- @param rows {HudRow[]}
local function buildVitals(data, rows)
	local metadata = data.metadata or {}
	local health = percent(metadata.health)
	rows[#rows + 1] = { kind = 'bar', id = 'health', icon = 'health', pct = health,
		value = tostring(health), tone = tone(health) }
	local armor = percent(metadata.armor)
	if armor > 0 then
		rows[#rows + 1] = { kind = 'bar', id = 'armor', icon = 'armor', pct = armor,
			value = tostring(armor) }
	end
end

--- @author DemiAutomatic
--- @type {string[]}
--- @description The needs drawn as gauges, in drawing order.
local NEED_GAUGES = { 'hunger', 'thirst' }

--- @author DemiAutomatic
--- @method buildNeeds
--- @description Appends the hunger and thirst gauges opx77_status has answered.
--- @param _ {PlayerData}
--- @param rows {HudRow[]}
local function buildNeeds(_, rows)
	for index = 1, #NEED_GAUGES do
		local key = NEED_GAUGES[index]
		local raw = need(key)
		if raw ~= nil then
			local value = percent(raw)
			if THRESHOLD == nil or value <= THRESHOLD then
				rows[#rows + 1] = { kind = 'bar', id = key, icon = key, pct = value,
					value = tostring(value), tone = tone(value) }
			end
		end
	end
end

--- @author DemiAutomatic
--- @method buildCyber
--- @description Appends the stamina gauge once opx77_status has answered.
--- @param _ {PlayerData}
--- @param rows {HudRow[]}
local function buildCyber(_, rows)
	local raw = need('stamina')
	if raw == nil then return end
	local value = percent(raw)
	if THRESHOLD == nil or value <= THRESHOLD then
		rows[#rows + 1] = { kind = 'bar', id = 'stamina', icon = 'stamina', pct = value,
			value = tostring(value), tone = tone(value) }
	end
end

--- @author DemiAutomatic
--- @type {string[]}
--- @description Money types drawn first, in this order.
local KNOWN_MONEY = { 'EDDIES', 'BANK' }

--- @author DemiAutomatic
--- @type {table<string, boolean>}
--- @description The leading money types as a set, built once.
local KNOWN_SET = {}
for index = 1, #KNOWN_MONEY do KNOWN_SET[KNOWN_MONEY[index]] = true end

--- @author DemiAutomatic
--- @method buildMoney
--- @description Appends one line per held money type, leading types first.
--- @param data {PlayerData}
--- @param rows {HudRow[]}
local function buildMoney(data, rows)
	local purse = data.money or {}
	local extra
	for key in pairs(purse) do
		if type(key) == 'string' and not KNOWN_SET[key] then
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
			rows[#rows + 1] = { kind = 'text', id = key:lower(), label = key, value = money(amount) }
		end
	end
end

--- @author DemiAutomatic
--- @method buildIdentity
--- @description Appends the job line and the street cred line.
--- @param data {PlayerData}
--- @param rows {HudRow[]}
local function buildIdentity(data, rows)
	local job = data.job
	if type(job) == 'table' and job.label then
		local grade = type(job.grade) == 'table' and job.grade.name or nil
		rows[#rows + 1] = {
			kind = 'text', id = 'job', label = tostring(job.label), value = grade,
			tone = job.onDuty == true and 'on' or nil,
		}
	end
	local cred = need('streetCred')
	if cred ~= nil and cred > 0 then
		rows[#rows + 1] = { kind = 'text', id = 'cred', label = locale('hud.label.cred'),
			value = tostring(math.floor(cred)) }
	end
end

--- @author DemiAutomatic
--- @type {table<string, fun(data: PlayerData, rows: HudRow[])>}
--- @description One row builder per block name config.lua may list.
local blocks = {
	vitals = buildVitals,
	cyber = buildCyber,
	needs = buildNeeds,
	money = buildMoney,
	identity = buildIdentity,
}

--- @author DemiAutomatic
--- @method OpxHud.State.View
--- @description Builds the rows to draw, or nil with nothing to draw.
--- @returns {HudFrame|nil}
function OpxHud.State.View()
	if not State.visible or State.data == nil then return nil end
	local rows = {}
	for index = 1, #BLOCKS do
		local build = blocks[BLOCKS[index]]
		if build ~= nil then build(State.data, rows) end
	end
	return { rows = rows }
end

--- @author DemiAutomatic
--- @method OpxHud.State.Signature
--- @description Reduces a view to a string, so an unchanged frame is skipped.
--- @param view {HudFrame|nil}
--- @returns {string}
function OpxHud.State.Signature(view)
	if view == nil then return '\0' end
	local rows = view.rows
	local parts = {}
	local field = 0
	for index = 1, #rows do
		local row = rows[index]
		parts[field + 1] = row.id
		parts[field + 2] = row.label or ''
		parts[field + 3] = row.value or ''
		parts[field + 4] = row.pct ~= nil and tostring(row.pct) or ''
		parts[field + 5] = row.tone or ''
		parts[field + 6] = row.icon or ''
		field = field + 6
	end
	return table.concat(parts, '\1')
end
