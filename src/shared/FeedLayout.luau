-- Logical canvas geometry. Main actions stay above the dock; tiny cards scroll.
local Feed = {}
function Feed.resolve(width, height, mobile, touchMinimum)
    local cardW = mobile and 436 or 610
    local actionHeight = math.max(76, touchMinimum or 0)
    local dockHeight = math.max(76, (touchMinimum or 0) + 12)
    local dockY = height - dockHeight - 14
    local actionY = dockY - 8 - actionHeight
    local headerButtonSize = math.max(66, touchMinimum or 0)
    local bodyY = mobile and math.max(100, 30 + headerButtonSize) or 106
    local bodyHeight = mobile and actionY - bodyY - 6 or height - 214
    local undoWidth = math.max(68, touchMinimum or 0)
    local actionWidth = (436 - undoWidth - 28) / 2
    local columns = (touchMinimum or 0) > (cardW - 58) / 4 and 2 or 4
    local variantHeight = math.max(48, touchMinimum or 0)
    local minimumCard = 88 + 18 + (4 / columns) * (variantHeight + 6) + 42 + 160
    local cardH = mobile and math.max(bodyHeight, minimumCard) or height - 214
    return {
        cardWidth = cardW, cardHeight = cardH,
        artHeight = cardH - (mobile and 88 or 170),
        variantHeight = variantHeight,
        variantColumns = columns, variantRows = 4 / columns,
        variantWidth = (cardW - 40 - (columns - 1) * 6) / columns,
        bodyY = bodyY, bodyHeight = bodyHeight,
        scrollable = mobile and cardH > bodyHeight, headerButtonSize = headerButtonSize,
        actionY = mobile and actionY or cardH - 82,
        actionHeight = actionHeight, actionWidth = actionWidth,
        undoWidth = undoWidth, undoX = actionWidth + 14, likeX = actionWidth + undoWidth + 28,
        dockY = dockY, dockHeight = dockHeight,
    }
end
return Feed
