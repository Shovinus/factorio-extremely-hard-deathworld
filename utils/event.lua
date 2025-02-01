local event = {}
local tickWatchers = {}
local eventWatchers = {}

-- Register nth_tick event
function event.nth_tick(tick, registerFunction)
    if tickWatchers[tick] == nil then
        tickWatchers[tick] = {} -- Array of functions to call
        script.on_nth_tick(tick, nth_tick_handler)
    end
    table.insert(tickWatchers[tick], registerFunction)
end

-- Nth tick handler
function nth_tick_handler(e)
    local tick = e.nth_tick
    if tickWatchers[tick] == nil then
        return
    end
    for i = 1, #tickWatchers[tick] do
        tickWatchers[tick][i](e)
    end
end

-- Register runtime event
function event.on(eventType, registerFunction, filter)
    local eventTypeSTR = "_"..eventType
    if eventWatchers[eventTypeSTR] == nil then
        eventWatchers[eventTypeSTR] = { handlers = {}, filter = nil }
    end

    -- Add the handler and its filter
    table.insert(eventWatchers[eventTypeSTR].handlers, { handler = registerFunction, filter = filter })

    -- Check and update the unified filter
    event.update_filter(eventType)
end

-- Update the unified filter for a given event type
function event.update_filter(eventType)
    local eventTypeSTR = "_"..eventType
    local watchers = eventWatchers[eventTypeSTR]
    if not watchers then return end

    -- Build the combined filter
    local combinedFilter = {}
    local hasFilters = false

    for _, watcher in ipairs(watchers.handlers) do
        if watcher.filter then
            hasFilters = true
            for _, f in ipairs(watcher.filter) do
                table.insert(combinedFilter, f)
            end
        end
    end

    -- Apply the unified filter if at least one handler uses a filter
    if hasFilters then
        watchers.filter = combinedFilter
        script.on_event(eventType, runtime_event_handler, combinedFilter)
    else
        watchers.filter = nil
        script.on_event(eventType, runtime_event_handler) -- No filter
    end
end

-- Unified runtime event handler
function runtime_event_handler(event)
    local eventType = "_"..event.name
    local watchers = eventWatchers[eventType]
    if not watchers then return end

    for _, watcher in ipairs(watchers.handlers) do
        -- Apply the filter if it exists
        if watcher.filter == nil or event_matches_filter(event, watcher.filter) then
            watcher.handler(event)
        end
    end
end

-- Helper to match filters
function event_matches_filter(event, filters)
    if type(filters) ~= "table" then
        error("Filters must be a table (array of filters)")
    end

    for _, filter in ipairs(filters) do
        if type(filter) ~= "table" or not filter.filter then
            error("Invalid filter format. Expected { filter = 'name', name = '<entity-name>' }")
        end

        if filter.filter ~= "name" then
            error("Unsupported filter type: " .. tostring(filter.filter) .. ". Only 'name' is allowed.")
        end

        -- Factorio-style name matching
        if event.entity and event.entity.name == filter.name then
            return true
        end
    end

    return false -- No filters matched
end


event.s = defines.events

return event
