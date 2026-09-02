OPX_HUD_CONFIG = {
  -- The corner the GAUGE block sits in. Four values, and nothing else is recognised:
  -- "bottom-left" | "bottom-right" | "top-left" | "top-right". An unrecognised value is not
  -- an error -- web/hud.js falls back to "bottom-left" and says nothing.
  --
  -- Three resources spell this key `ANCHOR` and none of them accept the same set, so read
  -- the list beside the one you are editing rather than assuming: opx77_menu adds the
  -- mid-height edges "left" and "right" and has no bottom corners, and opx77_chat takes only
  -- the two left ones.
  ANCHOR = "bottom-left",
  WIDTH = 210, -- width of the gauge block, in pixels at a 1920-wide surface
  -- The money, job and cred corner. The same four values as ANCHOR above, same silent
  -- fallback, except that this one falls back to "top-right".
  INFO_ANCHOR = "top-right",
  BLOCKS = { "vitals", "cyber", "needs", "money", "identity" }, -- remove one to drop it
  NEEDS_THRESHOLD = 90, -- hide a need or cyber gauge above this percent; false always shows it
  COMMAND = "hud", -- chat command that shows and hides the HUD, or false for none
}
