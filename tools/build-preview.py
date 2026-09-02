#!/usr/bin/env python3
"""Regenerates ../preview.html from the resource's own files.

    python3 tools/build-preview.py        # then open preview.html in a browser

`preview.html` is a DEV ARTEFACT, not part of the resource: it sits at the
repository root rather than under `web/`, so `web_files { "web/**" }` does not
match it and it is never shipped to a client.

Generated rather than hand-written so it cannot drift, and as close to the
shipped page as a browser gets: `web/open77-ui.css`, `web/hud.css` and
`web/hud.js` are inlined VERBATIM, the markup is lifted out of
`web/index.html`, and it runs on the real `<body>` exactly as in game. The
scene is painted on `<html>`, the one element the stylesheet leaves alone, so
it stays visible while the body fades.

Two things are not the resource: the `Open77` bridge is shimmed, and the
character comes from a table here instead of from opx77_core. What draws the
rows is the resource's own client/state.lua logic, restated in JS -- the same
thresholds, the same hiding rules, read from config.lua at build time.
"""
import base64, json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
BACKGROUND = ROOT / "tools/preview-bg.jpg"

tokens = (ROOT / "web/open77-ui.css").read_text(encoding="utf-8")
hudcss = (ROOT / "web/hud.css").read_text(encoding="utf-8")
hudjs = (ROOT / "web/hud.js").read_text(encoding="utf-8")
index = (ROOT / "web/index.html").read_text(encoding="utf-8")
config = (ROOT / "config.lua").read_text(encoding="utf-8")


def scalar(name, cast=str):
    match = re.search(r"^\s*%s\s*=\s*([^,\n]+)," % name, config, re.M)
    if match is None:
        raise SystemExit("config.lua: %s not found" % name)
    return cast(match.group(1).strip().strip('"'))


CFG = {
    "anchor": scalar("ANCHOR"),
    "infoAnchor": scalar("INFO_ANCHOR"),
    "width": scalar("WIDTH", int),
    "theme": scalar("THEME"),
    "tween": scalar("TWEEN_MS", int),
    "segments": scalar("GAUGE_SEGMENTS", int),
}
THRESHOLD = scalar("NEEDS_THRESHOLD", int)
BLOCKS = re.search(r"BLOCKS = \{([^}]*)\}", config).group(1)
BLOCKS = [b.strip().strip('"') for b in BLOCKS.split(",") if b.strip()]

markup = re.search(r'<div class="gauges" id="gauges"></div>\n<ul class="info" id="info"></ul>', index)
if markup is None:
    raise SystemExit("web/index.html: the hud markup was not found")
markup = markup.group(0)

background = base64.b64encode(BACKGROUND.read_bytes()).decode()

scene_css = """
/* ==========================================================================
   The scene. Everything above this line is the resource, unedited.
   ========================================================================== */
html {
  background: #000 url("data:image/jpeg;base64,__BACKGROUND__") center / cover no-repeat;
}
"""

