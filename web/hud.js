/* A renderer: Lua decides which rows exist and what they say, this draws them in order. */
(function () {
  "use strict";

  /* Errors are reported to Lua: the bridge swallows handler exceptions and no
     console output reaches the client log. */
  var reportCount = 0;
  var reporting = false;

  function describe(value) {
    try {
      if (value instanceof Error) return (value.name || "Error") + ": " + value.message;
      if (value === null || value === undefined) return String(value);
      if (typeof value === "object") return Object.prototype.toString.call(value);
      return String(value);
    } catch (ignored) { return "<undescribable>"; }
  }

  function report(text) {
    if (reporting || reportCount >= 20) return;
    reporting = true;
    reportCount += 1;
    try { window.Open77.emit("hud:diag", { text: String(text).slice(0, 400) }); }
    catch (ignored) { /* nowhere left to complain to */ }
    reporting = false;
  }

  window.addEventListener("error", function (event) {
    report("uncaught " + (event.message || "?") + " at line " + (event.lineno || 0));
  });
  (function (original) {
    console.error = function () {
      report(Array.prototype.map.call(arguments, describe).join(" "));
      try { original.apply(console, arguments); } catch (ignored) { /* no console */ }
    };
  })(console.error);

  /* An empty Lua list arrives as {}, which is truthy: `value || []` keeps it. */
  function list(value) { return Array.isArray(value) ? value : []; }
  function text(value) { return value === null || value === undefined ? "" : String(value); }

  var gaugesEl = document.getElementById("gauges");
  var infoEl = document.getElementById("info");

  var ANCHORS = {
    "bottom-left": "anchor-bottom-left",
    "bottom-right": "anchor-bottom-right",
    "top-left": "anchor-top-left",
    "top-right": "anchor-top-right",
    "top-center": "anchor-top-center",
    "bottom-center": "anchor-bottom-center"
  };

  /* Inline SVG: no icon font reaches a page here. `currentColor` carries the tone rules. */
  var ICONS = {
    health: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6">' +
            '<path d="M8 13.5S2 10 2 6.2A3.2 3.2 0 0 1 8 4.6 3.2 3.2 0 0 1 14 6.2C14 10 8 13.5 8 13.5Z"/></svg>',
    armor:  '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6">' +
            '<path d="M8 1.8 13.4 4v4.2c0 3.2-2.4 5.3-5.4 6.2-3-0.9-5.4-3-5.4-6.2V4Z"/></svg>',
    stamina: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" ' +
             'stroke-linejoin="round"><path d="M9.2 1.6 4.2 8.9h3.4l-.8 5.5 5-7.3H8.4Z"/></svg>',
    hunger: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" ' +
            'stroke-linecap="round"><path d="M4.4 1.9v4.6a1.6 1.6 0 0 0 3.2 0V1.9"/>' +
            '<path d="M6 6.5v7.6"/>' +
            '<path d="M11.6 1.9c-1 0-1.8 1.6-1.8 3.6s.8 2.6 1.8 2.6Z"/>' +
            '<path d="M11.6 8.1v6"/></svg>',
    thirst: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6">' +
            '<path d="M8 1.8s4.3 4.6 4.3 7.5A4.3 4.3 0 0 1 8 14.2 4.3 4.3 0 0 1 3.7 9.3C3.7 6.4 8 1.8 8 1.8Z"/></svg>'
  };

  var strip = document.getElementById("strip");
  var chipsEl = document.getElementById("chips");

  var segments = 10;

  function applyConfig(payload) {
    payload = payload || {};

    gaugesEl.className = "gauges " + (ANCHORS[text(payload.anchor)] || ANCHORS["bottom-left"]);
    infoEl.className = "info " + (ANCHORS[text(payload.infoAnchor)] || ANCHORS["top-right"]);
    var width = Number(payload.width);
    if (isFinite(width) && width > 0) {
      gaugesEl.style.setProperty("--hud-width", Math.round(width) + "px");
    }
    var count = Number(payload.segments);
    if (isFinite(count) && count >= 2) segments = Math.round(count);
    /* must run after `anchor` has been read out of this payload */
    stripFallback = ANCHORS[text(payload.anchor)] || ANCHORS["bottom-left"];
    placeStrip(payload);

    var voiceCount = Number(payload.voiceSegments);
    if (isFinite(voiceCount) && voiceCount >= 2) voiceCells = cells(voiceMeter, Math.round(voiceCount));
    vehicleEl.className = "vehicle " + (ANCHORS[text(payload.vehicleAnchor)] || ANCHORS["bottom-center"]) +
      (vehicleEl.classList.contains("live") ? " live" : "");
  }

  /* Replaces a container's children with `count` plain segments and answers them. */
  function cells(parent, count) {
    var made = [];
    while (parent.firstChild) parent.removeChild(parent.firstChild);
    for (var index = 0; index < count; index += 1) {
      var cell = span("block");
      made.push(cell);
      parent.appendChild(cell);
    }
    return made;
  }

  function light(list, lit) {
    for (var index = 0; index < list.length; index += 1) {
      var wanted = index < lit ? "block on" : "block";
      if (list[index].className !== wanted) list[index].className = wanted;
    }
  }

  function setText(node, value) {
    var wanted = text(value);
    if (node.textContent !== wanted) node.textContent = wanted;
  }

  /* Voice: Lua decides the state and every word; this only lights what it is told. */
  var VOICE_STATES = ["idle", "detected", "talking", "muted", "offline"];
  var voiceEl = document.getElementById("voice");
  var voiceMeter = document.getElementById("voice-meter");
  var voiceRefs = {
    caption: document.getElementById("voice-caption"),
    mode: document.getElementById("voice-mode"),
    distance: document.getElementById("voice-distance"),
    pips: document.getElementById("voice-pips"),
    key: document.getElementById("voice-key"),
    ptt: document.getElementById("voice-ptt"),
    heard: document.getElementById("voice-heard"),
    heardCount: document.getElementById("voice-heard-count")
  };
  var voiceCells = cells(voiceMeter, 8);
  var voicePips = [];

  function renderVoice(payload) {
    payload = payload || {};
    if (payload.active !== true) {
      voiceEl.classList.remove("live");
      return;
    }
    var state = VOICE_STATES.indexOf(text(payload.state)) >= 0 ? text(payload.state) : "offline";
    var wanted = "voice live state-" + state;
    if (voiceEl.className !== wanted) voiceEl.className = wanted;

    setText(voiceRefs.caption, payload.caption);
    setText(voiceRefs.mode, payload.mode);
    setText(voiceRefs.distance, payload.distance);
    voiceRefs.distance.hidden = !payload.distance;
    light(voiceCells, Number(payload.lit) || 0);

    var count = Math.max(0, Math.min(8, Math.round(Number(payload.count) || 0)));
    if (voicePips.length !== count) voicePips = cells(voiceRefs.pips, count);
    light(voicePips, Math.round(Number(payload.index) || 0));
    voiceRefs.pips.hidden = count === 0;

    setText(voiceRefs.key, payload.key);
    voiceRefs.key.hidden = !payload.key;
    setText(voiceRefs.ptt, payload.activation);
    voiceRefs.ptt.hidden = !payload.activation;

    var heard = Math.max(0, Math.round(Number(payload.heard) || 0));
    setText(voiceRefs.heardCount, heard);
    voiceRefs.heard.hidden = heard === 0;
  }

  /* Vehicle: shown only while Lua says the character sits in one. */
  var vehicleEl = document.getElementById("vehicle");
  var vehicleRefs = {
    speed: document.getElementById("vehicle-speed"),
    unit: document.getElementById("vehicle-unit"),
    gear: document.getElementById("vehicle-gear"),
    rpm: document.getElementById("vehicle-rpm"),
    integrityRing: document.getElementById("vehicle-integrity-ring"),
    integrityRow: document.getElementById("vehicle-integrity-row"),
    integrityLabel: document.getElementById("vehicle-integrity-label"),
    integrity: document.getElementById("vehicle-integrity"),
    air: document.getElementById("vehicle-air")
  };
  /* Past this share of the outer ring the engine reads as redlining. */
  var REDLINE = 85;
  /* Speed that fills the outer ring when the engine speed is not reported. */
  var DIAL_KPH = 250;

  /* Fills a pathLength-100 ring to a percent. */
  function ring(path, percent) {
    var share = Math.max(0, Math.min(100, percent));
    path.style.strokeDasharray = share + " 100";
  }

  function renderVehicle(payload) {
    payload = payload || {};
    if (payload.active !== true) {
      vehicleEl.classList.remove("live");
      return;
    }
    vehicleEl.classList.add("live");
    setText(vehicleRefs.speed, Math.max(0, Math.round(Number(payload.speed) || 0)));
    setText(vehicleRefs.unit, payload.unit);

    var gear = text(payload.gear) || "N";
    setText(vehicleRefs.gear, gear);
    vehicleRefs.gear.className = "vehicle-gear" + (gear === "R" ? " reverse" : gear === "N" ? " neutral" : "");

    var fill = typeof payload.rpm === "number" ? payload.rpm
      : (Number(payload.speed) || 0) / DIAL_KPH * 100;
    ring(vehicleRefs.rpm, fill);
    vehicleRefs.rpm.classList.toggle("redline", typeof payload.rpm === "number" && payload.rpm >= REDLINE);

    var hasIntegrity = typeof payload.integrity === "number";
    vehicleRefs.integrityRow.hidden = !hasIntegrity;
    ring(vehicleRefs.integrityRing, hasIntegrity ? payload.integrity : 0);
    vehicleRefs.integrityRing.setAttribute("class", "ring-integrity" + (payload.tone ? " " + text(payload.tone) : ""));
    if (hasIntegrity) {
      setText(vehicleRefs.integrityLabel, payload.integrityLabel);
      setText(vehicleRefs.integrity, Math.round(payload.integrity) + "%");
      vehicleRefs.integrityRow.className = "vehicle-integrity" + (payload.tone ? " " + text(payload.tone) : "");
    }

    setText(vehicleRefs.air, payload.airborne === true ? payload.airborneLabel : "");
    vehicleRefs.air.hidden = payload.airborne !== true;
  }

  /* The strip rides in the HUD's corner until opx77_status publishes a stripAnchor.
     This is the only place the strip element is positioned. */
  var stripFallback = ANCHORS["bottom-left"];

  function placeStrip(payload) {
    strip.className = "strip " + (ANCHORS[text(payload.stripAnchor)] || stripFallback);
    var offset = Number(payload.stripOffset);
    if (isFinite(offset) && offset >= 0) {
      strip.style.setProperty("--strip-offset", Math.round(offset) + "px");
    }
  }

  /* One element per row id, kept across frames: a fresh node has nothing to animate from. */
  var slots = {};

  function span(className) {
    var node = document.createElement("span");
    node.className = className;
    return node;
  }

  function gauge(row) {
    var entry = slots[row.id];
    if (entry !== undefined) return entry;
    entry = { node: document.createElement("div"), icon: span("icon"),
              blocks: span("blocks"), value: span("value"), cells: [] };
    entry.icon.innerHTML = ICONS[row.icon] || "";
    for (var index = 0; index < segments; index += 1) {
      var cell = span("block");
      entry.cells.push(cell);
      entry.blocks.appendChild(cell);
    }
    entry.node.appendChild(entry.icon);
    entry.node.appendChild(entry.blocks);
    entry.node.appendChild(entry.value);
    slots[row.id] = entry;
    return entry;
  }

  function line(row) {
    var entry = slots[row.id];
    if (entry !== undefined) return entry;
    entry = { node: document.createElement("li"), label: span("label"), value: span("value") };
    entry.node.appendChild(entry.label);
    entry.node.appendChild(entry.value);
    slots[row.id] = entry;
    return entry;
  }

  /* insertBefore, never appendChild: appending MOVES a node to the end. */
  function place(parent, wanted) {
    for (var index = 0; index < wanted.length; index += 1) {
      var current = parent.children[index];
      if (current !== wanted[index]) parent.insertBefore(wanted[index], current || null);
    }
    while (parent.children.length > wanted.length) parent.lastElementChild.remove();
  }

  function render(payload) {
    var rows = list((payload || {}).rows);
    var bars = [], lines = [];

    for (var index = 0; index < rows.length; index += 1) {
      var row = rows[index] || {};
      if (!row.id) continue;
      if (row.kind === "bar") {
        var entry = gauge(row);
        entry.node.className = "gauge " + text(row.id) + (row.tone ? " " + text(row.tone) : "");
        entry.value.textContent = text(row.value);
        // rounded up: a gauge with anything left in it never reads as empty
        var lit = Math.ceil((Number(row.pct) || 0) / 100 * segments);
        for (var cell = 0; cell < entry.cells.length; cell += 1) {
          entry.cells[cell].className = cell < lit ? "block on" : "block";
        }
        bars.push(entry.node);
      } else {
        var read = line(row);
        read.node.className = "line " + text(row.id) + (row.tone ? " " + text(row.tone) : "");
        read.label.textContent = text(row.label);
        read.value.textContent = text(row.value);
        lines.push(read.node);
      }
    }

    place(gaugesEl, bars);
    place(infoEl, lines);
    document.body.classList.add("open");
  }

  function hide() {
    document.body.classList.remove("open");
  }

  /* Status effects: opx77_status owns them, this surface draws them.
     One <li> per chip id, kept while Lua keeps sending that id and dropped the
     frame it stops, so a rebuilt element never restarts its countdown. */
  var chips = {};

  function chip(id) {
    var entry = chips[id];
    if (entry !== undefined) return entry;
    entry = { node: document.createElement("li"), icon: span("icon"), label: span("label"),
              time: span("time") };
    entry.node.appendChild(entry.icon);
    entry.node.appendChild(entry.label);
    entry.node.appendChild(entry.time);
    chips[id] = entry;
    return entry;
  }

  function renderChips(payload) {
    payload = payload || {};
    var wanted = list(payload.chips);
    var order = [];
    var seen = {};
    var atMs = Date.now();

    for (var index = 0; index < wanted.length; index += 1) {
      var row = wanted[index] || {};
      if (!row.id) continue;
      var entry = chip(row.id);
      entry.node.className = "chip" + (row.tone ? " " + text(row.tone) : "");
      entry.icon.textContent = text(row.icon);
      entry.label.textContent = text(row.label);
      // absolute, so the countdown is this page's own arithmetic from here on
      entry.endsAt = Number(row.remainingMs) > 0 ? atMs + Number(row.remainingMs) : null;
      entry.total = Number(row.totalMs) || null;
      entry.progress = typeof row.progress === "number" ? row.progress : null;
      seen[row.id] = true;
      order.push(entry.node);
    }

    var hidden = Number(payload.hidden) || 0;
    if (hidden > 0) {
      var more = chip("__more");
      more.node.className = "chip more";
      more.icon.textContent = "";
      more.label.textContent = "+" + hidden;
      more.endsAt = null;
      more.total = null;
      more.progress = null;
      seen.__more = true;
      order.push(more.node);
    }

    for (var id in chips) {
      if (!seen[id]) {
        if (chips[id].node.parentNode) chips[id].node.remove();
        delete chips[id];
      }
    }
    /* insertBefore, never appendChild: appending MOVES a node to the end. */
    for (var i = 0; i < order.length; i += 1) {
      if (chipsEl.children[i] !== order[i]) {
        chipsEl.insertBefore(order[i], chipsEl.children[i] || null);
      }
    }

    document.body.classList.add("open");
  }

  /* One rAF loop for every chip on screen; it stops once no deadline is left to draw. */
  function chipFrame() {
    var atMs = Date.now();
    var running = false;
    for (var id in chips) {
      var entry = chips[id];
      if (!entry.node.parentNode) continue;
      var width = null;
      if (entry.endsAt && entry.total) {
        width = Math.max(0, Math.min(1, (entry.endsAt - atMs) / entry.total));
        running = true;
      } else if (entry.progress !== null) {
        width = entry.progress;
      }
      entry.time.style.width = width === null ? "0" : (width * 100) + "%";
    }
    if (running) window.requestAnimationFrame(chipFrame);
    else pending = false;
  }

  var pending = false;
  function pump() {
    if (pending) return;
    pending = true;
    window.requestAnimationFrame(chipFrame);
  }


  Open77.on("hud:config", function (payload) {
    try { applyConfig(payload); } catch (error) { report("config: " + describe(error)); }
  });
  Open77.on("hud:frame", function (payload) {
    try {
      render(payload);
      placeStrip(payload || {});
      renderChips(payload);
      pump();
    } catch (error) { report("render: " + describe(error)); }
  });
  Open77.on("hud:voice", function (payload) {
    try { renderVoice(payload); } catch (error) { report("voice: " + describe(error)); }
  });
  Open77.on("hud:vehicle", function (payload) {
    try { renderVehicle(payload); } catch (error) { report("vehicle: " + describe(error)); }
  });
  Open77.on("hud:hide", function () {
    try { hide(); } catch (error) { report("hide: " + describe(error)); }
  });

  /* Emitted whatever happened above: Lua drops every message until it lands. */
  try { Open77.ready(); } catch (error) { report("ready: " + describe(error)); }
  Open77.emit("hud:ready", {});
})();
