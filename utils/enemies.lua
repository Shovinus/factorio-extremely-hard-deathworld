enemies = {}
local e = require("utils.event")
local g = require("utils.general")
local time_til_100_evo = 7 * 60 * 60 * 60 -- 7 hours
spitter_death_records = 20
max_path_deviation = 300
storage.enemy_check_offset = 1
qualities_map = { "normal", "uncommon", "rare", "epic", "legendary" }

-- Weight table based on the evolution factor (0 to 1)
weight_table = {
    { 100, 0,  0,  0,  0 },  -- 0.0
    { 90,  10, 0,  0,  0 },  -- 0.1
    { 70,  30, 0,  0,  0 },  -- 0.2
    { 30,  50, 20, 0,  0 },  -- 0.3
    { 0,   70, 30, 0,  0 },  -- 0.4
    { 0,   50, 40, 10, 0 },  -- 0.5
    { 0,   30, 60, 10, 0 },  -- 0.6
    { 0,   20, 50, 30, 0 },  -- 0.7
    { 0,   0,  40, 50, 10 }, -- 0.8
    { 0,   0,  20, 60, 20 }, -- 0.9
    { 0,   0,  10, 20, 80 }  -- 1.0
}

function increase_biter_hp()
    local hp = storage.biter_hp
    local pcent = storage.biter_hp_base_modifier
    local s_hp = storage.biter_initial_hp
    local t_hp = storage.biter_target_hp
    -- Increase the biter hp by a percentage of the difference between the target hp and the current hp
    storage.biter_hp = hp * (1 + (pcent - (pcent * ((hp - s_hp) / (t_hp - s_hp)))))
end

local biter_names = { "small-biter", "medium-biter", "big-biter", "behemoth-biter" }
local spitter_names = { "small-spitter", "medium-spitter", "big-spitter", "behemoth-spitter" }
local spitter_to_worm_conversion_map = {
    ["small-spitter"] = "small-worm-turret",
    ["medium-spitter"] = "medium-worm-turret",
    ["big-spitter"] = "big-worm-turret",
    ["behemoth-spitter"] = "behemoth-worm-turret"
}
local kills_min = 180
local kills_max = 220

local function fixBoundingBox(entity)
    local bb = entity.bounding_box
    bb.left_top.x = bb.left_top.x - entity.position.x
    bb.left_top.y = bb.left_top.y - entity.position.y
    bb.right_bottom.x = bb.right_bottom.x - entity.position.x
    bb.right_bottom.y = bb.right_bottom.y - entity.position.y
    return bb
end


local function fill_closest_water_tile(start_pos, end_pos, surface)
    local x0, y0 = start_pos.x, start_pos.y
    local x1, y1 = end_pos.x, end_pos.y

    x0 = math.floor(x0)
    y0 = math.floor(y0)
    x1 = math.floor(x1)
    y1 = math.floor(y1)

    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)

    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1

    local err = (dx > dy and dx or -dy) / 2
    while true do
        -- Check if the current tile is water
        local tile = surface.get_tile(x0, y0)
        if tile and tile.valid and tile.prototype.collision_mask.layers["water_tile"] then
            for i = -2, 2 do
                for j = -2, 2 do
                    local tile = surface.get_tile(x0 + i, y0 + j)
                    if tile and tile.valid and tile.prototype.collision_mask.layers["water_tile"] then
                        --surface.set_tiles({ { name = "water-shallow", position = { x0 + i, y0 + j } } })
                        surface.set_tiles({ { name = "landfill", position = { x0 + i, y0 + j } } })
                    end
                end
            end
        end


        -- Break the loop if we've reached the end position
        if x0 == x1 and y0 == y1 then break end

        -- Move to the next position
        local e2 = err
        if e2 > -dx then
            err = err - dy
            x0 = x0 + sx
        end
        if e2 < dy then
            err = err + dx
            y0 = y0 + sy
        end
    end
