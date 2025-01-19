local util = require("util")
local crash_site = require("crash-site")
local spitter_death_records = 20


----We disable victory conditions of silo script because it doesn't work with soft reset
_ENV.no_victory = true
---
_ENV.biter_hp = 3000

_ENV.biter_initial_hp = 3000
_ENV.biter_target_hp_multiplier = 300
_ENV.biter_target_hp = _ENV.biter_target_hp_multiplier * _ENV.biter_initial_hp
_ENV.biter_hp_base_modifier = 0.002

_ENV.extremely_hard_victory = false
_ENV.reset_seed = 987654321
_ENV.reset_seed_delayed = 987654321
_ENV.restart = "false"
_ENV.hard_mode = false
_ENV.spitter_to_worm_conversion_map =
{
	["small-spitter"] = "small-worm-turret",
	["medium-spitter"] = "medium-worm-turret",
	["big-spitter"] = "big-worm-turret",
	["behemoth-spitter"] = "behemoth-worm-turret"
}



local resetVariables = function()
	_ENV.player_state = {}
	_ENV.deconstruction_history = {}
	_ENV.new_map = true
	-- clear globals
	_ENV.extremely_hard_victory = false
	_ENV.latch = 0
	_ENV.u = {}
	for i = 1, spitter_death_records do
		_ENV.u[i] = { 0, 0 }
	end
	_ENV.biter_hp = 3000
	_ENV.kills_min = 250
	_ENV.kills_max = 300
	_ENV.deconstruction_history = {}
	_ENV.no_regen_biters = {}

	-- default starting map settings
	game.map_settings.enemy_evolution.destroy_factor = 0
	game.map_settings.enemy_evolution.pollution_factor = 0
	if _ENV.hard_mode then
		game.map_settings.enemy_evolution.time_factor = 0.00007
		game.map_settings.pollution.enemy_attack_pollution_consumption_modifier = 0.5
	else
		game.map_settings.enemy_evolution.time_factor = 0.00005
		game.map_settings.pollution.enemy_attack_pollution_consumption_modifier = 6
	end
	game.map_settings.enemy_expansion.enabled                                 = true
	game.map_settings.enemy_expansion.max_expansion_cooldown                  = 4000
	game.map_settings.enemy_expansion.min_expansion_cooldown                  = 3000
	game.map_settings.enemy_expansion.settler_group_max_size                  = 11
	game.map_settings.enemy_expansion.settler_group_min_size                  = 10
	game.map_settings.pollution.ageing                                        = 0.5
	game.map_settings.pollution.enabled                                       = true
	game.map_settings.unit_group.max_gathering_unit_groups                    = 30
	game.map_settings.unit_group.max_unit_group_size                          = 150

	-- path finding changes to reduce lag
	game.map_settings.path_finder.general_entity_collision_penalty = 0
	game.map_settings.path_finder.general_entity_subsequent_collision_penalty = 0
	game.map_settings.path_finder.ignore_moving_enemy_collision_distance = 0
	game.map_settings.path_finder.use_path_cache = false
	game.map_settings.path_finder.extended_collision_penalty = 0
	game.map_settings.path_finder.enemy_with_different_destination_collision_penalty = 0
	game.map_settings.path_finder.stale_enemy_with_same_destination_collision_penalty = 0
	game.map_settings.max_failed_behavior_count = 1
end

local default_player_state = function()
	return {
		has_received_starting_items = false
	}
end

local created_items = function()
	return
	{
		["iron-plate"] = 8,
		["wood"] = 1,
		["pistol"] = 1,
		["firearm-magazine"] = 10,
		["burner-mining-drill"] = 1,
		["stone-furnace"] = 1
	}
end

local respawn_items = function()
	return
	{
		["pistol"] = 1,
		["firearm-magazine"] = 5
	}
end

local ship_items = function()
	return
	{
		["firearm-magazine"] = 180,
		["gun-turret"] = 9
	}
end

local debris_items = function()
	return
	{
		["iron-plate"] = 8,
		["burner-mining-drill"] = 30,
		["stone-furnace"] = 20
	}
end

local ship_parts = function()
	return crash_site.default_ship_parts()
end
-----------------------------------------------------------------------------------------------------------------
local change_seed = function()
	local surface = game.surfaces[1]
	local mgs = surface.map_gen_settings
	mgs.seed = _ENV.reset_seed
	surface.map_gen_settings = mgs
end
-------------------------------------------------------------------------------------------------------------------------------

