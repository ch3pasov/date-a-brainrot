-- Logical geometry shared by collection lists and their empty postcards.
local List = {}
function List.pagination(height, touch)
    local size = math.max(66, touch or 0)
    return { size = size, y = height - size, nextX = size + 10, labelX = size * 2 + 20 }
end
function List.resolve(height, mobile, touch, sent, paginated)
    local filterY = mobile and 103 or 91
    local filterHeight = math.max(mobile and 58 or 44, touch or 0)
    local gridY = filterY + filterHeight + (mobile and 17 or 16)
    local actionHeight = math.max(mobile and 66 or 52, touch or 0)
    local rowHeight = (mobile and (sent and 146 or 124) or (sent and 276 or 254)) + actionHeight
    local pager = List.pagination(height, touch)
    local bottom = paginated and pager.y - 10 or height - 6
    return {
        filterY = filterY, filterHeight = filterHeight, gridY = gridY,
        gridHeight = math.max(1, bottom - gridY), actionHeight = actionHeight,
        rowHeight = rowHeight, artHeight = mobile and rowHeight - 16 or 150,
        actionY = rowHeight - actionHeight - 12, pager = pager,
    }
end
function List.empty(height, top, mobile, touch)
    local actionHeight = math.max(66, touch or 0)
    local noteHeight = mobile and 52 or 58
    local minimum = 16 + 112 + 12 + noteHeight + 14 + actionHeight + 16
    local cardHeight = math.max(minimum, height - top - 8)
    local actionY = cardHeight - actionHeight - 16
    local noteY = actionY - 14 - noteHeight
    return {
        top = top, height = cardHeight, actionHeight = actionHeight, actionY = actionY,
        noteY = noteY, noteHeight = noteHeight, imageY = 16,
        imageHeight = math.min(mobile and 156 or 240, noteY - 28),
        bottom = top + cardHeight + 8, scrollable = top + cardHeight + 8 > height,
    }
end
return List
