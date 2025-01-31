-- admin.lua

local admin = {}

-- Function to get all admin players
function admin.get_admin_players()
    local admins = {}
    for _, player in pairs(game.players) do
        if player.admin then
            table.insert(admins, player)
        end
    end
    return admins
end

-- Track if the player is holding the custom deconstruction planner
storage.player_holding_custom_planner = storage.player_holding_custom_planner or {}

-- Function to give the player a deconstruction planner with special configuration
local landfill_tile_name = "landfill"

local function give_custom_deconstruction_planner(player)
    -- Ensure the player has space in the cursor (hand)
    if player.clear_cursor() then
        -- Insert a deconstruction planner directly into the player's cursor (hand)
        player.cursor_stack.set_stack("deconstruction-planner")

        -- Configure the deconstruction planner to only target landfill tiles
        local planner = player.cursor_stack
        if planner and planner.is_deconstruction_item then
            -- Set the tile filters to only target landfill
            planner.tile_filters = { landfill_tile_name } -- Set to target only landfill tiles
            planner.entity_filters = {}                   -- Clear
            planner.tile_selection_mode = defines.deconstruction_item.tile_selection_mode.only
            -- Mark that the player is holding the custom deconstruction planner
            storage.player_holding_custom_planner[player.index] = true

            player.print("You have been given a custom deconstruction planner for removing landfill.")
        else
            player.print("Error: Couldn't configure the deconstruction planner.")
        end
    else
        player.print("Error: You must have an empty cursor to receive the deconstruction planner.")
    end
end

-- Event handler to detect when a player changes the item in their hand (cursor stack)
function admin.on_player_cursor_stack_changed(event)
    local player = game.players[event.player_index]

    -- Check if the player was holding the custom deconstruction planner
    if storage.player_holding_custom_planner[player.index] then
        local cursor_stack = player.cursor_stack
        if(cursor_stack == nil) then return end

        -- If the player is no longer holding the custom deconstruction planner
        if not cursor_stack.valid_for_read or cursor_stack.name ~= "deconstruction-planner" then
            storage.player_holding_custom_planner[player.index] = false

            -- Try to delete the custom deconstruction planner from their inventory
            local main_inventory = player.get_main_inventory()
            if main_inventory then
                for i = 1, #main_inventory do
                    local item = main_inventory[i]
                    if item and item.valid_for_read and item.name == "deconstruction-planner" then
                        -- Remove the deconstruction planner
                        main_inventory.remove(item)
                        player.print("The custom deconstruction planner has been removed.")
                        break
                    end
                end
            end
        end
    end
end

-- Store the deconstruction event
function admin.store_deconstruction_event(player_name, area, surface)
    -- Ensure the history exists
    storage.deconstruction_history = storage.deconstruction_history or {}

    -- Add the new deconstruction event to the history
    table.insert(storage.deconstruction_history, {
        player_name = player_name,
        area = area,
        surface = surface
    })

    -- Limit the history to the last 20 entries
    if #storage.deconstruction_history > 20 then
        table.remove(storage.deconstruction_history, 1) -- Remove the oldest entry
    end
end

-- Function to highlight a deconstruction area and render player's name
function admin.highlight_deconstruction_area(surface, area, player_name)
    -- Ensure the surface is valid and check for left_top and right_bottom coordinates
    if not surface or not surface.valid then
        return
    end

    if area and area.left_top and area.right_bottom then
        -- Define the color and duration for the rectangle highlight
        local color = { r = 1, g = 0, b = 0, a = 0.5 } -- Red with some transparency
        local duration_ticks = 60 * 10                 -- 10 seconds

        -- Get all admin players
        local admins = admin.get_admin_players()

        -- Draw a rectangle around the deconstruction area visible only to admins
        rendering.draw_rectangle({
            color = color,
            width = 4,
            filled = false,
            left_top = area.left_top,
            right_bottom = area.right_bottom,
            surface = surface,
            players = admins,             -- Show only to admins
            time_to_live = duration_ticks -- Duration before it disappears
        })

        -- Draw the player's name at the top left of the deconstruction area with 50% transparency
        rendering.draw_text({
            text = player_name,
            surface = surface,
            target = area.left_top,                   -- Position the text at the top-left of the deconstruction area
            color = { r = 1, g = 1, b = 1, a = 0.5 }, -- White color with 50% transparency (alpha = 0.5)
            scale = 1.5,
            players = admins,                         -- Show only to admins
            time_to_live = duration_ticks             -- Duration before it disappears
        })
    end
end

-- Function to show the admin panel with buttons
function admin.show_admin_panel(player)
    -- Ensure the player is an admin
    if not player.admin then return end

    -- Clear existing GUI elements if the panel is already open
    if player.gui.center.admin_panel then
        player.gui.center.admin_panel.destroy()
    end

    -- Create the admin panel
    local frame = player.gui.center.add({
        type = "frame",
        name = "admin_panel",
        direction = "vertical",
        caption = "Admin Tools"
    })

    -- Add one button to display the last 20 deconstruction events
    frame.add({
        type = "button",
        name = "show_last_20_decons",
        caption = "Show Last 20 Deconstructions"
    })

    frame.add({
        type = "button",
        name = "remove_landfill",
        caption = "Remove Landfill",
        tooltip = "Removes up to 20 tiles of landfill with your next deconstruction planner use."
    })

    -- Add a button to execute the /admin command
    frame.add({
        type = "button",
        name = "run_admin_command",
        caption = "/admin info"
    })

    -- Add a close button
    frame.add({
        type = "button",
        name = "close_admin_panel",
        caption = "Close"
    })
