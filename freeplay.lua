local util = require("util")
local crash_site = require("crash-site")
local spitter_death_records = 20

local e = require("utils.event")
local enemies = require("utils.enemies")
local g = require("utils.general")


local inventories = {
	defines.inventory.character_main,
	defines.inventory.character_guns,
	defines.inventory.character_ammo
}
----We disable victory conditions of silo script because it doesn't work with soft reset
storage.no_victory = true
---
storage.count_down_start = 30
storage.count_down = 30
storage.biter_hp = 3000
storage.debug_override = false
storage.biter_initial_hp = 3000
storage.biter_target_hp_multiplier = 300
storage.biter_target_hp = storage.biter_target_hp_multiplier * storage.biter_initial_hp
storage.biter_hp_base_modifier = 0.002
storage.newgame = true

storage.reset_seed = 2013392874
storage.reset_seed_delayed = 2013392874
storage.restart = "false"
storage.hard_mode = false
storage.current_pathfinding = nil


local resetVariables = function()
	game.player.force.technologies["atomic-bomb"].enabled = false
	storage.player_state = {}
	storage.deconstruction_history = {}
	storage.new_map = true
	-- clear globals
	storage.latch= 0
	storage.u = {}
	for i = 1, spitter_death_records do
		storage.u[i] = { 0, 0 }
	end
	storage.biter_hp = 3000
	storage.deconstruction_history = {}
	storage.no_regen_biters = {}
	storage.current_pathfinding = nil
	storage.exhd_game_progress = {
		nauvis_launch = false,
		gleba_touchdown = false,
		vulcanus_touchdown = false,
		fulgora_touchdown = false,
		aquilo_touchdown = false,
		space_edge_reach = false
	}

	storage.motion = nil
	-- default starting map settings
	game.map_settings.enemy_evolution.destroy_factor = 0
	game.map_settings.enemy_evolution.pollution_factor = 0
	if storage.hard_mode then
		game.map_settings.enemy_evolution.time_factor = 0.00007
		game.map_settings.pollution.enemy_attack_pollution_consumption_modifier = 0.5
	else
		game.map_settings.enemy_evolution.time_factor = 0.00005
		game.map_settings.pollution.enemy_attack_pollution_consumption_modifier = 6
	end
	game.map_settings.enemy_expansion.enabled                                         = true
	game.map_settings.enemy_expansion.max_expansion_cooldown                          = 4000
	game.map_settings.enemy_expansion.min_expansion_cooldown                          = 3000
	game.map_settings.enemy_expansion.settler_group_max_size                          = 11
	game.map_settings.enemy_expansion.settler_group_min_size                          = 10
	game.map_settings.pollution.ageing                                                = 0.5
	game.map_settings.pollution.enabled                                               = true
	game.map_settings.unit_group.max_gathering_unit_groups                            = 30
	game.map_settings.unit_group.max_unit_group_size                                  = 100

	-- path finding changes to reduce lag
	game.map_settings.path_finder.general_entity_collision_penalty                    = 0
	game.map_settings.path_finder.general_entity_subsequent_collision_penalty         = 0
	game.map_settings.path_finder.ignore_moving_enemy_collision_distance              = 0
	game.map_settings.path_finder.use_path_cache                                      = false
	game.map_settings.path_finder.extended_collision_penalty                          = 0
	game.map_settings.path_finder.enemy_with_different_destination_collision_penalty  = 0
	game.map_settings.path_finder.stale_enemy_with_same_destination_collision_penalty = 0
	game.map_settings.max_failed_behavior_count                                       = 1
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
	mgs.seed = storage.reset_seed
	surface.map_gen_settings = mgs
end


local is_debug = function()
	return not game.is_multiplayer() and not storage.debug_override
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
	storage.new_map = true

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
	game.get_pollution_statistics(1).clear()
	resetVariables()
	local surface = game.surfaces[1]
	if storage.hard_mode then
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
	game.forces["player"].max_failed_attempts_per_tick_per_construction_queue = 2
	game.forces["player"].max_successful_attempts_per_tick_per_construction_queue = 6
	game.difficulty_settings.technology_price_multiplier = 1
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
	if (storage.player_state == nil) then
		resetVariables()
	end
	local player = game.get_player(player_index)

	if storage.player_state[player_index] == nil then
		storage.player_state[player_index] = default_player_state()
	end
	local player_state = storage.player_state[player_index]

	if player_state.has_received_starting_items == false then
		player_state.has_received_starting_items = true
		util.insert_safe(player, storage.created_items)
	else
		util.insert_safe(player, storage.respawn_items)
	end
