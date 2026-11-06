-- A streak celebrates consecutive confirmed answers. It never changes scoring.
local Vibe = {}
function Vibe.stats(hits, through, confirmed)
    local current, best, correct = 0, 0, 0
    hits = type(hits) == "table" and hits or {}
    local total = math.clamp(math.floor(through or #hits), 0, 6)
    for i = 1, total do
        local hit = hits[i]
        if i == total and type(confirmed) == "boolean" then hit = confirmed end
        if hit == true then
            current += 1; correct += 1; best = math.max(best, current)
        else current = 0 end
    end
    return { current = current, best = best, correct = correct, total = total }
end
function Vibe.cheer(personality, streak)
    if streak < 2 then return nil end
    local tag = ({food="вкусно!", music="в ритм!", nature="растём!", adventure="вперёд!", art="красиво!", humor="огурцы в деле!"})[personality] or "есть вайб!"
    return streak .. " подряд · " .. tag
end
return Vibe
