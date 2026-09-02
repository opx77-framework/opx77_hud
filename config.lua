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
  -- The game's own HUD, component by component: `false` hides it, `true` puts it back.
  -- Everything is off by default, because this resource draws the replacement -- left alone
  -- the two stack, and the player reads their health off two bars that disagree while one of
  -- them animates.
  --
  -- Set `VANILLA = false` to leave the game's HUD entirely alone; remove a line to leave that
  -- one component alone. What is restored when this resource stops is whatever each component
  -- was found at, not what is written here.
  --
  -- The names are the client's, not ours, and `Open77.hud.components()` is what the client
  -- answers when asked. A name this client does not recognise is a logged warning and nothing
  -- else, so an older client is never a script error.
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