-- Some values need to be reset pre-surface clear, and some need to be set
-- post-surface clear.
--
-- For the most part, settings should be set post-clear, but a few select
-- variables that control how the game behaves during resets, might need special
-- care on when it is called.
local reset_global_setings__pre_surface_clear = function()
	-- Altering tiles during a surface clear causes desyncs, this is a known factorio bug.
	-- See https://forums.factorio.com/viewtopic.php?f=230&t=113601

	-- [on_chunk_generated] checks [converted_shallow_water] to determine if to
	-- convert water tiles immediately. We need to disable this flag before
	-- reset, so that reset chunks are not touch until the surface clear is
	-- fully complete.
	_ENV.new_map = true

	-- We reset time played before clearing the surface. That way,
	-- the periodic check that converts all water tiles does not fire until
	-- after the surface map-generation is fully complete.
	game.reset_time_played()
end

local reset_global_settings__post_surface_clear = function()
	-- clear game statistics
	game.reset_game_state()
	game.forces["enemy"].reset()
	game.forces["enemy"].reset_evolution()
	game.get_pollution_statistics(0).clear()
	resetVariables()



	local surface = game.surfaces[1]
	if math.random(1, 2) == 2 then
		--pitch black nights
		surface.brightness_visual_weights = { 1, 1, 1 }
		surface.min_brightness = 0
		surface.dawn = 0.80
		surface.dusk = 0.20
		surface.evening = 0.40
		surface.morning = 0.60
		surface.daytime = 0.61
		surface.freeze_daytime = false
	else
		--default nights
		surface.brightness_visual_weights = { 0, 0, 0 }
		surface.min_brightness = 0.15
		surface.dawn = 0.80
		surface.dusk = 0.20
		surface.evening = 0.40
		surface.morning = 0.60
		surface.daytime = 0.75
		surface.freeze_daytime = false
	end

	game.forces["enemy"].friendly_fire = false
	game.forces["player"].research_queue_enabled = true
	game.forces["player"].max_failed_attempts_per_tick_per_construction_queue = 2
	game.forces["player"].max_successful_attempts_per_tick_per_construction_queue = 6
	game.difficulty_settings.technology_price_multiplier = 1
	game.difficulty_settings.recipe_difficulty = 0
	surface.solar_power_multiplier = 1
	game.forces["player"].set_turret_attack_modifier("flamethrower-turret", -0.8)
	game.forces["player"].set_turret_attack_modifier("laser-turret", 1.35)
	game.forces["player"].set_gun_speed_modifier("laser", 4)
end

local reset_global_settings = function()
	reset_global_setings__pre_surface_clear()
	reset_global_settings__post_surface_clear()
end

local handle_player_created_or_respawned = function(player_index)
	if(_ENV.player_state == nil) then
		resetVariables()
	end
	local player = game.get_player(player_index)

	if _ENV.player_state[player_index] == nil then
		_ENV.player_state[player_index] = default_player_state()
	end
	local player_state = _ENV.player_state[player_index]

	if player_state.has_received_starting_items == false then
		player_state.has_received_starting_items = true
		util.insert_safe(player, _ENV.created_items)
	else
		util.insert_safe(player, _ENV.respawn_items)
	end
end

local on_player_created = function(event)
	local player = game.get_player(event.player_index)
	local name = player.name
	local x = { ID = (event.player_index - 1), Name = name }
	print(serpent.line(x))

	handle_player_created_or_respawned(event.player_index)

	if not _ENV.init_ran then
		-- This is so that other mods and scripts have a chance to do remote calls before we do things like charting the starting area, creating the crash site, etc.
		_ENV.init_ran = true

		reset_global_settings()

		if not _ENV.disable_crashsite then
			local surface = player.surface
			crash_site.create_crash_site(surface, { -5, -6 }, util.copy(_ENV.crashed_ship_items),
				util.copy(_ENV.crashed_debris_items), util.copy(_ENV.crashed_ship_parts))
		end
	end

	if not _ENV.skip_intro then
		player.print(_ENV.custom_intro_message or { "msg-intro" })
	end
end

local on_player_respawned = function(event)
	handle_player_created_or_respawned(event.player_index)
