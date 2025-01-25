local welcome = {}

-- Function to show the welcome popup
function welcome.show_welcome_popup(player)
    -- Destroy any existing GUI (just in case)
    if player.gui.center.welcome_popup then
        player.gui.center.welcome_popup.destroy()
    end

    -- Create a new frame in the center of the screen
    local frame = player.gui.center.add {
        type = "frame",
        name = "welcome_popup",
        caption = "[color=orange][font=default]Welcome to[/font][/color] [color=#c44747][font=default-bold]Extremely Hard Deathworld![/font][/color]",
        direction = "vertical"
    }

    local framewidth = 480
    -- Create labels and set the style to allow text wrapping
    local label1 = frame.add { type = "label", caption = "[color=#d4aa00][font=default]This server, created by Atraps003, offers a unique and challenging experience.[/font][/color]" }
    label1.style.single_line = false
    label1.style.maximal_width = framewidth

    frame.add { type = "label", caption = " " } -- Empty label to create a blank line

    local label2 = frame.add { type = "label", caption = "[color=#99ff99][font=default-bold]The biter logic, health, and other mechanics are overhauled. [/font][/color][color=#99ff99][font=default]Many vanilla tactics will not work in this map. New players are encouraged to listen to seasoned players and admins for advice.[/font][/color]" }
    label2.style.single_line = false
    label2.style.maximal_width = framewidth


    frame.add { type = "label", caption = " " } -- Empty label to create a blank line

    local label3 = frame.add { type = "label", caption = "[color=#99ff99][font=default]The server has 2 game modes (hardmode on/off), this mode is shown on server reset, or type /mode to see the current mode. During the week hardmode is normally off so that smaller groups have a chance to win, and at the weekends we group up to take on the harder mode :). Don't be fooled though even with hardmode off its no picnic.[/font][/color]" }
    label3.style.single_line = false
    label3.style.maximal_width = framewidth

    frame.add { type = "label", caption = " " } -- Empty label to create a blank line

    local label4 = frame.add { type = "label", caption = "[font=default][color=#7dbfcf]For more guidance and community support, join our Discord![/color][/font]" }
    label4.style.single_line = false
    label4.style.maximal_width = framewidth

    local label5 = frame.add { type = "label", caption = "[color=#4c8abf][font=default]Discord: https://discord.gg/KkgVVMcbqn (https://bit.ly/ExHD)[/font][/color]" }
    label5.style.single_line = false
    label5.style.maximal_width = framewidth


    frame.add { type = "label", caption = " " } -- Empty label to create a blank line
    local flow = frame.add { type = "flow", direction = "horizontal" }
    flow.style.horizontally_stretchable = true
    flow.style.horizontal_align = "right"

    -- Right-aligned text within the flow
    flow.add { type = "label", caption = "[color=#444444][font=default]The factory must grow.     [/font][/color]" }
    flow.add { type = "button", name = "close_welcome_popup", caption = "[font=default-bold]Close[/font]" }
end

-- Event handler for when a player joins the game
function welcome.on_player_joined(event)
    local player = game.get_player(event.player_index)

    -- Check if the player is joining for the first time
    if not storage.joined_players then
        storage.joined_players = {}
    end

    -- If the player is not in the joined list, show the pop-up
    if not storage.joined_players[player.name] then
        storage.joined_players[player.name] = true
        welcome.show_welcome_popup(player) -- Show the welcome popup
    end
end

-- Event handler for clicking buttons in the GUI
function welcome.on_gui_click(event)
    local player = game.get_player(event.player_index)
    if (event.element.valid == false) then return end

    if event.element.name == "close_welcome_popup" then
        if player.gui.center.welcome_popup then
            player.gui.center.welcome_popup.destroy() -- Close the popup
        end
    end
end

commands.add_command("welcome", "Open the welcome message", function(cmd)
    local player = game.players[cmd.player_index]
    welcome.show_welcome_popup(player)
end)
commands.add_command("mode", "Show the current mode", function(cmd)
    local player = game.players[cmd.player_index]
    player.print(string.format("[color=yellow]Hardmode is currently [/color][color=%s[/color]",
        storage.hard_mode and "red]on" or "green]off"))
end)


return welcome
