---@meta

OpxHud.Runtime = {}

--- Tells the player something: a toast through opx77_notify while it runs and
--- `OPX_HUD_CONFIG.NOTIFY` allows, a chat line otherwise. Best-effort, never a dependency.
---@param kind "info"|"success"|"warning"|"error"
---@param message string
function OpxHud.Runtime.Notify(kind, message) end

--- Shows (anything but `false`) or hides the surface, and redraws when that changed.
---@param value any
---@return boolean visible the resulting visibility
function OpxHud.Runtime.SetVisible(value) end

--- Whether the surface is shown.
---@return boolean
function OpxHud.Runtime.IsVisible() end