end

e.on(defines.events.on_player_created,function(event)
	local player = game.get_player(event.player_index)
	if(player == nil) then return end
	local name = player.name
	local x = { ID = (event.player_index - 1), Name = name }

	handle_player_created_or_respawned(event.player_index)

	if not storage.init_ran then
		-- This is so that other mods and scripts have a chance to do remote calls before we do things like charting the starting area, creating the crash site, etc.
		storage.init_ran = true

		reset_global_settings()

		if not storage.disable_crashsite then
			local surface = player.surface
			crash_site.create_crash_site(surface, { -5, -6 }, util.copy(storage.crashed_ship_items),
				util.copy(storage.crashed_debris_items), util.copy(storage.crashed_ship_parts))
		end
	end
end)

e.on(e.s.on_player_respawned, function(event)
	handle_player_created_or_respawned(event.player_index)
end)
------------------------------------------------------------------------------------------------
function reset(reason)
	if (storage.newgame) then
		storage.newgame = false
		game.surfaces[1].clear(true)
		game.forces["player"].reset()
		return
	end
	local reset_type = nil
	local red = game.forces["player"].get_item_production_statistics(1).get_output_count "automation-science-pack"
	if (storage.restart == "true") then
		reset_type = "[color=red][font=default-large-bold]Hard reset[/font][/color]"
		helpers.write_file("reset/reset.log", "restart", false, 0)
	else
		if (red > 0) then
			local victory = storage.exhd_game_progress.nauvis_launch
			local deaths = game.forces["player"].get_kill_count_statistics(1).get_output_count "character"
			local minutes = math.floor((game.tick / 3600) * 10) / 10
			local mode = storage.hard_mode and "hard" or "normal"
			local rockets_launched = game.forces["player"].rockets_launched

			local log_message = string.format("%d_%s_%s_%d_%d_%d_%d", 
			storage.reset_seed_delayed,
			mode,tostring(victory),red, deaths, minutes, rockets_launched)

			helpers.write_file("reset/reset.log", log_message, false, 0)
		end
		reset_type = "[color=green][font=default-large-bold]Soft reset[/font][/color]"
		change_seed()
		game.surfaces[1].clear(true)
		game.forces["player"].reset()
		for _, pl in pairs(game.players) do
			if pl and pl.valid and pl.character and pl.character.health > 0 then
				while (pl.crafting_queue ~= nil) do
					pl.cancel_crafting { index = 1, count = pl.crafting_queue[1].count }
				end
			end
			for _, inv in pairs(inventories) do
				local inv = pl.get_inventory(inv)
				if (inv ~= nil) then
					inv.clear()
				end
			end
			pl.teleport(g.add_random_offset(5, { 5, 5 }), game.surfaces[1])
			handle_player_created_or_respawned(pl.index)
		end
	end
	if reason ~= nil then
		game.print(string.format("%s [color=yellow]%s Hardmode is currently [/color][color=%s[/color]", reset_type,
			reason, storage.hard_mode and "red]on" or "green]off"))
	end
end

