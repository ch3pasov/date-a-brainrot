local Feel = {}
function Feel.threshold(width) return math.clamp(width * 0.20, 72, 110) end
function Feel.direction(distance, velocity, width)
    local threshold = Feel.threshold(width)
    if math.abs(distance) >= threshold or (math.abs(distance) >= threshold * 0.45 and math.abs(velocity) >= 850 and distance * velocity > 0) then
        return distance > 0 and 1 or -1
    end
    return 0
end
function Feel.pose(distance, vertical, width)
    local x = math.clamp(distance, -width * 1.4, width * 1.4) * 0.84
    local y = math.clamp(vertical * 0.12, -18, 18)
    local rotation = math.clamp(distance / width * 16, -15, 15)
    local strength = math.clamp(math.abs(distance) / Feel.threshold(width), 0, 1)
    return x, y, rotation, strength
end
return Feel