end
------------------------------------------------------------------------------------------------
function reset(reason)
	local reset_type = nil
	local red = game.forces["player"].item_production_statistics.get_output_count "automation-science-pack"
	if (_ENV.restart == "true") then
		reset_type = "[color=red][font=default-large-bold]Hard reset[/font][/color]"
		game.write_file("reset/reset.log", "restart", false, 0)
	else
		if (red > 0) then
			local victory = _ENV.extremely_hard_victory
			local deaths = game.forces["player"].kill_count_statistics.get_output_count "character"
			local minutes = math.floor((game.ticks_played / 3600) * 10) / 10
			local mode = _ENV.hard_mode and "hard" or "normal"
			local rockets_launched = game.forces["player"].rockets_launched

			local log_message = string.format("%d_%s_%s_%d_%d_%d_%d", _ENV.reset_seed_delayed, mode, tostring(victory),
				red, deaths, minutes, rockets_launched)

			game.write_file("reset/reset.log", log_message, false, 0)
		end
		reset_type = "[color=green][font=default-large-bold]Soft reset[/font][/color]"
		change_seed()
		game.surfaces[1].clear(true)
		game.forces["player"].reset()
	end
	if reason ~= nil then
		game.print(string.format("%s [color=yellow]%s Hardmode is currently [/color][color=%s[/color]", reset_type,
			reason, _ENV.hard_mode and "red]on" or "green]off"))
	end
end

-----------------------------------------------------------------------------------------------
local on_pre_surface_cleared = function(event)
	reset_global_setings__pre_surface_clear()

	-- We need to kill all players _before_ the surface is cleared, so that
	-- their inventory, and crafting queue, end up on the old surface
	for _, pl in pairs(game.players) do
		if pl.connected and pl.character ~= nil then
			-- We call die() here because otherwise we will spawn a duplicate
			-- character, who will carry over into the new surface
			pl.character.die()
		end
		-- Setting [ticks_to_respawn] to 1 seems to consistantly kill offline
		-- players. Calling this for online players will cause them instead be
		-- respawned the next tick, skipping the 10 respawn second timer.
		pl.ticks_to_respawn = 1
		--  Need to teleport otherwise offline players will force generate many chunks on new surface at their position on old surface when they rejoin.
		pl.teleport({ 0, 0 })
	end
end
-----------------------------------------------------------------------------------------------
local on_surface_cleared = function(event)
	reset_global_settings__post_surface_clear()

	local surface = game.surfaces[1]
	surface.request_to_generate_chunks({ 0, 0 }, 6)
	surface.force_generate_chunk_requests()
	crash_site.create_crash_site(surface, { -5, -6 }, util.copy(_ENV.crashed_ship_items),
		util.copy(_ENV.crashed_debris_items), util.copy(_ENV.crashed_ship_parts))
end
------------------------------------------------------------------------------------------
local on_player_toggled_map_editor = function(event)
	_ENV.restart = "true"

	local player = game.get_player(event.player_index)
	reset(string.format("%s has toggled the map editor.", player.name))
end
------------------------------------------------------------------------------------------
local on_console_command = function(event)
	local command = event.command
	local parameters = event.parameters
	print(command)
	print(parameters)

	if (game.console_command_used and _ENV.restart ~= "true") then
		_ENV.restart = "true"
		local name = nil
		if event.player_index ~= nil then
			name = game.get_player(event.player_index).name
		end
		reset(string.format("%s has used a console command.", name or "SERVER"))
	end
end
local function send_group_to_spawn(group)
	local command = {
		type = defines.command.compound,
		structure_type = defines.compound_command.return_last,
		commands =
		{
			{ type = defines.command.go_to_location, destination = { 0, 0 } },
			{ type = defines.command.attack_area,    destination = { 0, 0 }, radius = 16, distraction = defines.distraction.by_anything },
			{ type = defines.command.build_base,     destination = { 0, 0 }, distraction = defines.distraction.none, ignore_planner = true }
		}
	}
	group.set_command(command)
end
local function send_group_to_spitter_death(group)
	-- Get the x and y positions of the event group
	local x = group.position.x
	local y = group.position.y

	-- Loop through the _ENV.u table to calculate distances
	local min_distance = 1000000000
	local min_location = 0
	for i = 1, spitter_death_records do
		local dx = x - _ENV.u[i][1]
		local dy = y - _ENV.u[i][2]
		local distance = (dx * dx) + (dy * dy)
		if distance < min_distance then
			min_distance = distance
			min_location = i
		end
	end
	local destination = _ENV.u[min_location]
	-- If the destination is 0,0, send the group to spawn as normal
	if destination[1] == 0 and destination[2] == 0 then
		send_group_to_spawn(group)
		return
	end

	local biters = {}
	local spitters = {}

	-- Loop through all members of the group and separate biters from spitters
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
		structure_type = defines.compound_command.return_last,
		commands =
		{
			{ type = defines.command.go_to_location, destination = _ENV.u[min_location], distraction = defines.distraction.none },
			{ type = defines.command.build_base,     destination = _ENV.u[min_location], distraction = defines.distraction.none, ignore_planner = true }
		}
	}
	--reset the location to 0,0 (to avoid continously sending these groups to the same location)
	_ENV.u[min_location] = { 0, 0 }
	group.set_command(command)
