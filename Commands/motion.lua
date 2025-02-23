storage.motion_seed = nil
storage.vote_count = nil
storage.last_motion_tick = nil
storage.motion_hardmode = nil


-- Count connected players
-- Evaluate quorum onVote
--


local motioner          = {}
local motion_vote_time  = 3600
local motion_max_time   = 18000
local majority_required = 0.66
storage.motion          = nil
--storage.motion = {
--    seed = nil,
--    hard_mode = false,
--    votes = {}
--}

-- Function to show the admin panel with buttons
function motioner.show_motion_panel(motioner)
    -- Clear existing GUI elements if the panel is already open
    if motioner.gui.center.motion_panel then
        motioner.gui.center.motion_panel.destroy()
    end

    -- Create the motion panel
    local frame = motioner.gui.center.add({
        type = "frame",
        name = "motion_panel",
        direction = "vertical",
        caption = "Start a change map vote"
    })

    --[[ frame.add({
        type = "textfield",
        name = "seed_textfield",
        caption = "Proposed seed",
        tooltip = "Enter the seed you want players to vote for, make blank for random seed",
        text = storage.reset_seed

    })]]
    frame.add({
        type = "checkbox",
        name = "hardmode_toggle",
        caption = "Hardmode",
        state = storage.hard_mode
    })
    -- Add a close button
    frame.add({
        type = "button",
        name = "cancel_motion_button",
        caption = "Cancel"
    })
    -- Add a close button
    frame.add({
        type = "button",
        name = "submit_motion_button",
        caption = "Submit"
    })
end

-- Function to show the admin panel with buttons
function motioner.show_vote_panel(voter)
    -- Clear existing GUI elements if the panel is already open
    if voter.gui.center.vote_panel then
        voter.gui.center.vote_panel.destroy()
    end

    -- Create the motion panel
    local frame = voter.gui.center.add({
        type = "frame",
        name = "vote_panel",
        direction = "vertical",
        caption = "Vote on whether to change map"
    })
    frame.add({
        type = "button",
        name = "no_vote_button",
        caption = "No, don't change map"
    })
    frame.add({
        type = "button",
        name = "yes_vote_button",
        caption = "Yes, change map"
    })
end

-- Function to handle GUI click events
function motioner.on_gui_click(event)
    if (event.element == nil or event.element.valid == false) then return end
    local player = game.players[event.player_index]

    if event.element.name == "cancel_motion_button" then
        if player.gui.center.motion_panel then
            player.gui.center.motion_panel.destroy()
        end
        return
    elseif event.element.name == "submit_motion_button" then
        -- Ensure only the server processes motion creation
        if game.is_multiplayer() and not game.is_server() then return end

        local frame = event.element.parent

        -- Ensure the motion can be submitted
        if storage.time > motion_max_time then
            player.print("You cannot submit a motion after the game is 10 minutes old.")
            frame.destroy()
            return
        end
        if storage.motion and (storage.motion.started + motion_vote_time > storage.time) then
            local seconds_left = math.ceil(((storage.motion.started + motion_vote_time) - storage.time) / 60)
            player.print(string.format("A vote is already in progress. A new vote can be started in %s seconds.",
                seconds_left))
            return
        end

        -- Initialize motion data
        local children = frame.children
        local hardmode = children[1].state

        storage.motion = {
            hard_mode = hardmode,
            votes = {},
            started = storage.time -- Ensure this is set
        }

        -- If fewer than 3 players, auto-pass the motion
        if #game.connected_players < 2 then
            storage.hard_mode = storage.motion.hard_mode
            reset("The motion to change the map has passed.")
            frame.destroy()
            return
        end

        storage.motion.votes[player.name] = true

        -- Ensure GUI updates are synchronized
        for _, pl in pairs(game.connected_players) do
            if pl ~= player then
                game.get_surface(1).create_entity({ name = "dummy-entity", position = { 0, 0 } }) -- Forces sync
                motioner.show_vote_panel(pl)
            end
        end

        frame.destroy()
    elseif event.element.name == "yes_vote_button" then
        if player.gui.top.top_panel.vote_panel then
            player.gui.top.top_panel.vote_panel.destroy()
        end

        if storage.motion == nil or storage.motion.started + motion_vote_time < storage.time then
            player.print("The vote has ended.")
            return
        end

        storage.motion.votes[player.name] = true

        local connected_players_number = #game.connected_players
        local votes_required = math.floor(connected_players_number * majority_required)

        local yes_votes_cast = 0
        for _, vote in pairs(storage.motion.votes) do
            if vote == true then
                yes_votes_cast = yes_votes_cast + 1
            end
        end

        if yes_votes_cast > votes_required then
            storage.hard_mode = storage.motion.hard_mode
            reset("The motion to change the map has passed.")
        end
    elseif event.element.name == "no_vote_button" then
        if player.gui.center.vote_panel then
            player.gui.center.vote_panel.destroy()
        end

        if storage.motion == nil or storage.motion.started + motion_vote_time < storage.time then
            player.print("The vote has ended.")
            return
        end

        storage.motion.votes[player.name] = false
    end
end

-- /change-map will open motion_panel
commands.add_command("change-map", "Open the motion panel", function(cmd)
    local player = game.players[cmd.player_index]
    motioner.show_motion_panel(player)
end)

return motioner
