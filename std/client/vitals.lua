---@meta

OpxHud.Vitals = {}

--- Reads `Open77.stats.get()` once. Health comes back as a percent of the reported maximum
--- (100 when none is reported), armour in points. An empty snapshot answers nil with no reason;
--- a missing API or a raising call answers nil with the reason.
---@return HudVitals|nil
---@return string|nil reason "api_absent" or the host error
function OpxHud.Vitals.Sample() end
