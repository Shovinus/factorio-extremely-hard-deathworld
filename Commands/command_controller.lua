local admin = require("admin")
local motioner = require("motion")
local welcome = require("welcome")
local hud = require("hud")
local reset_controller = require("reset")

-- Library event integration
local lib = {}

lib.on_gui_click = function (event)
    admin.on_gui_click(event)
    motioner.on_gui_click(event)
    welcome.on_gui_click(event)
end

lib.on_player_joined_game = function (event)
    welcome.on_player_joined(event)
    hud.on_player_joined(event)
end
    
lib.events = {
    [defines.events.on_gui_click] = lib.on_gui_click,
    [defines.events.on_player_joined_game] = lib.on_player_joined_game,
    [defines.events.on_player_deconstructed_area] = admin.on_player_deconstructed_area,
    [defines.events.on_player_cursor_stack_changed] = admin.on_player_cursor_stack_changed,
}
return lib
