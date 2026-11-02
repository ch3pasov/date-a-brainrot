local Layout = {}
function Layout.resolve(viewportWidth, viewportHeight, touch)
    local w, h = math.max(1, viewportWidth), math.max(1, viewportHeight)
    local mobile = w / h < 1.1
    if mobile then
        local scale = math.min(w / 480, h / 760, 1)
        return { mobile = true, width = 480, height = h / scale, scale = scale, touchMinimum = math.max(66, math.ceil(44 / scale)) }
    end
    local scale = math.min(w / 1200, h / 760)
    return { mobile = false, width = 1200, height = 760, scale = scale, touchMinimum = touch and math.max(46, math.ceil(44 / scale)) or nil }
end
return Layout
