
local exhdhelp = {}


storage.biter_names = {"small-biter", "medium-biter", "big-biter", "behemoth-biter"}
storage.spitter_names = {"small-spitter", "medium-spitter", "big-spitter", "behemoth-spitter"}
storage.spitter_to_worm_conversion_map =
{
	["small-spitter"] = "small-worm-turret",
	["medium-spitter"] = "medium-worm-turret",
	["big-spitter"] = "big-worm-turret",
	["behemoth-spitter"] = "behemoth-worm-turret"
}
storage.kills_min = 250
storage.kills_max = 300

exhdhelp.getBiterKills = function()
    local killStats = game.forces["player"].get_kill_count_statistics(1)
	local kills = 0
    local biters = storage.biter_names
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
return exhdhelp;
