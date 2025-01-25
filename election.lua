
storage.vote_seed = ""
storage.vote_count = "0"

local on_console_command = function(event)
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
end

-- Library event integration
local lib = {}

-- https://lua-api.factorio.com/latest/events.html#on_console_command
lib.events = {
    [defines.events.on_console_command] = on_console_command,
}
return lib