OPX_HUD_CONFIG = {
  LOCALE = "en", -- catalogue used for player-facing text; "en" or "fr"
  -- "bottom-left" | "bottom-right" | "top-left" | "top-right"; anything else falls back
  ANCHOR = "bottom-left",
  WIDTH = 210, -- width of the gauge block, in pixels at a 1920-wide surface
  INFO_ANCHOR = "top-right", -- the money, job and cred corner; same four values as ANCHOR
  BLOCKS = { "vitals", "cyber", "needs", "money", "identity" }, -- remove one to drop it
  -- hide a need or cyber gauge above this percent; `false`, or anything that is not a
  -- number, always shows it
  NEEDS_THRESHOLD = 90,
  COMMAND = "hud", -- chat command that shows and hides the HUD, or false for none
  -- The game's own HUD, component by component: `false` hides it, `true` puts it back.
  -- `VANILLA = false` leaves the game's HUD alone; a removed line leaves that component alone.
  VANILLA = {
    minimap = false,
    compass = false,
    clock = false,
    health = false,
    stamina = false,
    weapon = false, -- the weapon and its ammunition count, together
    speedometer = false,
  },
}