end
--------------------------------------------------------------------------------------------
local on_unit_group_finished_gathering = function(event)
	--if event.group.command == nil then
	--	send_group_to_spawn(event.group)
	--	return
	--end
	if _ENV.latch == 0 then
		_ENV.latch = 1
	else
		_ENV.latch = 0
		if math.random(1, 3) ~= 2 and false then
			send_group_to_spawn(event.group)
		else
			send_group_to_spitter_death(event.group)
		end
	end
end
-------------------------------------------------------------------------------------------------------
script.on_nth_tick(120, function()
	if _ENV.new_map then
		if game.ticks_played > 100 then
			_ENV.new_map = false
			_ENV.reset_seed_delayed = _ENV.reset_seed
			game.forces["player"].chart(game.surfaces[1], { { x = -400, y = -400 }, { x = 400, y = 400 } })
		end
	end
end)
local increase_biter_hp = function()
	local hp = _ENV.biter_hp
	local pcent = _ENV.biter_hp_base_modifier
	local s_hp = _ENV.biter_initial_hp
	local t_hp = _ENV.biter_target_hp
	-- Increase the biter hp by a percentage of the difference between the target hp and the current hp
	_ENV.biter_hp = hp*(1+(pcent-(pcent*((hp-s_hp)/(t_hp-s_hp)) )))
end
-------------------------------------------------------------------------------------------------------
-- Do adjustments every minute instead of 5 minutes
script.on_nth_tick(3600, function()
	local evo = game.forces["enemy"].evolution_factor
	local kills = game.forces["player"].kill_count_statistics.get_flow_count { name = "medium-biter", input = true, precision_index = defines.flow_precision_index.ten_minutes } +
		game.forces["player"].kill_count_statistics.get_flow_count { name = "big-biter", input = true, precision_index = defines.flow_precision_index.ten_minutes } +
		game.forces["player"].kill_count_statistics.get_flow_count { name = "behemoth-biter", input = true, precision_index = defines.flow_precision_index.ten_minutes } +
		(game.forces["player"].kill_count_statistics.get_flow_count { name = "small-biter", input = true, precision_index = defines.flow_precision_index.ten_minutes } * 0.5)
	local pollution = game.pollution_statistics.get_flow_count { name = "biter-spawner", output = true, precision_index = defines.flow_precision_index.ten_minutes }
	local tpd = ((evo + 1) * 25000)
	game.surfaces[1].ticks_per_day = tpd
	---------------------------------------------------------------------------------------------------------------------------------
	--  local hours = math.floor((game.ticks_played / 216000) * 100) / 100
	--  local rounded_evo = math.floor(evo * 100) / 100
	--  game.write_file("evo", {"",rounded_evo," evo in ",hours," hours\n"}, true,  1)
	---------------------------------------------------------------------------------------------------------------------------------
	if (evo > 0.3 and evo < 0.5) then
		game.map_settings.enemy_evolution.time_factor = 0.00056
	end
	if (evo > 0.5 and evo < 0.7) then
		game.map_settings.enemy_evolution.time_factor = 0.0008
	end
	if (evo > 0.7 and evo < 0.9) then
		game.map_settings.enemy_evolution.time_factor = 0.004
	end
	if (evo > 0.95) then
		increase_biter_hp()
	end


	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	--if hardmode is on increase the size of the settler groups after 10 minutes, otherwise after 30 minutes
	if ((game.ticks_played > 36000 and _ENV.hard_mode) or game.ticks_played > 108000) then
		--Start adjusting the pollution consumption modifier after 10 minutes in hardmode and 30 minutes in normal mode
		if pollution > 1 then
			local current_modifier = game.map_settings.pollution.enemy_attack_pollution_consumption_modifier
			if kills < _ENV.kills_min then
				-- Decrease the pollution consumption modifier by 5% if the player has killed less than 250 biters in the last 10 minutes
				game.map_settings.pollution.enemy_attack_pollution_consumption_modifier = math.max(
					current_modifier * 0.95, 0.01)
			elseif kills > _ENV.kills_max then
				game.map_settings.pollution.enemy_attack_pollution_consumption_modifier = math.min(
					game.map_settings.pollution.enemy_attack_pollution_consumption_modifier / 0.95, 1.5)
			end
		end
		game.map_settings.enemy_expansion.settler_group_min_size = 90
		game.map_settings.enemy_expansion.settler_group_max_size = 100
	elseif (game.ticks_played > 36000) then -- if hardmode is off increase the size of the settler groups after 10 minutes
		game.map_settings.enemy_expansion.settler_group_min_size = 20
		game.map_settings.enemy_expansion.settler_group_max_size = 22
	end
	-- iterate through the _ENV.no_regen_biters and remove any invalid entries
	for unit_number, biter in pairs(_ENV.no_regen_biters) do
		if not biter.entity.valid then
			_ENV.no_regen_biters[unit_number] = nil
		end
	end
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	if game.ticks_played > 36288000 then
		reset("Game has reached its maximum playtime of 7 days.")
	end
end)
----------------------------------------------------------------------------------------------------------------------------------
script.on_event(defines.events.on_entity_died,
	function(event)
		if math.random(1, 5) == 2 then
			local create_entity = game.surfaces[1].create_entity
			local entity_position = event.entity.position
			local rand = math.random(1, spitter_death_records)
			create_entity { name = "grenade", target = entity_position, speed = 1, position = entity_position, force = "enemy" }
			_ENV.u[rand][1] = entity_position.x
			_ENV.u[rand][2] = entity_position.y
		end
	end
)
script.set_event_filter(defines.events.on_entity_died,
	{ { filter = "name", name = "behemoth-spitter" }, { filter = "name", name = "big-spitter" }, { filter = "name", name = "medium-spitter" }, { filter = "name", name = "small-spitter" } })
