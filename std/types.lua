---@meta
--- Type annotations for opx77_hud. Never loaded at runtime, never listed in open77.lua.

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
---@field voiceSegments integer      segments of the voice input meter
---@field vehicleAnchor HudAnchor|nil where the vehicle read-out stands, nil while disabled

--- Live health and armour, as `OpxHud.Vitals.Sample` reads them from `Open77.stats`.
---@class HudVitals
---@field health number  percent of the reported maximum, 0 upwards
---@field armor number   points, 0 upwards
---@field stamina number|nil  percent of the game's stamina pool, nil when the snapshot has none

--- The state the microphone indicator is drawn in.
---@alias HudVoiceState
---| "idle"      capture on, nothing picked up
---| "detected"  the microphone picks up a voice that is not transmitted
---| "talking"   transmitting
---| "muted"     capture disabled in the pause menu
---| "offline"   no voice backend

--- The payload of `hud:voice`. `{ active = false }` alone takes the indicator off screen.
---@class HudVoiceView
---@field active boolean
---@field state HudVoiceState
---@field caption string          translated word under the mic
---@field lit integer             meter segments lit, 0 while muted or offline
---@field mode string             translated reach mode, or the proximity word without open-voice
---@field distance string|nil     translated reach in metres
---@field index integer|nil       position of the reach mode in open-voice's cycle
---@field count integer|nil       number of reach modes in that cycle
---@field key string|nil          open-voice's cycle key
---@field activation string|nil   open77_voice's push-to-talk key, or the open-mic word under voice activation
---@field heard integer           players heard right now, 0 hides the counter

--- The payload of `hud:vehicle`. `{ active = false }` alone takes the read-out off screen.
---@class HudVehicleView
---@field active boolean
---@field speed integer           km/h, 0..999
---@field gear string             "R", "N" or the forward gear
---@field rpm integer|nil         percent of the rated maximum, nil when unreported
---@field integrity integer|nil   percent, nil when unreported
---@field tone HudTone|nil        integrity at or below 33 or 15 percent
---@field airborne boolean
---@field unit string             translated labels, added by client/main.lua
---@field integrityLabel string
---@field airborneLabel string

--- Every export answers a table carrying `ok` and never raises. Nothing here refuses, so
--- there is no error code.
---@class HudResponse
---@field ok boolean

--- What `setVisible` and `isVisible` answer.
---@class HudVisibility : HudResponse
---@field visible boolean  the player's choice, kept while down
---@field down boolean     opx77_medic has the player down: nothing is drawn, whatever `visible`

--- The payload of `opx77:medic:stateChanged`, as this resource reads it. Any resource can
--- raise the name, so it never changes the player's own `visible` choice.
---@class MedicStateChanged
---@field down boolean
---@field waiting boolean

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

--- Saved health and armour. opx77_core only writes them at character creation and never from
--- gameplay, so the gauge reads `HudVitals` first and these only as a fallback.
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
