# opx77_hud

> [!WARNING]
> **This project is currently in early development and is not considered production-ready.**
>
> The API, architecture, features, and internal systems are subject to change at any time
> without prior notice. Breaking changes may be introduced as development progresses.
>
> **Do not rely on the current API for production resources yet.**

The player HUD for **Opx77**. Health, armour, stamina and needs as segmented gauges in the
bottom-left corner, plus a bare read-out of money, job and street cred in the top-right, and
the status chip strip that `opx77_status` publishes.

It reads `opx77_core` and `opx77_status` and draws. It decides nothing and writes nothing.

## Features

- Hidden on connection, up once a character is selected, down again on logout
- A `/hud` command and a rebindable key, F8 by default, so a player can hide it; the choice
  survives a character switch
- Segmented gauges that read at a glance over a moving scene
- Fails quiet: a source that is not running costs a log line, not a broken screen
- Turns the game's own HUD off at boot, so its health bar and clock are not drawn under this one

## Commands

One, and it is open to every player: hiding your own HUD is not an operator action.

| Command | Gated |
|---|---|
| `/hud [on\|off]` | open -- omit the argument to toggle |

The name is yours to change in `config.lua`, and `COMMAND = false` registers nothing. It is
registered from the server half because the Open77 client runtime installs no
`RegisterCommand`.

An argument it does not recognise is answered with a warning toast carrying the usage, raised
through `opx77_notify` by the client half; showing or hiding answers nothing, since the HUD
going up or down is the answer. `opx77_notify` stays optional: while it is stopped, or with
`NOTIFY = false`, the same text is a chat line instead, and the client log says so once.

## Keys

| Mapping id | Name in the pause menu | Default | Does |
|---|---|---|---|
| `opx77_hud.toggle` | *HUD: show or hide* | `F8` | what `/hud` with no argument does |

The key is declared with `RegisterKeyMapping`, so the pause menu's key bindings tab lists it
under the name above — read from the configured locale when the resource starts — and every
player can rebind it there; it needs the `input.actions` capability, which the manifest
declares. It toggles on the client, without the round trip the command makes,
and a press while another surface holds the keyboard — the chat box, a form, the pause menu —
does nothing. `KEYS.TOGGLE` in `config.lua` sets the default, which a player's own rebind
overrides; `KEYS.TOGGLE = false` registers no mapping, and a value that is neither a key name
nor `false` is a client log warning and the default. F8 sits clear of the keys the rest of a
stock resource set takes: F2 wardrobe, F3 animation picker, F6 perspective, F9 staff menu,
F11 voice mode, X stop animation, V push-to-talk, ALT context menu.

## Exports

Client exports, all of them returning a table with `ok`.

- `setVisible(value)` -- show (`true`) or hide (`false`) the HUD; answers with the resulting
  visibility.
- `isVisible()` -- whether the HUD is up.
- `vanilla()` -- what became of the game's own HUD on this client. Read-only.

For a cutscene or a full-screen menu, hide it and show it again after. Nothing may set the
game's own HUD through an export: this resource hides it because it draws the replacement.

## Where the values come from

Two resources, and neither is written to.

| Value | Owner | Read from |
|---|---|---|
| `health`, `armor` | `opx77_core` | `metadata` on the character |
| `money`, `job` | `opx77_core` | the character itself |
| `hunger`, `thirst`, `stamina`, `streetCred` | `opx77_status` | its `getNeeds` export and event |

`opx77_core` is read once at start with its `GetPlayerData` export, to catch up on a character
that loaded before this resource did, and after that only from the client-local
`opx77:client:onPlayerLoaded`, `opx77:client:playerDataChanged` and
`opx77:client:onPlayerUnloaded`. There is no poll behind it: the core resends the whole of
`PlayerData` on every change to health, armour, money and job, and its client half raises
`playerDataChanged` off that. A stop or restart of `opx77_core` raises no unload event, so the
HUD treats that stop as an unload: the character and its needs leave the frame until the core
loads a character again.