----------------------------------------------------------------------------------------------------------------------------------
script.on_event(defines.events.on_entity_damaged,
	function(event)
		-- If the biter is not in the no_regen list, add it
		if not _ENV.no_regen_biters[event.entity.unit_number] then
			_ENV.no_regen_biters[event.entity.unit_number] = { entity = event.entity, last_health = 3000 }
		end

		local previous_health = _ENV.no_regen_biters[event.entity.unit_number].last_health
		local damage = event.final_damage_amount
		-- Reduce incoming damage
		local reduced_damage = damage * (1 / (_ENV.biter_hp/3000))


		--convert the entity to string
		event.entity.health = previous_health - reduced_damage
		_ENV.no_regen_biters[event.entity.unit_number].last_health = event.entity.health
		if event.entity.health <= 0 then
			_ENV.no_regen_biters[event.entity.unit_number] = nil
		end
	end,{ {filter = "name", name = "behemoth-biter"} }
)
-- Make worms more vunerable to artillery and grenades to counter the worm rush strategy
script.on_event(defines.events.on_entity_damaged, function(event)
	-- check if the damage was caused by artillery or artillery wagon
	if(event.cause ~= nil and ( event.cause.name == "artillery-turret" or event.cause.name == "artillery-wagon")) then
		-- get all nearby worms within a radius of 20 tiles
		local worms = event.entity.surface.find_entities_filtered { position = event.entity.position, radius = 20, type = "turret" }
		-- loop through all worms
		for _, worm in pairs(worms) do			
			worm.die(event.cause.force, event.cause)
		end
	elseif(event.damage_type.name == "physical" and event.cause and is_player_weapon_shotgun(event.cause.player)) then
		-- shotgun damage increasing
		--local damage = event.original_damage_amount
		--negate resistance
		--local increased_damage = damage * 1
		--event.entity.health = event.entity.health + event.final_damage_amount
		--event.entity.health = event.entity.health - increased_damage
	elseif(event.damage_type.name == "explosion") then
		-- grenade damage increasing
		local damage = event.final_damage_amount
		local original_damage = event.original_damage_amount
		local reduced_damage = original_damage - damage
		--reduce resistance
		local adjusted_damage = damage + (reduced_damage /2)
		--4x dmg
		local increased_damage = adjusted_damage * 4

		--reset health to previous value
		event.entity.health = event.entity.health + event.final_damage_amount
		-- remove the modified health
		event.entity.health = event.entity.health - increased_damage
	end
end, {{ filter = "name", name = "small-worm-turret" }, { filter = "name", name = "medium-worm-turret" }, { filter = "name", name = "big-worm-turret" }, { filter = "name", name = "behemoth-worm-turret" }})
function is_player_weapon_shotgun(player)
	if not player then return false end
    local weapon_inventory = player.get_inventory(defines.inventory.character_guns)
    if weapon_inventory and weapon_inventory[player.character.selected_gun_index].valid_for_read then
        local current_weapon = weapon_inventory[player.character.selected_gun_index]
        
        -- Check if the current weapon is a shotgun
        if current_weapon.name == "shotgun" or current_weapon.name == "combat-shotgun" then
            return true
        end
    end
    return false
