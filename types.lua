---@meta
--- Type annotations for opx77_hud. Never loaded at runtime.

--- A corner of the surface. Anything else falls back to that block's own default.
---@alias HudAnchor "bottom-left"|"bottom-right"|"top-left"|"top-right"

--- The colour role a row takes, or nil for the default one.
---@alias HudTone
---| "bad"   at or below 15 percent
---| "warn"  at or below 33 percent
---| "on"    the job line, while the character is clocked in

--- One entry of config.lua's BLOCKS, built in the order they are listed.
---@alias HudBlock "vitals"|"cyber"|"needs"|"money"|"identity"

--- A gauge row. It carries no label: `gauge()` in web/hud.js draws the icon, the segments
--- and the value, and never reads one.
---@class HudBarRow
---@field kind "bar"
---@field id string        the element the page keeps across frames
---@field icon string      a key of ICONS in web/hud.js
---@field pct integer      0..100, clamped and rounded
---@field value string     already formatted
---@field tone HudTone|nil

--- A text row, drawn in the info corner. Its label IS rendered.
---@class HudTextRow
---@field kind "text"
---@field id string
---@field label string     from the catalogue, or from opx77_core for a money type or a job
---@field value string|nil
---@field tone HudTone|nil

---@alias HudRow HudBarRow|HudTextRow

--- The payload of `hud:frame`. `hud:hide` carries an empty table and nothing else.
---@class HudFrame
---@field rows HudRow[]
---@field chips StatusChip[]         as opx77_status published them, capped at MAX_CHIPS
---@field hidden integer             effects past that cap, drawn as one "+N" chip
---@field stripAnchor HudAnchor|nil  where opx77_status wants its strip
---@field stripOffset number|nil     pixels above that corner

--- The payload of `hud:config`, sent once the page has answered `hud:ready`.
---@class HudConfig
---@field anchor HudAnchor
---@field infoAnchor HudAnchor
---@field width number
---@field segments integer

--- Every export answers a table carrying `ok` and never raises. Nothing here refuses, so
--- there is no error code.
---@class HudResponse
---@field ok boolean

--- What `setVisible` and `isVisible` answer.
---@class HudVisibility : HudResponse
---@field visible boolean

--- What `vanilla` answers. Read-only: nothing may set the game's own HUD through an export.
---@class HudVanilla : HudResponse
---@field available boolean                 false on a client whose Open77.hud predates the API
---@field found table<string, boolean>|nil  what each component was at, before this resource
---@field state table|nil                   whatever the client reports right now

--- opx77_core's shape, reproduced only as far as this resource reads it.
---@class PlayerData
---@field metadata PlayerMetadata|nil
---@field money table<string, number>|nil  money type -> amount
---@field job PlayerJob|nil

--- Health and armour stay in opx77_core; the gameplay needs are opx77_status's.
---@class PlayerMetadata
---@field health number  0-100
---@field armor number   0-100

---@class PlayerJob
---@field name string
---@field label string
---@field onDuty boolean
---@field grade { name: string, level: integer }

--- The needs opx77_status owns, as this resource reads them. It owns the bounds too.
---@class NeedValues
---@field hunger number      0-100
---@field thirst number      0-100
---@field stamina number     0-100
---@field streetCred number  0-100000

--- What the `getNeeds` export of opx77_status answers, and the payload of `opx77:status:needs`.
--- `ready` false blanks the gauges it owns rather than drawing them at zero.
---@class NeedsSnapshot
---@field ok boolean|nil          on the export's answer only
---@field values NeedValues|nil
---@field ready boolean|nil
---@field citizenId string|nil

--- One chip of `opx77:status:effects`, drawn exactly as opx77_status published it.
---@class StatusChip
---@field id string
---@field label string
---@field icon string|nil
---@field tone string|nil
---@field progress number|nil
---@field remainingMs integer|nil
---@field totalMs integer|nil

--- The payload of `opx77:status:effects`. Any resource can raise this name, so `chips` is
--- capped and `hidden`, `anchor` and `offset` are bounded before they reach the page.
---@class StatusEffectsEvent
---@field chips StatusChip[]
---@field hidden integer
---@field anchor HudAnchor|nil
---@field offset number|nil