`opx77_status` is read the same way: once at start with its `getNeeds` export, and after that
only from the client-local `opx77:status:needs` event, which it raises on every change. The
status chips arrive the same way, on `opx77:status:effects`, capped at twelve per frame; the
strip's own anchor and offset are bounded before they reach the page, since any resource can
raise that name.

`opx77_status` is an optional runtime companion, not a dependency. Where it is absent, stopped
(its `onClientResourceStop` clears them here), or has not answered yet -- a `not_loaded`
refusal, or an event carrying `ready = false` -- the gauges it owns are left out of the frame
entirely rather than drawn at zero, and every other block keeps drawing. An empty hunger bar
is something a player acts on, so it is never shown for a value the HUD does not have.

## The game's own HUD

Left alone, Cyberpunk keeps drawing its own health bar, clock and minimap underneath this one,
so `client/vanilla.lua` hides the components named in `VANILLA` at boot and re-asserts them
when a character loads, because the game brings its HUD back at incarnation. This needs the
`ui.vanilla.hud` capability, which the manifest declares; it is presentation on the client and
nothing here is authoritative.

Each `false` is a hide claim this resource holds; `true` releases only its own claim, so a
component another resource hides stays hidden. The platform releases every claim of this resource
when it stops or reloads, so nothing is put back by hand. A component
name this client does not recognise is a logged warning, and a client whose `Open77.hud`
predates the API is a logged warning too, never a script error -- `exports("vanilla")` is how
you tell those apart.

## Configuration

`config.lua`.

- `ANCHOR` -- corner of the gauge block: `bottom-left`, `bottom-right`, `top-left` or
  `top-right`. Anything else silently falls back to `bottom-left`.
- `WIDTH` -- width of the gauge block, in pixels at a 1920-wide surface.
- `INFO_ANCHOR` -- corner of the money, job and cred lines. The same four values, falling
  back to `top-right`.
- `BLOCKS` -- which blocks are built and in what order: `vitals`, `cyber`, `needs`, `money`,
  `identity`. Remove one to drop it.
- `NEEDS_THRESHOLD` -- hide a need or cyber gauge above this percent, or `false` to always
  show it. Anything that is not a number is read as `false`.
- `LOCALE` -- the catalogue player-facing text is read from: `en` or `fr`.
- `COMMAND` -- the chat command, or `false` for none. See **Commands** above.
- `NOTIFY` -- the command's refusal as an `opx77_notify` toast (`true`, the default), or
  `false` for a chat line. See **Commands** above.
- `KEYS.TOGGLE` -- the show/hide key's default, which each player can rebind in the pause menu,
  or `false` to register no mapping. See **Keys** above.
- `VANILLA` -- the game's own HUD, component by component: `false` hides it, `true` puts it
  back, a removed line leaves that component alone, and `VANILLA = false` leaves the whole
  thing alone. The shipped lines are `minimap`, `compass`, `clock`, `health`, `stamina`,
  `weapon` (the weapon and its ammunition count, together) and `speedometer`.

## Locales

`shared/locale.lua` with `locales/en.lua` and `locales/fr.lua`, selected by `LOCALE` in
`config.lua`. A missing key falls back to `en` and then to the key itself. The catalogue is a
`shared_script` because the `/hud` command is registered server-side. `Open77.log` lines stay
English.

## Architecture

Why the code is written the way it is -- load order, the two sources, the frame signature,
the untrusted status strip, the key, the game's own HUD -- is in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (in French). The LuaLS types and the
signatures of the `OpxHud.*` functions are in `std/` (`std/types.lua` and one stub file per
script); they are never loaded.

## Community & Support

Join the Open77 and Opx77 communities to discover the platform, share your projects, and
connect with other developers.

<!-- TODO: replace with the final URLs before publication. -->

* [Open77](#)
* [Open77 GitHub](#)
* [OPX Discord](#)

## License

opx77_hud is licensed under the [**MIT License**](LICENSE).

Copyright © 2026 **Luis MOUTA**.

<p align="center">
    <sub>opx77_hud is an independent community project and is not affiliated with or
    endorsed by CD PROJEKT RED.</sub>
</p>
