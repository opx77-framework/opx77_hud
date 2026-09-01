OPX_HUD_CONFIG = {
  ANCHOR = "bottom-left", -- "bottom-left" | "bottom-right" | "top-left" | "top-right"
  WIDTH = 210, -- width of the gauge block, in pixels at a 1920-wide surface
  INFO_ANCHOR = "top-right", -- money, job and cred corner; same four values as ANCHOR
  BLOCKS = { "vitals", "cyber", "needs", "money", "identity" }, -- remove one to drop it
  NEEDS_THRESHOLD = 90, -- hide a need or cyber gauge above this percent; false always shows it
  COMMAND = "hud", -- chat command that shows and hides the HUD, or false for none
}
