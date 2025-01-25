local general = {}

general.add_random_offset = function(radius,center)
    centerx = center.x or center[1]
    centery = center.y or center[2]
    local angle = math.random() * 2 * math.pi -- Random angle in radians
    local distance = math.random() * radius -- Random distance within the radius
    local x_offset = math.cos(angle) * distance
    local y_offset = math.sin(angle) * distance

    return { x = x_offset + centerx, y = y_offset + centery }end
return general