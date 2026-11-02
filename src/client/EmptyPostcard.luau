local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout = require(Shared.ListLayout)
local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Empty = {}
function Empty.mount(parent, options)
    local mobile = options.mobile
    local layout = Layout.empty(parent.Size.Y.Offset, options.top, mobile, UI.touchMinimum)
    if parent:IsA("ScrollingFrame") then
        parent.ScrollingEnabled = layout.scrollable
        parent.ScrollBarThickness = layout.scrollable and 3 or 0
        parent.CanvasSize = UDim2.fromOffset(0, layout.scrollable and layout.bottom or 0)
    end
    local card = UI.frame(parent, "EmptyPostcard", UDim2.fromOffset(4, layout.top), UDim2.new(1, -8, 0, layout.height), C.panel, 4)
    UI.stroke(card, C.ink).Thickness = 2
    local imageW = mobile and 152 or 270
    local picture = UI.frame(card, "Picture", UDim2.fromOffset(16, layout.imageY), UDim2.fromOffset(imageW, layout.imageHeight), C.aqua, 2)
    if options.mount then options.mount(picture)
    else
        local iconSize = math.min(imageW - 20, layout.imageHeight - 16)
        local draw = options.icon == "clock" and Icons.clock or options.icon == "phone" and Icons.phone or Icons.photo
        draw(picture, UDim2.new(.5, -iconSize / 2, .5, -iconSize / 2), UDim2.fromOffset(iconSize, iconSize))
    end
    local textX = imageW + 30
    local tag = UI.pill(card, "Status", options.badge, UDim2.fromOffset(textX, layout.imageY), mobile and 228 or 360, C.yellow)
    tag.Label.TextSize = UI.readableSize(12, 10)
    local title = UI.label(card, "Title", options.title, UDim2.fromOffset(textX, layout.imageY + 36), UDim2.new(1, -textX - 16, 0, layout.imageHeight - 36), UI.readableSize(mobile and 24 or 32), C.ink, true)
    title.TextScaled = true
    UI.new("UITextSizeConstraint", { MinTextSize = UI.readableSize(18, 10), MaxTextSize = UI.readableSize(mobile and 24 or 32) }, title)
    local note = UI.label(card, "Description", options.note, UDim2.fromOffset(16, layout.noteY), UDim2.new(1, -32, 0, layout.noteHeight), UI.readableSize(18), C.muted)
    note.TextXAlignment = Enum.TextXAlignment.Center
    if options.action then
        local button = UI.button(card, "EmptyAction", options.actionText, UDim2.fromOffset(16, layout.actionY), UDim2.new(1, -32, 0, layout.actionHeight), C.mint, options.action)
        button.TextSize = UI.readableSize(17); button.TextColor3 = C.panel
    end
    return card
end
return Empty
