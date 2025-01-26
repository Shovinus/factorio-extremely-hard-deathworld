-- hud.lua

local hud = {}


-- Function to create the top-left button for admins
function hud.create_top_left_gui(player)
    local top_panel = player.gui.top.top_panel
    if not top_panel then
        top_panel = player.gui.top.add { type = "flow", name = "top_panel", direction = "vertical" }
        -- Create the top-left panel
        local info = top_panel.add { type = "label", name = "top_panel_info", caption = "" }
        info.style.single_line = false
    end
    -- Control the admin button
    if not player.admin then
        -- If the panel already exists, destroy it
        if player.gui.top.top_panel.admin_open_panel_button then
            player.gui.top.top_panel.admin_open_panel_button.destroy()
        end
    else
        -- Check if the button already exists; if not, create it
        if not player.gui.top.top_panel.admin_open_panel_button then
            -- Add a button that opens the admin panel
            top_panel.add { type = "button", name = "admin_open_panel_button", caption = "Admin Panel", index = 1}
        end
    end
    
    local evolution_factor = game.forces["enemy"].get_evolution_factor(1) * 100 -- Convert to percentage


    local biter_hp = storage.biter_hp;
    -- convert ticks to friendly time
    local ticks = game.ticks_played
    local seconds = ticks / 60
    local minutes = seconds / 60
    local hours = minutes / 60
    local days = hours / 24
    local time_played = string.format("%d days %d:%02d:%02d", days, hours % 24, minutes % 60, seconds % 60)
    -- Update the evolution factor and biter HP labels
    local info_string = string.format([[
    Time: %s
    Evolution: %.2f%%
    Biter HP: %d
    ]],
        time_played,
        evolution_factor,
        biter_hp
    )
    player.gui.top.top_panel.top_panel_info.caption = info_string
end

--every second update the admin panel with stats
script.on_nth_tick(30, function()
    for _, player in pairs(game.players) do
        hud.create_top_left_gui(player)
    end
end)

-- Event handler for when a player joins the game
function hud.on_player_joined(event)
    local player = game.players[event.player_index]
    hud.create_top_left_gui(player)
end
return hud