-- function place_blueprint()
-- 	if (not (storage.reset_seed == 20133928755)) then
-- 		return
-- 	end
-- 	local surface = game.surfaces[1]
-- 	local position = { x = -27, y = -123 } -- Position where the b`ueprint will be placed
-- 	local force = game.forces["player"]
-- 	local bp_entity = surface.create_entity { name = 'item-on-ground', position = { 0, 0 }, stack = 'blueprint' }
-- 	bp_entity.stack.import_stack(storage.default_blueprint)
-- 	bp_entity.stack.build_blueprint({
-- 		surface = surface,
-- 		force = force,
-- 		position = position,
-- 		build_mode = defines.build_mode.superforced,
-- 		skip_fog_of_war = false
-- 	})
-- 	bp_entity.destroy()
-- end

-----------------------------------------------------------------------------------------------
e.on(defines.events.on_pre_surface_cleared,function(event)
	reset_global_setings__pre_surface_clear()
end)
-----------------------------------------------------------------------------------------------
e.on(defines.events.on_surface_cleared,function(event)
	reset_global_settings__post_surface_clear()

	local surface = game.surfaces[1]
	surface.request_to_generate_chunks({ 0, 0 }, 6)
	surface.force_generate_chunk_requests()
	crash_site.create_crash_site(surface, { -5, -6 }, util.copy(storage.crashed_ship_items),
		util.copy(storage.crashed_debris_items), util.copy(storage.crashed_ship_parts))
end)
------------------------------------------------------------------------------------------
e.on(defines.events.on_player_toggled_map_editor,function(event)
	if (is_debug()) then
		return
	end
	storage.restart = "true"

	local player = game.get_player(event.player_index)
	if(player == nil) then return end
	reset(string.format("%s has toggled the map editor.", player.name))
end)
------------------------------------------------------------------------------------------
e.on(defines.events.on_console_command,function(event)
	local command = event.command
	local parameters = event.parameters
	print(command)
	print(parameters)

	if (game.console_command_used and storage.restart ~= "true") then
		storage.restart = "true"
		local name = nil
		if event.player_index ~= nil then
			name = game.get_player(event.player_index).name
		end
		reset(string.format("%s has used a console command.", name or "SERVER"))
	end
end)





---------------------------------------------------------------------------------------------------------------------------------------------------
e.on(defines.events.on_rocket_launched, function(event)
	if 	storage.exhd_game_progress.nauvis_launch == false then
		game.print("The rocket has launched! Well done! The nightmare isn't over yet though get to the edge of space, engineer.")
		game.forces["enemy"].kill_all_units()
		game.surfaces[1].clear_pollution()
		game.map_settings.pollution.enemy_attack_pollution_consumption_modifier= 0.5
		--game.map_settings.pollution.enabled = false
		storage.exhd_game_progress.nauvis_launch = true
		--game.set_game_state { game_finished = true, player_won = true, can_continue = true, victorious_force = player }
	end
end)
-------------------------------------------------------------------------------------------------------------------------------------------
e.on(defines.events.on_research_finished,function(event)
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
	if (event.research.name == "refined-flammable") then
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
end)
-------------------------------------------------------------------------------------------
e.on(defines.events.on_research_cancelled,function(event)
	if event.research[storage.research] == 1 then
		game.difficulty_settings.technology_price_multiplier = 1
	end
end)
-------------------------------------------------------------------------------------------
e.on(defines.events.on_research_started,function(event)
	storage.research = event.research.name
	if (event.research.name == "nuclear-power") then
		game.difficulty_settings.technology_price_multiplier = 0.5
	end
	if (event.research.name == "spidertron") then
		game.difficulty_settings.technology_price_multiplier = 0.16
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
		game.difficulty_settings.technology_price_multiplier = 0.5
	end
end)
-------------------------------------------------------------------------------------------
-- local on_cutscene_waypoint_reached = function(event)
-- 	if not storage.crash_site_cutscene_active then return end
-- 	if not crash_site.is_crash_site_cutscene(event) then return end
-- 	local player = game.get_player(event.player_index)
-- 	player.exit_cutscene()
-- 	if not storage.skip_intro then
-- 		if game.is_multiplayer() then
-- 		else
-- 			game.show_message_dialog { text = storage.custom_intro_message or { "msg-intro" } }
-- 		end
-- 	end
--end
-------------------------------------------------------------------------------------------
-- local skip_crash_site_cutscene = function(event)
-- 	if not storage.crash_site_cutscene_active then return end
-- 	if event.player_index ~= 1 then return end
-- 	local player = game.get_player(event.player_index)
-- 	if player.controller_type == defines.controllers.cutscene then
-- 		player.exit_cutscene()
-- 	end
-- end
-------------------------------------------------------------------------------------------
-- local on_cutscene_cancelled = function(event)
-- 	if not storage.crash_site_cutscene_active then return end
-- 	if event.player_index ~= 1 then return end
-- 	storage.crash_site_cutscene_active = nil
-- 	local player = game.get_player(event.player_index)
-- 	if player.gui.screen.skip_cutscene_label then
-- 		player.gui.screen.skip_cutscene_label.destroy()
-- 	end
-- 	if player.character then
-- 		player.character.destructible = true
-- 	end
-- 	player.zoom = 1.5
-- end
-------------------------------------------------------------------------------------------
-- local on_player_display_refresh = function(event)
-- 	crash_site.on_player_display_refresh(event)
-- end
-------------------------------------------------------------------------------------------

local freeplay_interface =
{
	get_created_items = function()
		return storage.created_items
	end,
	set_created_items = function(map)
		storage.created_items = map or error("Remote call parameter to freeplay set created items can't be nil.")
	end,
	get_respawn_items = function()
		return storage.respawn_items
	end,
	set_respawn_items = function(map)
		storage.respawn_items = map or error("Remote call parameter to freeplay set respawn items can't be nil.")
	end,
	set_skip_intro = function(bool)
		storage.skip_intro = bool
	end,
	get_skip_intro = function()
		return storage.skip_intro
	end,
	set_custom_intro_message = function(message)
		storage.custom_intro_message = message
	end,
	get_custom_intro_message = function()
		return storage.custom_intro_message
	end,
	set_chart_distance = function(value)
		storage.chart_distance = tonumber(value) or
			error("Remote call parameter to freeplay set chart distance must be a number")
	end,
	get_disable_crashsite = function()
		return storage.disable_crashsite
	end,
	set_disable_crashit = function(bool)
		storage.disable_crashsite = bool
	end,
	get_init_ran = function()
		return storage.init_ran
	end,
	get_ship_items = function()
		return storage.crashed_ship_items
	end,
	set_ship_items = function(map)
		storage.crashed_ship_items = map or error("Remote call parameter to freeplay set created items can't be nil.")
	end,
	get_debris_items = function()
		return storage.crashed_debris_items
	end,
	set_debris_items = function(map)
		storage.crashed_debris_items = map or error("Remote call parameter to freeplay set respawn items can't be nil.")
	end,
	get_ship_parts = function()
		return storage.crashed_ship_parts
	end,
	set_ship_parts = function(parts)
		storage.crashed_ship_parts = parts or error("Remote call parameter to freeplay set ship parts can't be nil.")
	end
}

if not remote.interfaces["freeplay"] then
	remote.add_interface("freeplay", freeplay_interface)
end


local freeplay = {}




freeplay.on_configuration_changed = function()
	storage.created_items = storage.created_items or created_items()
	storage.respawn_items = storage.respawn_items or respawn_items()
	storage.crashed_ship_items = storage.crashed_ship_items or ship_items()
	storage.crashed_debris_items = storage.crashed_debris_items or debris_items()
	storage.crashed_ship_parts = storage.crashed_ship_parts or ship_parts()
	if not storage.init_ran then
		-- migrating old saves.
		storage.init_ran = #game.players > 0
	end
end


freeplay.on_init = function()
	storage.created_items = created_items()
	storage.respawn_items = respawn_items()
	storage.crashed_ship_items = ship_items()
	storage.crashed_debris_items = debris_items()
	storage.crashed_ship_parts = ship_parts()
	resetVariables()

	reset("Game has been initialized.")
end
e.nth_tick(60, function()
	if storage.new_map then
		if game.ticks_played > 100 then
			storage.new_map = false
			storage.reset_seed_delayed = storage.reset_seed
			game.forces["player"].chart(game.surfaces[1], { { x = -400, y = -400 }, { x = 400, y = 400 } })
		end
	end
end)

e.nth_tick(60 * 60, function()
	-- extend daytime over time	
	local evo = game.forces["enemy"].get_evolution_factor(1)
	local tpd = ((evo + 1) * 25000)
	game.surfaces[1].ticks_per_day = tpd
	-- reset the game if it has been running for more than 7 days
	if game.ticks_played > 36288000 then
		reset("Game has reached its maximum playtime of 7 days.")
	end
end)

return freeplay