end
local function send_group_to_spitter_death(group)
    -- Get the x and y positions of the event group
    local x = group.position.x
    local y = group.position.y

    -- Loop through the storage.u table to calculate distances
    local min_distance = 100000
    local min_location = 1
    for i = 1, spitter_death_records do
        local dx = x - storage.u[i][1]
        local dy = y - storage.u[i][2]
        local distance = (dx * dx) + (dy * dy)
        if distance < min_distance then
            min_distance = distance
            min_location = i
        end
    end
    local destination = storage.u[min_location]
    -- If the destination is 0,0, send the group to spawn as normal
    if destination[1] == 0 and destination[2] == 0 then
        send_group_to_spawn(group)
        return
    end

    local biters = {}
    local spitters = {}

    -- Loop through all members of the group and separate biters fropitters
    local members = group.members
    for i = #members, 1, -1 do
        local unit = members[i]
        if unit.name:find("spitter") then
            spitters[#spitters + 1] = unit
        else
            biters[#biters + 1] = unit
        end
    end
    -- If the group has no spitters, send it to spawn
    if #spitters == 0 then
        send_group_to_spawn(group)
        return
    end
    -- If the group has biters, create a new group and move the biters to it
    if #biters > 0 then
        local new_group = group.surface.create_unit_group({ position = group.position, force = group.force })
        -- Loop through all members of the group and move biters to the new group
        for i = #members, 1, -1 do
            local unit = members[i]
            -- Assuming biters are identified by "biter" in their unit name/type (adjust this condition if necessary)
            if unit.name:find("biter") then
                new_group.add_member(unit) -- Remove the biter from the original group
            end
        end
        send_group_to_spawn(new_group)
    end
    local command = {
        type = defines.command.compound,
        structure_type = defines.compound_command.logical_or,
        commands =
        {
            { type = defines.command.build_base, destination = storage.u[min_location], distraction = defines.distraction.none, ignore_planner = true }
        }
    }
    --reset the location to 0,0 (to avoid continously sending these groups to the same location)
    storage.u[min_location] = { 0, 0 }
    group.set_command(command)
end
e.on(e.s.on_script_path_request_finished, function(event)
    --try to get the original path request
    if (storage.current_pathfinding[event.id] == nil) then
        return
    end
    local start = storage.current_pathfinding[event.id]
    if event.path == nil and not event.try_again_later then
        -- draw a line from the start to the end of the path and try to find water_tiles in the path
        fill_closest_water_tile(start, { x = 0, y = 0 }, game.surfaces[1])
    elseif event.path ~= nil then
        local path = event.path

        local _end = { x = 0, y = 0 }
        -- Iterate over every 32th node to reduce processing overhead
        for i = 1, #path, 32 do
            local node = path[i].position

            -- Calculate the perpendicular distance from the node to the straight line
            local dx = _end.x - start.x
            local dy = _end.y - start.y
            local len_squared = dx * dx + dy * dy

            if len_squared > 0 then
                local t = ((node.x - start.x) * dx + (node.y - start.y) * dy) / len_squared
                t = math.max(0, math.min(1, t)) -- Clamp t to [0, 1]

                local closest_x = start.x + t * dx
                local closest_y = start.y + t * dy

                local deviation_dx = node.x - closest_x
                local deviation_dy = node.y - closest_y
                local deviation_distance = math.sqrt(deviation_dx * deviation_dx + deviation_dy * deviation_dy)

                -- Check if the deviation exceeds the allowed maximum
                if deviation_distance > max_path_deviation then
                    -- Draw a line from start to end and try to fill water tiles
                    fill_closest_water_tile(start, { x = 0, y = 0 }, game.surfaces[1])
                    break
                end
            end
        end
    end
    storage.current_pathfinding = nil
end)
e.on(e.s.on_unit_group_finished_gathering, function(event)
    local group = event.group
    if (group.is_script_driven) then
        --We already set the commands for this group
        return
    end
    -- Rebuild the group because if you try to command it as is, it will fail silently
    local members = group.members
    local new_group = group.surface.create_unit_group({ position = group.position, force = group.force })

    for i = #members, 1, -1 do
        local unit = members[i]
        new_group.add_member(unit)
    end

    if math.random(1, 3) ~= 2 and false then
        send_group_to_spawn(new_group)
    else
        send_group_to_spitter_death(new_group)
    end
end)

enemies.getBiterKills = function()
    local killStats = game.forces["player"].get_kill_count_statistics(1)
    local kills = 0
    local biters = biter_names
    for i = 1, #biters do
        kills = kills + killStats.get_flow_count {
            category = "output",
            name = biters[i],
            input = true,
            precision_index = defines.flow_precision_index.ten_minutes
        }
    end
    return kills
end
function send_group_to_spawn(group)
    local evo = game.forces["enemy"].get_evolution_factor(1)
    local sample_entity = group.members[1]
    if sample_entity == nil then
        return
    end
    -- Check if there's already a pathfinding request in progress
    if storage.current_pathfinding == nil and evo > 0.00 then
        -- Request a path from the sample entity's position to {0, 0}
        local pathrequest                        = game.surfaces[1].request_path({
            bounding_box = fixBoundingBox(sample_entity),
            collision_mask = sample_entity.prototype.collision_mask,
            start = sample_entity.position,
            goal = { x = 0, y = 0 },
            force = sample_entity.force,
            radius = 1, -- Define the clearance around obstacles

        })
        storage.current_pathfinding              = {}
        storage.current_pathfinding[pathrequest] = sample_entity.position
    end
    local command = {
        type = defines.command.compound,
        structure_type = defines.compound_command.return_last,
        commands =
        {
            {
                type = defines.command.go_to_location,
                destination = g.add_random_offset(64, { 0, 0 }),
                distraction = defines.distraction.by_anything,

            },
            { type = defines.command.wander,     radius = 1,                     wander_in_group = true,                 ticks_to_wait = 10,   distraction = defines.distraction.none },
            { type = defines.command.build_base, destination = { x = 0, y = 0 }, distraction = defines.distraction.none, ignore_planner = true }
        }
    }
    group.set_command(command)
end

function get_quality()
    local qualities_map = { "normal", "uncommon", "rare", "epic", "legendary" }
    if (storage.hard_mode) then


        -- Get the evolution factor
        local evolution = game.forces["enemy"].get_evolution_factor()
        local evolution_index = evolution * 10                       -- Convert 0-1 range to 0-10 range
        local lower_index = math.floor(evolution_index) + 1          -- Floor and convert to 1-based index
        local upper_index = math.min(lower_index + 1, #weight_table) -- Ensure it's within bounds
        local interp_factor = evolution_index % 1                    -- Fractional part for interpolation

        -- Ensure lower_index is within bounds
        lower_index = math.max(1, math.min(lower_index, #weight_table))

        -- Get the two closest weight distributions
        local lower_weights = weight_table[lower_index]
        local upper_weights = weight_table[upper_index]

        -- Interpolate between the two weight distributions
        local interpolated_weights = {}
        local total_weight = 0
        for i = 1, #lower_weights do
            local weight = lower_weights[i] * (1 - interp_factor) + upper_weights[i] * interp_factor
            table.insert(interpolated_weights, weight)
            total_weight = total_weight + weight
        end

        -- Perform weighted random selection
        local random_value = math.random() * total_weight
        local cumulative_weight = 0

        for i, weight in ipairs(interpolated_weights) do
            cumulative_weight = cumulative_weight + weight
            if random_value <= cumulative_weight then
                return prototypes.quality[qualities_map[i]]
            end
        end
    else
        -- make quality based on the number of planets touched
        p = storage.exhd_game_progress.planets_touched
        p = p + 1
        if (p > #qualities_map)
        then
            p = #qualities_map
        end

        return prototypes.quality[qualities_map[1]]
    end
end

e.on(e.s.on_entity_spawned, function(event)
    local entity = event.entity
    if entity.force.name == "enemy" then
        if entity.type == "unit" then
            newenemy = game.surfaces[1].create_entity {
                name = entity.name,
                position = entity.position,
                force = "enemy",
                direction = entity.direction,
                quality = get_quality(),
                color = { r = 0.5, g = 0, b = 0, a = 0.5 }
            };
            newenemy.commandable.set_command(entity.commandable.command)
            newenemy.color = { r = 0.5, g = 0, b = 0, a = 0.5 }
            entity.destroy()
        end
    end
end)


e.nth_tick(60 * 60, function()
    ---------------------------------------
    local evo = game.forces["enemy"].get_evolution_factor(1)
    local kills = enemies.getBiterKills()
    local ticks = storage.time
    local pollution = game.get_pollution_statistics(1).get_flow_count {
        category = "output",
        name = "biter-spawner",
        output = true,
        precision_index = defines.flow_precision_index.ten_minutes
    }

    local evo = game.forces["enemy"].get_evolution_factor(1)
    if (evo > 0.95) then
        increase_biter_hp()
    end

    -- iterate through the storage.no_regen_biters and remove any invalid entries
    for unit_number, biter in pairs(storage.no_regen_biters) do
        if not biter.entity.valid then
            storage.no_regen_biters[unit_number] = nil
        end
    end

    if (storage.exhd_game_progress.nauvis_launch) then
        return;
    end
    --if hardmode is on increase the size of the settler groups after 10 minutes, otherwise after 30 minutes
    --Disabled hardmode affecting the biter size
    if ((ticks > 10 * 60 * 60 and storage.hard_mode and false) or ticks > 30 * 60 * 60) then
        --Start adjusting the pollution consumption modifier after 10 minutes in hardmode and 30 minutes in normal mode
        if pollution > 1 then
            local current_modifier = game.map_settings.pollution.enemy_attack_pollution_consumption_modifier
            if kills < kills_min then
                -- Decrease the pollution consumption modifier by 5% if the player has killed less than 250 biters in the last 10 minutes
                game.map_settings.pollution.enemy_attack_pollution_consumption_modifier = math.max(
                    current_modifier * 0.95, 0.01)
            elseif kills > kills_max then
                game.map_settings.pollution.enemy_attack_pollution_consumption_modifier = math.min(
                    game.map_settings.pollution.enemy_attack_pollution_consumption_modifier / 0.95, 1.5)
            end
        end
        game.map_settings.enemy_expansion.settler_group_min_size = 60
        game.map_settings.enemy_expansion.settler_group_max_size = 70
    elseif (ticks > 10 * 60 * 60) then -- if hardmode is off increase the size of the settler groups slightly after 10 minutes
        game.map_settings.enemy_expansion.settler_group_min_size = 20
        game.map_settings.enemy_expansion.settler_group_max_size = 22
    end
end)
e.nth_tick(60, function()
    -- Check if there are any worms or spawners in the spawn area
    local count = game.surfaces[1].count_entities_filtered { area = { left_top = { x = -32, y = -32 }, right_bottom = { x = 32, y = 32 } }, type = { "turret", "unit-spawner" } }
    local was_counting = storage.count_down < storage.count_down_start
    -- If there are any worms or spawners in the spawn area, start counting down, if not reset the countdown
    if (count > 0) then
        storage.count_down = storage.count_down - 1
    else
        storage.count_down = storage.count_down_start
    end
    local current_tick = storage.time
    local evo = current_tick / time_til_100_evo
    if (evo > 1) then
        evo = 1
    end
    game.forces["enemy"].set_evolution_factor(evo)
    if (was_counting and storage.count_down == storage.count_down_start) then
        -- If we were counting and now we are not, tell the players that the countdown has been reset
        game.print(
            "[color=green][font=default-large-bold]Countdown reset, all worms and spawners destroyed[/font][/color]")
    elseif (not was_counting and storage.count_down < storage.count_down_start) then
        -- If we were not counting and now we are, tell the players that the countdown has started
        game.print("[color=orange][font=default-large-bold]WARNING: Worms and spawners detected, " ..
            storage.count_down_start .. " seconds until reset[/font][/color]")
    elseif (storage.count_down == 10) then
        -- If we are 10 seconds away from resetting, tell the players
        game.print("[color=red][font=default-large-bold]10 seconds left[/font][/color]")
    elseif (storage.count_down == 0) then
        -- If the countdown has reached 0, reset the game
        storage.count_down = storage.count_down_start
        reset("Worms and spawners overtook the spawn area")
    end
end)
--Randomly creates a grenade when a spitter dies and marks the position
e.on(e.s.on_entity_died,
    function(event)
        if math.random(1, 5) == 2 then
            local entity_position = event.entity.position
            local rand = math.random(1, spitter_death_records)
            event.entity.surface.create_entity {
                name = "grenade",
                target = entity_position,
                speed = 0,
                position = entity_position,
                force = "enemy" }
            storage.u[rand][1] = entity_position.x
            storage.u[rand][2] = entity_position.y
        end
    end,
    {
        { filter = "name", name = "behemoth-spitter" },
        { filter = "name", name = "big-spitter" },
        { filter = "name", name = "medium-spitter" },
        { filter = "name", name = "small-spitter" }
    }
)
--
e.on(e.s.on_entity_damaged, function(event)
    -- If the biter is not in the no_regen list, add it
    if not storage.no_regen_biters[event.entity.unit_number] then
        storage.no_regen_biters[event.entity.unit_number] = { entity = event.entity, last_health = 3000 }
    end

    local previous_health = storage.no_regen_biters[event.entity.unit_number].last_health
    local damage = event.final_damage_amount
    -- Reduce incoming damage
    local reduced_damage = damage * (1 / (storage.biter_hp / 3000))


    --convert the entity to string
    event.entity.health = previous_health - reduced_damage
    storage.no_regen_biters[event.entity.unit_number].last_health = event.entity.health
    if event.entity.health <= 0 then
        storage.no_regen_biters[event.entity.unit_number] = nil
    end
end, { { filter = "name", name = "behemoth-biter" } }
)
-- Make worms more vunerable to artillery and grenades to counter the worm rush strategy
e.on(e.s.on_entity_damaged, function(event)
        -- check if the damage was caused by artillery or artillery wagon
        if (event.cause ~= nil and (event.cause.name == "artillery-turret" or event.cause.name == "artillery-wagon")) then
            -- get all nearby worms within a radius of 20 tiles
            local worms = event.entity.surface.find_entities_filtered { position = event.entity.position, radius = 20, type = "turret" }
            -- loop through all worms
            for _, worm in pairs(worms) do
                worm.die(event.cause.force, event.cause)
            end
        elseif (event.damage_type.name == "explosion") then
            -- grenade damage increasing
            local damage = event.final_damage_amount
            local original_damage = event.original_damage_amount
            local reduced_damage = original_damage - damage
            --reduce resistance
            local adjusted_damage = damage + (reduced_damage / 2)
            --4x dmg
            local increased_damage = adjusted_damage * 100

            --reset health to previous value
            event.entity.health = event.entity.health + event.final_damage_amount
            -- remove the modified health
            event.entity.health = event.entity.health - increased_damage
        end
    end,
    { { filter = "name", name = "small-worm-turret" }, { filter = "name", name = "medium-worm-turret" }, { filter = "name", name = "big-worm-turret" }, { filter = "name", name = "behemoth-worm-turret" } })

e.on(e.s.on_build_base_arrived, function(event)
    if (event.group.command ~= nil and
            event.group.command.commands ~= nil)
    then
        --get last command
        local command = event.group.command.commands[#event.group.command.commands]
        -- check is not heading to 0,0
        if (command ~= nil and
                command.type == defines.command.build_base and not
                (command.destination.x == 0 and
                    command.destination.y == 0)) then
            --Spitter death group arrived, convert all spitters to worms
            local surface = game.surfaces[1]
            local group = event.group
            local members = group.members
            local converted_units = 0
            for i = #members, 1, -1 do
                local retries = 0
                local unit = members[i]
                --confirm in the conversion map
                if spitter_to_worm_conversion_map[unit.name] and converted_units < (storage.time / (3600 * 30)) then
                    converted_units = converted_units + 1
                    -- attempt to place the worm within the radius`
                    local new_pos = g.add_random_offset(15, unit.position)
                    surface.create_entity { name = spitter_to_worm_conversion_map[unit.name],
                        position = new_pos, force = unit.force, quality = unit.quality }
                end
                unit.destroy()
            end
        end
    end
end)



return enemies
