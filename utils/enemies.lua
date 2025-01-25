enemies = {}
local e = require("utils.event")
local g = require("utils.general")
spitter_death_records = 20



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
local kills_min = 250
local kills_max = 300

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
	local found_water = false
	while true do
		-- Check if the current tile is water
		local tile = surface.get_tile(x0, y0)
		if tile and tile.valid and tile.prototype.collision_mask.layers["water_tile"] then
			found_water = true
			for i = -2, 2 do
				for j = -2, 2 do
					local tile = surface.get_tile(x0 + i, y0 + j)
					if tile and tile.valid and tile.prototype.collision_mask.layers["water_tile"] then
						surface.set_tiles({ { name = "water-shallow", position = { x0 + i, y0 + j } } })
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
e.on(e.s.on_script_path_request_finished,function(event)
	--try to get the original path request
	if (storage.current_pathfinding[event.id] == nil) then
		return
	end
	local path = storage.current_pathfinding[event.id]
	if event.path == nil and not event.try_again_later then
		-- draw a line from the start to the end of the path and try to find water_tiles in the path
		fill_closest_water_tile(path, { x = 0, y = 0 }, game.surfaces[1])
	end
	storage.current_pathfinding = nil
end)
e.on(e.s.on_unit_group_finished_gathering,function(event)
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
	if storage.current_pathfinding == nil and evo > 0.2 then
		-- Request a path from the sample entity's position to {0, 0}
		local pathrequest                        = game.surfaces[1].request_path({
			bounding_box = fixBoundingBox(sample_entity),
			collision_mask = sample_entity.prototype.collision_mask,
			start = sample_entity.position,
			goal = { x = 0, y = 0 },
			force = sample_entity.force,
			radius = 1, -- Define the clearance around obstacles
			pathfind_flags = { low_priority = false }
		})
		storage.current_pathfinding              = {}
		storage.current_pathfinding[pathrequest] = sample_entity.position
	end
	local command = {
		type = defines.command.compound,
		structure_type = defines.compound_command.return_last,
		commands =
		{
			{ type = defines.command.go_to_location, destination = g.add_random_offset(64,{0,0}), distraction = defines.distraction.by_anything, pathfind_flags = { low_priority = true } },
			{ type = defines.command.wander,         radius = 1,                      wander_in_group = true,                        ticks_to_wait = 10,                      distraction = defines.distraction.none },
			{ type = defines.command.build_base,     destination = { x = 0, y = 0 },  distraction = defines.distraction.none,        ignore_planner = true }
		}
	}
	group.set_command(command)
end
e.nth_tick(60 * 60, function()
    ---------------------------------------
    --reset the current pathfinding every minute
    local evo = game.forces["enemy"].get_evolution_factor(1)
    local kills = enemies.getBiterKills()
    local ticks = game.ticks_played
    local pollution = game.get_pollution_statistics(1).get_flow_count {
        category = "output",
        name = "biter-spawner",
        output = true,
        precision_index = defines.flow_precision_index.ten_minutes
    }

    --adjust the evolution factor based on the current evolution

    if(evo < 0.3) then
    elseif (evo < 0.5) then
        game.map_settings.enemy_evolution.time_factor = 0.00056
    elseif (evo < 0.7) then
        game.map_settings.enemy_evolution.time_factor = 0.0008
    elseif (evo < 0.9) then
        game.map_settings.enemy_evolution.time_factor = 0.004
    elseif (evo > 0.95) then
        increase_biter_hp()
    end

    --if hardmode is on increase the size of the settler groups after 10 minutes, otherwise after 30 minutes
    if ((ticks > 10*60*60 and storage.hard_mode) or ticks > 30*60*60) then
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
        game.map_settings.enemy_expansion.settler_group_min_size = 90
        game.map_settings.enemy_expansion.settler_group_max_size = 100
    elseif (ticks > 10*60*60) then -- if hardmode is off increase the size of the settler groups slightly after 10 minutes
        game.map_settings.enemy_expansion.settler_group_min_size = 20
        game.map_settings.enemy_expansion.settler_group_max_size = 22
    end
    -- iterate through the storage.no_regen_biters and remove any invalid entries
    for unit_number, biter in pairs(storage.no_regen_biters) do
        if not biter.entity.valid then
            storage.no_regen_biters[unit_number] = nil
        end
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
e.on(e.s.on_entity_damaged,function(event)
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
            local increased_damage = adjusted_damage * 4

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
                if spitter_to_worm_conversion_map[unit.name] and converted_units < (game.ticks_played / (3600 * 2)) then
                    converted_units = converted_units + 1
                    -- attempt to place the worm within the radius`
                    local new_pos = g.add_random_offset(15,unit.position)
                    surface.create_entity { name = storage.spitter_to_worm_conversion_map[unit.name], 
                    position = new_pos, force = unit.force }
                end
                unit.destroy()
            end
        end
    end
end)



return enemies
