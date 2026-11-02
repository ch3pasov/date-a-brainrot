local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Reaction = {}

-- Video reactions remain legible for creatures that have no arm bones.
-- The chosen gesture is an expression, never an assertion of a server hit.
function Reaction.mount(parent)
    local size = UI.readableSize(48, 28)
    local bubble = UI.frame(parent, "CameraReaction", UDim2.new(1, -size - 8, 1, -size - 8), UDim2.fromOffset(size, size), C.panel, 10)
    bubble.Visible = false
    UI.stroke(bubble, C.ink).Thickness = 2
    local tail = UI.frame(bubble, "Tail", UDim2.new(0, -4, .65, 0), UDim2.fromOffset(10, 10), C.panel, 1)
    tail.Rotation = 45
    local pictures = {}
    for _, gesture in { "wave", "heart", "dance" } do
        local icon = Icons.gesture(bubble, gesture, UDim2.fromOffset(6, 6), UDim2.fromOffset(size - 12, size - 12))
        icon.Name = gesture; icon.Visible = false
        pictures[gesture] = icon
    end
    local current
    return {
        show = function(gesture)
            local nextGesture = pictures[gesture] and gesture or nil
            if nextGesture == current then return end
            current = nextGesture
            bubble.Visible = current ~= nil
            for name, icon in pictures do icon.Visible = name == current end
        end,
    }
end
return Reaction