end

-- Function to handle GUI click events
function admin.on_gui_click(event)
    local player = game.players[event.player_index]

    -- Handle admin panel close button
    if event.element.name == "close_admin_panel" then
        if player.gui.center.admin_panel then
            player.gui.center.admin_panel.destroy()
        end
        return
    end

    -- Handle showing last 20 deconstructions
    if event.element.name == "show_last_20_decons" then
        -- Loop through the last 20 deconstruction events and highlight each one
        for _, decon_event in ipairs(storage.deconstruction_history or {}) do
            admin.highlight_deconstruction_area(decon_event.surface, decon_event.area, decon_event.player_name)
        end
    end

    -- Handle removing landfill
    if event.element.name == "remove_landfill" then
        player.print("Use the deconstruction planner to remove up to 20 landfill tiles.")
        give_custom_deconstruction_planner(player)
    end

    -- Handle executing /admin command
    if event.element.name == "run_admin_command" then
        game.players[event.player_index].print("You have to type /admin in the chat to execute the command.")
    end

    -- Handle clicking the top-left button to open the admin panel
    if event.element.name == "admin_open_panel_button" then
        admin.show_admin_panel(player)
    end
end

-- Event handler for when a player uses the deconstruction planner
function admin.on_player_deconstructed_area(event)
    local player = game.players[event.player_index]
    local area = event.area
    local surface = event.surface -- Use event.surface directly

    -- Check if surface is valid before proceeding
    if not surface or not surface.valid then
        return
    end

    -- Store the deconstruction event (original logic)
    admin.store_deconstruction_event(player.name, area, surface)

    -- Check if the player is holding the custom deconstruction planner (for landfill removal)
    if storage.player_holding_custom_planner[player.index] then
        local cursor_stack = player.cursor_stack
        if(cursor_stack == nil) then return end
        -- Check if the cursor stack contains the custom deconstruction planner (identified by its tile filter)
        if cursor_stack.valid_for_read and cursor_stack.is_deconstruction_item then
            if cursor_stack.tile_filters and cursor_stack.tile_filters[1] == "landfill" then
                -- Track how many landfill tiles have been changed
                local tiles_changed = 0
                local max_tiles_to_change = 20
                local tiles_to_replace = {}

                -- Iterate over the selected area and find landfill tiles
                for x = math.floor(area.left_top.x), math.ceil(area.right_bottom.x) do
                    for y = math.floor(area.left_top.y), math.ceil(area.right_bottom.y) do
                        local tile = surface.get_tile(x, y)
                        if tile.name == "landfill" and tiles_changed < max_tiles_to_change then
                            -- Replace landfill tile with water
                            table.insert(tiles_to_replace, { name = "water", position = { x, y } })
                            tiles_changed = tiles_changed + 1
                        end
                        -- Stop if we have changed 20 tiles
                        if tiles_changed >= max_tiles_to_change then
                            break
                        end
                    end
                    if tiles_changed >= max_tiles_to_change then
                        break
                    end
                end

                -- Replace the tiles on the surface
                if #tiles_to_replace > 0 then
                    surface.set_tiles(tiles_to_replace)
                    game.print(string.format(
                        "[color=red]%s landfill tiles have been removed and replaced with water by %s.[/color]",
                        tiles_changed, player.name))
                else
                    player.print("No landfill tiles were found in the selected area.")
                end

                -- Remove the custom deconstruction planner from their hand
                player.clear_cursor() -- Clears whatever is in their hand

                -- Optionally, remove it from their inventory too
                local main_inventory = player.get_main_inventory()
                if main_inventory then
                    for i = 1, #main_inventory do
                        local item = main_inventory[i]
                        if item and item.valid_for_read and item.name == "deconstruction-planner" then
                            -- Check if the item has the correct tile filter (landfill)
                            if item.tile_filters and item.tile_filters[1] == "landfill" then
                                -- Remove the custom deconstruction planner from inventory
                                main_inventory.remove(item)
                                player.print("The custom deconstruction planner has been removed from your inventory.")
                                break
                            end
                        end
                    end
                end

                -- Mark that the player is no longer holding the custom planner
                storage.player_holding_custom_planner[player.index] = false
            else
                player.print("You're not holding the custom deconstruction planner.")
            end
        else
            player.print("You're not holding any deconstruction planner.")
        end
    end
end

-- Command to give the player a custom deconstruction planner for landfill removal
commands.add_command("give_landfill_removal_planner", "Gives a deconstruction planner for landfill removal",
    function(cmd)
        local player = game.players[cmd.player_index]
        give_custom_deconstruction_planner(player)
    end)

-- Add a command to open the admin panel
commands.add_command("open_admin_panel", "Open the admin panel", function(cmd)
    local player = game.players[cmd.player_index]
    admin.show_admin_panel(player)
end)


return admin