end
local function random_offset(radius)
	local angle = math.random() * 2 * math.pi -- Random angle in radians
	local distance = math.random() * radius -- Random distance within the radius
	local x_offset = math.cos(angle) * distance
	local y_offset = math.sin(angle) * distance
	return x_offset, y_offset
end

local on_build_base_arrived = function(event)
	if (event.group.command ~= nil and
			event.group.command.commands ~= nil and
			event.group.command.commands[1].destination.x ~= 0 and
			event.group.command.commands[1].destination.y ~= 0) then
		--Spitter death group arrived, convert all spitters to worms
		local surface = game.surfaces[1]
		local group = event.group
		local members = group.members
		local converted_units = 0
		for i = #members, 1, -1 do
			local retries = 0
			local unit = members[i]
			--confirm in the conversion map
			if _ENV.spitter_to_worm_conversion_map[unit.name] and converted_units < (game.ticks_played / (3600* 2)) then
				converted_units = converted_units + 1
				-- attempt to place the worm within the radius`
				local x_offset, y_offset = random_offset(15) -- 15-tile radius
				local new_pos = { unit.position.x + x_offset, unit.position.y + y_offset }
				local new_unit = surface.create_entity { name = _ENV.spitter_to_worm_conversion_map[unit.name], position = new_pos, force = unit.force }
			end
			unit.destroy()
		end
	end
end
-----------------------------------------------------e-----------------------------------------------
local on_biter_base_built = function(event)
	local oxpos = event.entity.position.x
	local oypos = event.entity.position.y
	if (oxpos > -34 and oxpos < 34 and oypos > -34 and oypos < 34) then
		game.print(
			"[color=acid][font=default-large-bold]Biter nests growing near spawn. Defeat imminent![/font][/color]")
		local nest_count = game.surfaces[1].count_entities_filtered { area = { left_top = { x = -32, y = -32 }, right_bottom = { x = 32, y = 32 } }, type = { "turret", "unit-spawner" } }
		if nest_count > 3 then
			reset("Uh oh... The biters have overtaken your spawn!")
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------------
local on_rocket_launched = function(event)
	if _ENV.extremely_hard_victory == false then
		game.forces["enemy"].kill_all_units()
		game.surfaces[1].clear_pollution()
		game.map_settings.pollution.enabled = false
		_ENV.extremely_hard_victory = true
		game.set_game_state { game_finished = true, player_won = true, can_continue = true, victorious_force = player }
	end
end
-------------------------------------------------------------------------------------------------------------------------------------------
local on_research_finished = function(event)
	game.difficulty_settings.technology_price_multiplier = 1
	game.surfaces[1].solar_power_multiplier = ((game.forces["player"].mining_drill_productivity_bonus * 10) + 1)
	-----------------------------------------------------------------------------------------------------------------------------------------------------------
	if (event.research.name == "laser-shooting-speed-1") then
		game.forces["player"].set_gun_speed_modifier("laser", 5)
	end
	if (event.research.name == "laser-shooting-speed-2") then
		game.forces["player"].set_gun_speed_modifier("laser", 5.1)
	end
	if (event.research.name == "laser-shooting-speed-3") then
		game.forces["player"].set_gun_speed_modifier("laser", 5.2)
	end
	if (event.research.name == "laser-shooting-speed-4") then
		game.forces["player"].set_gun_speed_modifier("laser", 5.3)
	end
	if (event.research.name == "laser-shooting-speed-5") then
		game.forces["player"].set_gun_speed_modifier("laser", 5.4)
	end
	if (event.research.name == "laser-shooting-speed-6") then
		game.forces["player"].set_gun_speed_modifier("laser", 5.5)
	end
	if (event.research.name == "laser-shooting-speed-7") then
		game.forces["player"].set_gun_speed_modifier("laser", 5.6)
	end
	------------------------------------------------------------------------------------
	if (event.research.name == "physical-projectile-damage-1") then
		game.forces["player"].set_turret_attack_modifier("gun-turret", 0)
	end
	if (event.research.name == "physical-projectile-damage-2") then
		game.forces["player"].set_turret_attack_modifier("gun-turret", 0)
	end
	if (event.research.name == "physical-projectile-damage-3") then
		game.forces["player"].set_turret_attack_modifier("gun-turret", 0)
	end
	if (event.research.name == "physical-projectile-damage-4") then
		game.forces["player"].set_turret_attack_modifier("gun-turret", 0)
	end
	if (event.research.name == "physical-projectile-damage-5") then
		game.forces["player"].set_turret_attack_modifier("gun-turret", 0)
	end
	if (event.research.name == "physical-projectile-damage-6") then
		game.forces["player"].set_turret_attack_modifier("gun-turret", 0)
	end
	---------------------------------------------------------------------------------------------------------
	if (event.research.name == "refined-flammables-1") then
		game.forces["player"].set_turret_attack_modifier("flamethrower-turret", -0.79)
	end
	if (event.research.name == "refined-flammables-2") then
		game.forces["player"].set_turret_attack_modifier("flamethrower-turret", -0.78)
	end
	if (event.research.name == "refined-flammables-3") then
		game.forces["player"].set_turret_attack_modifier("flamethrower-turret", -0.76)
	end
	if (event.research.name == "refined-flammables-4") then
		game.forces["player"].set_turret_attack_modifier("flamethrower-turret", -0.73)
	end
	if (event.research.name == "refined-flammables-5") then
		game.forces["player"].set_turret_attack_modifier("flamethrower-turret", -0.7)
	end
	if (event.research.name == "refined-flammables-6") then
		game.forces["player"].set_turret_attack_modifier("flamethrower-turret", -0.65)
	end
	--------------------------------------------------------------------------------------------
	if (event.research.name == "worker-robots-speed-1") then
		game.forces["player"].worker_robots_speed_modifier = 1
		game.forces["player"].worker_robots_battery_modifier = 0.5
	end
	if (event.research.name == "worker-robots-speed-2") then
		game.forces["player"].worker_robots_speed_modifier = 2
		game.forces["player"].worker_robots_battery_modifier = 1
	end
	if (event.research.name == "worker-robots-speed-3") then
		game.forces["player"].worker_robots_speed_modifier = 4
		game.forces["player"].worker_robots_battery_modifier = 2
	end
	if (event.research.name == "worker-robots-speed-4") then
		game.forces["player"].worker_robots_speed_modifier = 7
		game.forces["player"].worker_robots_battery_modifier = 3.5
	end
	if (event.research.name == "worker-robots-speed-5") then
		game.forces["player"].worker_robots_speed_modifier = 12
		game.forces["player"].worker_robots_battery_modifier = 6
	end
end
-------------------------------------------------------------------------------------------
local on_research_cancelled = function(event)
	if event.research[_ENV.research] == 1 then
		game.difficulty_settings.technology_price_multiplier = 1
	end
end
-------------------------------------------------------------------------------------------
local on_research_started = function(event)
	_ENV.research = event.research.name
	if (event.research.name == "nuclear-power") then
		game.difficulty_settings.technology_price_multiplier = 0.5
	end
	if (event.research.name == "spidertron") then
		game.difficulty_settings.technology_price_multiplier = 0.16
	end
	-- Make atomic bomb research 10 times more expensive
	if (event.research.name == "atomic-bomb") then
		game.difficulty_settings.technology_price_multiplier = 10
	end
	if (event.research.name == "artillery") then
		game.difficulty_settings.technology_price_multiplier = 0.2
	end
	if (event.research.name == "uranium-ammo") then
		game.difficulty_settings.technology_price_multiplier = 0.4
	end
	if (event.research.name == "kovarex-enrichment-process") then
		game.difficulty_settings.technology_price_multiplier = 0.25
	end
	if (event.research.name == "rocket-silo") then
		game.difficulty_settings.technology_price_multiplier = 10
	end
end
-------------------------------------------------------------------------------------------
local on_cutscene_waypoint_reached = function(event)
	if not _ENV.crash_site_cutscene_active then return end
	if not crash_site.is_crash_site_cutscene(event) then return end

	local player = game.get_player(event.player_index)

	player.exit_cutscene()

	if not _ENV.skip_intro then
		if game.is_multiplayer() then
			player.print(_ENV.custom_intro_message or { "msg-intro" })
		else
			game.show_message_dialog { text = _ENV.custom_intro_message or { "msg-intro" } }
		end
	end
end

local skip_crash_site_cutscene = function(event)
	if not _ENV.crash_site_cutscene_active then return end
	if event.player_index ~= 1 then return end
	local player = game.get_player(event.player_index)
	if player.controller_type == defines.controllers.cutscene then
		player.exit_cutscene()
	end
end

local on_cutscene_cancelled = function(event)
	if not _ENV.crash_site_cutscene_active then return end
	if event.player_index ~= 1 then return end
	_ENV.crash_site_cutscene_active = nil
	local player = game.get_player(event.player_index)
	if player.gui.screen.skip_cutscene_label then
		player.gui.screen.skip_cutscene_label.destroy()
	end
	if player.character then
		player.character.destructible = true
	end
	player.zoom = 1.5
end

local on_player_display_refresh = function(event)
	crash_site.on_player_display_refresh(event)
end

local freeplay_interface =
{
	get_created_items = function()
		return _ENV.created_items
	end,
	set_created_items = function(map)
		_ENV.created_items = map or error("Remote call parameter to freeplay set created items can't be nil.")
	end,
	get_respawn_items = function()
		return _ENV.respawn_items
	end,
	set_respawn_items = function(map)
		_ENV.respawn_items = map or error("Remote call parameter to freeplay set respawn items can't be nil.")
	end,
	set_skip_intro = function(bool)
		_ENV.skip_intro = bool
	end,
	get_skip_intro = function()
		return _ENV.skip_intro
	end,
	set_custom_intro_message = function(message)
		_ENV.custom_intro_message = message
	end,
	get_custom_intro_message = function()
		return _ENV.custom_intro_message
	end,
	set_chart_distance = function(value)
		_ENV.chart_distance = tonumber(value) or
			error("Remote call parameter to freeplay set chart distance must be a number")
	end,
	get_disable_crashsite = function()
		return _ENV.disable_crashsite
	end,
	set_disable_crashsite = function(bool)
		_ENV.disable_crashsite = bool
	end,
	get_init_ran = function()
		return _ENV.init_ran
	end,
	get_ship_items = function()
		return _ENV.crashed_ship_items
	end,
	set_ship_items = function(map)
		_ENV.crashed_ship_items = map or error("Remote call parameter to freeplay set created items can't be nil.")
	end,
	get_debris_items = function()
		return _ENV.crashed_debris_items
	end,
	set_debris_items = function(map)
		_ENV.crashed_debris_items = map or error("Remote call parameter to freeplay set respawn items can't be nil.")
	end,
	get_ship_parts = function()
		return _ENV.crashed_ship_parts
	end,
	set_ship_parts = function(parts)
		_ENV.crashed_ship_parts = parts or error("Remote call parameter to freeplay set ship parts can't be nil.")
	end
}

if not remote.interfaces["freeplay"] then
	remote.add_interface("freeplay", freeplay_interface)
end

local is_debug = function()
	local surface = game.surfaces.nauvis
	local map_gen_settings = surface.map_gen_settings
	return map_gen_settings.width == 50 and map_gen_settings.height == 50
end

local freeplay = {}

freeplay.events =
{
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_player_respawned] = on_player_respawned,
	[defines.events.on_cutscene_waypoint_reached] = on_cutscene_waypoint_reached,
	["crash-site-skip-cutscene"] = skip_crash_site_cutscene,
	[defines.events.on_player_display_resolution_changed] = on_player_display_refresh,
	[defines.events.on_player_display_scale_changed] = on_player_display_refresh,
	[defines.events.on_cutscene_cancelled] = on_cutscene_cancelled,
	[defines.events.on_research_finished] = on_research_finished,
	[defines.events.on_unit_group_finished_gathering] = on_unit_group_finished_gathering,
	[defines.events.on_biter_base_built] = on_biter_base_built,
	[defines.events.on_rocket_launched] = on_rocket_launched,
	[defines.events.on_pre_surface_cleared] = on_pre_surface_cleared,
	[defines.events.on_surface_cleared] = on_surface_cleared,
	[defines.events.on_console_command] = on_console_command,
	[defines.events.on_player_toggled_map_editor] = on_player_toggled_map_editor,
	[defines.events.on_research_cancelled] = on_research_cancelled,
	[defines.events.on_research_started] = on_research_started,
	[defines.events.on_build_base_arrived] = on_build_base_arrived

}


freeplay.on_configuration_changed = function()
	_ENV.created_items = _ENV.created_items or created_items()
	_ENV.respawn_items = _ENV.respawn_items or respawn_items()
	_ENV.crashed_ship_items = _ENV.crashed_ship_items or ship_items()
	_ENV.crashed_debris_items = _ENV.crashed_debris_items or debris_items()
	_ENV.crashed_ship_parts = _ENV.crashed_ship_parts or ship_parts()

	if not _ENV.init_ran then
		-- migrating old saves.
		_ENV.init_ran = #game.players > 0
	end
end


freeplay.on_init = function()
	_ENV.created_items = created_items()
	_ENV.respawn_items = respawn_items()
	_ENV.crashed_ship_items = ship_items()
	_ENV.crashed_debris_items = debris_items()
	_ENV.crashed_ship_parts = ship_parts()
	resetVariables()

	if is_debug() then
		_ENV.skip_intro = true
		_ENV.disable_crashsite = true
	end
end

return freeplay
