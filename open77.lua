resource "opx77_hud"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true

reload_policy "reconnect" -- the CEF surface is never replaced in place

shared_script "config.lua" -- both halves read it: the layout, and the command name
server_script "server/main.lua" -- the chat command only: there is no client-side RegisterCommand

client_script "client/state.lua"
client_script "client/main.lua" -- after state.lua, because main draws what state holds
client_script "client/exports.lua" -- last: publishing the surface claims it exists

web_ui_page "web/index.html"
web_ui_auto_create false -- created in client/main.lua, so a failure is one logged line
web_files { "web/**" }

-- The /hud answer travelling from this resource's server half to its own client
-- half. Nothing on screen comes over the network: the character is read from
-- opx77_core's client half through an export, which needs no permission.
permissions { "network.events" }
