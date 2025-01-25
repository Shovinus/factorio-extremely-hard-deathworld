local event = {}
local tickWatchers = {}
local eventWatchers = {}
function event.nth_tick(tick, registerFunction)
    if tickWatchers[tick] == nil then
        -- array of functions to call
        tickWatchers[tick] = {}
        script.on_nth_tick(tick, nth_tick_handler)
    end
    table.insert(tickWatchers[tick], registerFunction)
end

function nth_tick_handler(e)
    local tick = e.nth_tick
    if tickWatchers[tick] == nil then
        return
    end
    for i = 1, #tickWatchers[tick] do
        tickWatchers[tick][i](e)
    end
end


function event.on(eventType, registerFunction, filter)
    script.on_event(eventType, registerFunction, filter)
end
event.s= defines.events

return event
