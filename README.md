# opx77_hud

> [!WARNING]
> **This project is currently in early development and is not considered production-ready.**
>
> The API, architecture, features, and internal systems are subject to change at any time without prior notice. Breaking changes may be introduced as development progresses.
>
> **Do not rely on the current API for production resources yet.**

The player HUD for **Opx77**. Health, armour, stamina and RAM as segmented gauges in the bottom-left corner, plus a bare read-out of money and job in the top-right.

It reads `opx77_core` and draws. It decides nothing and writes nothing.

## Features

- Hidden on connection, up once a character is selected, down again on logout
- A `/hud` command so a player can hide it, whose choice survives a character switch
- Segmented gauges that read at a glance over a moving scene
- Fails quiet: a core that is not running costs a log line, not a broken screen
- Turns the game's own HUD off at boot, so its health bar and clock are not drawn under this one

## Exports

| Export | Does |
|---|---|
| `setVisible` | show or hide the HUD |
| `isVisible` | whether it is up |
| `vanilla` | what became of the game's own HUD on this client |

For a cutscene or a full-screen menu, hide it and show it again after.

## The game's own HUD

Left alone, Cyberpunk keeps drawing its own health bar, clock and minimap underneath this
one. So the resource that draws the replacement is the resource that turns the original off:
at boot, `client/vanilla.lua` hides the seven components named in `VANILLA`, and re-asserts
them when a character loads, because the game brings its HUD back at incarnation.

```lua
VANILLA = {
  minimap = false, compass = false, clock = false, health = false,
  stamina = false, weapon = false, speedometer = false,
}
```

`false` hides, `true` puts back, a removed line leaves that component alone, and
`VANILLA = false` leaves the whole thing alone. What is restored when this resource stops is
whatever each component was found at, not what is written here -- a component the player's
own settings had off stays off.

This needs the `ui.vanilla.hud` capability, which the manifest declares. It is presentation
on the client that holds it: nothing here is authoritative and none of it is worth trusting
on the server. A client whose `Open77.hud` predates the API is a logged warning rather than
a script error, and `exports("vanilla")` is how you tell that apart from a component that
refused.

## Configuration

`config.lua`. Which gauges are drawn and in what order, where the two anchors sit, the name of the command, and which of the game's own HUD components are hidden.

## Community & Support

Join the Open77 and Opx77 communities to discover the platform, share your projects, and connect with other developers.

<!-- TODO: replace with the final URLs before publication. -->

* [Open77](#)
* [Open77 GitHub](#)
* [OPX Discord](#)

## License

opx77_hud is licensed under the [**MIT License**](LICENSE).

Copyright © 2026 **Luis MOUTA**.

<p align="center">
    <sub>opx77_hud is an independent community project and is not affiliated with or endorsed by CD PROJEKT RED.</sub>
</p>
