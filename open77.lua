--- @author DemiAutomatic
--- @file open77.lua
--- @description Resource manifest declaring scripts, permissions and reload policy.

resource "opx77_hud"
version "0.7.0"
open77_version ">=0.0.1"
auto_start true

reload_policy "reconnect"

shared_script "config.lua"
shared_script "shared/locale.lua"
shared_script "locales/en.lua"
shared_script "locales/fr.lua"

server_script "server/main.lua"

client_script "client/state.lua"
client_script "client/vanilla.lua"
client_script "client/keys.lua"
client_script "client/main.lua"
client_script "client/exports.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

permissions {
  "network.events",
  "ui.vanilla.hud",
  "input.actions",
}
