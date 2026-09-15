---@meta

OpxHud.Vanilla = {}

--- Applies `OPX_HUD_CONFIG.VANILLA` through `Open77.hud`. Safe to call repeatedly; the
--- visibility each component had before is recorded on the first call only.
---@return integer applied
---@return string|nil reason "config_not_a_table" or "api_absent" when nothing could be applied
function OpxHud.Vanilla.Apply() end

--- Puts back the recorded visibility of every component the client reported, then forgets it.
---@return integer restored
function OpxHud.Vanilla.Restore() end

--- What became of the game's own HUD: whether `Open77.hud` exists, what was found, and what
--- the client reports right now.
---@return HudVanilla
function OpxHud.Vanilla.Snapshot() end
