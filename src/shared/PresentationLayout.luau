local Layout = {}
function Layout.resolve(width, height, mobile, touchMinimum)
    local replyHeight = math.max(mobile and 58 or 54, touchMinimum or 0)
    local repliesHeight = replyHeight * 3 + 24
    local controlsHeight = math.max(78, touchMinimum or 0)
    local controlsY = height - controlsHeight - 38
    local videoHeight = math.max(205, controlsY - 98)
    return {
        replyHeight = replyHeight, repliesHeight = repliesHeight,
        logHeight = height - repliesHeight - 139,
        controlsHeight = controlsHeight, controlsY = controlsY,
        videoHeight = videoHeight, videoWidth = (width - 48) / 2,
        cameraWidth = mobile and width - 36 or (width - 48) / 2,
        cameraHeight = mobile and (videoHeight - 12) / 2 or videoHeight,
        secondCameraX = mobile and 18 or 18 + (width - 48) / 2 + 12,
        secondCameraY = mobile and 47 + (videoHeight - 12) / 2 + 12 or 47,
        promptY = videoHeight + 52, dotsY = height - 32,
        gestureWidth = width / 3 - 16,
    }
end
function Layout.minimumPhoneHeight(mobile, touchMinimum)
    local replyHeight = math.max(mobile and 58 or 54, touchMinimum or 0)
    return replyHeight * 3 + 24 + 139 + 120 + 16
end
function Layout.dateHeader(width, mobile, touchMinimum, fontSize)
    local control = math.max(66, touchMinimum or 0)
    local titleWidth = mobile and math.max(174, math.ceil(fontSize * 10)) or 550
    local left = math.max(112, 26 + control + 14)
    local stacked = width - left - (26 + control + 14) < titleWidth
    local titleY = stacked and 16 + control + 12 or 16
    local titleHeight = math.max(66, math.ceil(fontSize * 2.5))
    return {
        titleX = stacked and 26 or left, titleY = titleY,
        titleWidth = stacked and width - 52 or titleWidth, titleHeight = titleHeight,
        cueY = math.max(100, 16 + control + 12, titleY + titleHeight + 12),
    }
end
return Layout
