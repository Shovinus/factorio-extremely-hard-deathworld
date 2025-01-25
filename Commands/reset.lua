-- reset.lua

local reset_controller = {}

commands.add_command("debug","Toggles the debug override, only works in single player mode", function(command) storage.debug_override = not storage.debug_override end)

commands.add_command("reset", "Resets map with random seed. Accepts a valid seed and 'true' or 'false' for hard_mode as parameters, in any order.", function(command)
	local player = game.get_player(command.player_index)
	if player.admin == true then
		local params = command.parameter and command.parameter:split(" ")
		local seed, hard_mode_str

		if params then
			for _, param in ipairs(params) do
				if tonumber(param) then
					seed = tonumber(param)
				elseif param == "true" or param == "false" then
					hard_mode_str = param
				else
					player.print(string.format("[color=red]Invalid parameter: %s[/color]", param))
					return
				end
			end
		end

		-- Handle the seed
		if seed then
			if seed > 0 and seed < 4294967296 then
				storage.reset_seed = seed
			else
				player.print("Invalid seed value. Seed must be between 1 and 4294967295.")
				return
			end
		else
			storage.reset_seed = math.random(1111, 4294967295)
		end

		-- Handle the hard_mode
		if hard_mode_str then
			if hard_mode_str == "true" then
				storage.hard_mode = true
			elseif hard_mode_str == "false" then
				storage.hard_mode = false
			else
				player.print("Invalid hard_mode value. Must be 'true' or 'false'.")
				return
			end
		end
		
		reset(string.format("%s has manually forced a reset.", player.name))		
	end
end)

-- Utility function to split a string by a delimiter
function string:split(delimiter)
	local result = {}
	for match in (self..delimiter):gmatch("(.-)"..delimiter) do
		table.insert(result, match)
	end
	return result
end



return reset_controller