driver_js = r"""
/* --------------------------------------------------------------- preview --
 * A stand-in for client/state.lua: the same thresholds and the same hiding
 * rules, so the rows on screen are the rows the resource would send.
 *
 *   space   step through the sample characters
 *   T       swap the theme
 *   A       cycle the anchor
 *   H       hide and show, as the setVisible export does
 */
(function () {
  "use strict";

  var CONFIG = __CONFIG__;
  var THRESHOLD = __THRESHOLD__;
  var BLOCKS = __BLOCKS__;
  var SAMPLES = __SAMPLES__;
  var ANCHORS = ["bottom-left", "bottom-right", "top-left", "top-right"];

  function percent(value) {
    if (typeof value !== "number" || !isFinite(value)) return 0;
    return Math.max(0, Math.min(100, Math.round(value)));
  }

  function money(value) {
    var sign = value < 0 ? "-" : "";
    return sign + String(Math.floor(Math.abs(value))).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
  }

  function tone(value) {
    if (value <= 15) return "bad";
    if (value <= 33) return "warn";
    return null;
  }

  var blocks = {
    vitals: function (data, rows) {
      var health = percent(data.metadata.health);
      rows.push({ kind: "bar", id: "health", label: "HP", icon: "health", pct: health,
                  value: String(health), tone: tone(health) });
      var armor = percent(data.metadata.armor);
      if (armor > 0) {
        rows.push({ kind: "bar", id: "armor", label: "ARMOR", icon: "armor",
                    pct: armor, value: String(armor) });
      }
    },
    // Hydration, and nothing else: Night City has no hunger.
    needs: function (data, rows) {
      var value = percent(data.metadata.thirst);
      if (THRESHOLD === false || value <= THRESHOLD) {
        rows.push({ kind: "bar", id: "thirst", label: "HYDRATION", icon: "thirst",
                    pct: value, value: String(value), tone: tone(value) });
      }
    },
    // Drawn only where a gameplay file has put them in metadata.
    cyber: function (data, rows) {
      [["stamina", "STAMINA"], ["ram", "RAM"]].forEach(function (gauge) {
        var raw = data.metadata[gauge[0]];
        if (typeof raw !== "number") return;
        var value = percent(raw);
        if (THRESHOLD === false || value <= THRESHOLD) {
          rows.push({ kind: "bar", id: gauge[0], label: gauge[1], icon: gauge[0],
                      pct: value, value: String(value), tone: tone(value) });
        }
      });
    },
    // The two known names lead; anything the operator added follows, sorted.
    money: function (data, rows) {
      var known = ["EDDIES", "BANK"];
      var extra = Object.keys(data.money).filter(function (k) { return known.indexOf(k) < 0; });
      extra.sort();
      known.concat(extra).forEach(function (key) {
        var amount = data.money[key];
        if (typeof amount === "number" && amount !== 0) {
          rows.push({ kind: "text", id: key.toLowerCase(), label: key, value: money(amount) });
        }
      });
    },
    identity: function (data, rows) {
      if (data.job && data.job.label) {
        rows.push({ kind: "text", id: "job", label: data.job.label,
                    value: data.job.grade && data.job.grade.name,
                    tone: data.job.onDuty ? "on" : null });
      }
      if (data.metadata.streetCred > 0) {
        rows.push({ kind: "text", id: "cred", label: "CRED",
                    value: String(Math.floor(data.metadata.streetCred)) });
      }
    }
  };

  var sample = 0;
  var visible = true;
  var live = Object.assign({}, CONFIG);

  function draw() {
    if (!visible) { Open77.__deliver("hud:hide", {}); return; }
    var data = SAMPLES[sample];
    var rows = [];
    BLOCKS.forEach(function (name) { if (blocks[name]) blocks[name](data, rows); });
    Open77.__deliver("hud:frame", { rows: rows });
  }

  var KEYS = {
    " ": function () { sample = (sample + 1) % SAMPLES.length; draw(); },
    t: function () {
      live.theme = live.theme === "cyberpunk" ? "open77" : "cyberpunk";
      Open77.__deliver("hud:config", live);
    },
    a: function () {
      live.anchor = ANCHORS[(ANCHORS.indexOf(live.anchor) + 1) % ANCHORS.length];
      Open77.__deliver("hud:config", live);
    },
    h: function () { visible = !visible; draw(); }
  };

  document.addEventListener("keydown", function (event) {
    var action = KEYS[event.key === " " ? " " : event.key.toLowerCase()];
    if (!action) return;
    event.preventDefault();
    action();
  });

  Open77.__deliver("hud:config", live);
  draw();
})();
"""

SAMPLES = [
    {"money": {"EDDIES": 1240, "BANK": 5000, "CRYPTO": 0},
     "job": {"label": "Merc", "onDuty": True, "grade": {"name": "Solo"}},
     "metadata": {"health": 100, "armor": 0, "thirst": 40, "stamina": 100, "ram": 62, "streetCred": 28}},
    {"money": {"EDDIES": 90, "BANK": 5000},
     "job": {"label": "Merc", "onDuty": True, "grade": {"name": "Solo"}},
     "metadata": {"health": 34, "armor": 62, "thirst": 22, "stamina": 45, "ram": 20, "streetCred": 28}},
    {"money": {"EDDIES": 4, "BANK": 0},
     "job": {"label": "Fixer", "onDuty": False, "grade": {"name": "Runner"}},
     "metadata": {"health": 11, "armor": 0, "thirst": 9, "stamina": 12, "ram": 0, "streetCred": 41}},
]

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OPX77 HUD</title>
<!-- The three faces the tokens name first. In game none of them resolve and
     the stacks fall through to Bahnschrift and Cascadia Mono. -->
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Rajdhani:wght@400;600;700&family=Saira:wght@400;600;700&family=IBM+Plex+Mono:wght@400;700&display=swap">
<style>
/* ==========================================================================
   web/open77-ui.css -- verbatim
   ========================================================================== */
{tokens}
/* ==========================================================================
   web/hud.css -- verbatim
   ========================================================================== */
{hudcss}
{scene_css.replace("__BACKGROUND__", background)}
</style>
</head>

<body>

{markup}
<script>
/* The host's bridge, shimmed: `__deliver` is where Lua would be. */
window.Open77 = (function () {{
  var handlers = {{}};
  return {{
    on: function (channel, handler) {{ handlers[channel] = handler; }},
    emit: function () {{}},
    ready: function () {{}},
    __deliver: function (channel, payload) {{
      if (handlers[channel]) handlers[channel](payload);
    }}
  }};
}})();
</script>
<script>
/* ==========================================================================
   web/hud.js -- verbatim
   ========================================================================== */
{hudjs}
</script>
<script>
{driver_js.replace("__CONFIG__", json.dumps(CFG)).replace("__THRESHOLD__", json.dumps(THRESHOLD)).replace("__BLOCKS__", json.dumps(BLOCKS)).replace("__SAMPLES__", json.dumps(SAMPLES))}
</script>
</body>
</html>
"""

out = ROOT / "preview.html"
out.write_text(html, encoding="utf-8")
print("wrote %s (%.0f KB)" % (out, len(html) / 1024))
print("anchor=%(anchor)s theme=%(theme)s width=%(width)spx" % CFG)
