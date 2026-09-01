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

## Exports

| Export | Does |
|---|---|
| `setVisible` | show or hide the HUD |
| `isVisible` | whether it is up |

For a cutscene or a full-screen menu, hide it and show it again after.

## Configuration

`config.lua`. Which gauges are drawn and in what order, where the two anchors sit, and the name of the command.

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
