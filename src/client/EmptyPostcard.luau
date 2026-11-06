local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout = require(Shared.ListLayout)
local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Empty = {}
function Empty.mount(parent, options)
    local mobile = options.mobile
    local width=parent.Size.X.Scale*(mobile and 480 or 1200)+parent.Size.X.Offset-8
    local imageW=mobile and 152 or 270
    local textX=imageW+30
    local textW=width-textX-16
    local tagFont=UI.readableSize(12,10)
    local tagH=math.max(28,UI.textHeight(options.badge,tagFont,textW-14,true)+8)
    local titleFont=UI.readableSize(mobile and 24 or 32)
    local titleH=UI.textHeight(options.title,titleFont,textW,true)
    local noteFont=UI.readableSize(18)
    local noteH=UI.textHeight(options.note,noteFont,width-32,false)
    local actionFont=UI.readableSize(17)
    local actionH=options.action and math.max(66,UI.touchMinimum or 0,UI.textHeight(options.actionText,actionFont,width-48,true)+12) or 0
    local layout = Layout.empty(parent.Size.Y.Offset, options.top, mobile, UI.touchMinimum,
        {imageHeight=tagH+12+titleH,noteHeight=noteH,actionHeight=actionH})
    if parent:IsA("ScrollingFrame") then
        parent.ScrollingEnabled = layout.scrollable
        parent.ScrollBarThickness = layout.scrollable and 3 or 0
        parent.CanvasSize = UDim2.fromOffset(0, layout.scrollable and layout.bottom or 0)
    end
    local card = UI.frame(parent, "EmptyPostcard", UDim2.fromOffset(4, layout.top), UDim2.new(1, -8, 0, layout.height), C.panel, 4)
    UI.stroke(card, C.ink).Thickness = 2
    local picture = UI.frame(card, "Picture", UDim2.fromOffset(16, layout.imageY), UDim2.fromOffset(imageW, layout.imageHeight), C.aqua, 2)
    if options.mount then options.mount(picture)
    else
        local iconSize = math.min(imageW - 20, layout.imageHeight - 16)
        local draw = options.icon == "clock" and Icons.clock or options.icon == "phone" and Icons.phone or Icons.photo
        draw(picture, UDim2.new(.5, -iconSize / 2, .5, -iconSize / 2), UDim2.fromOffset(iconSize, iconSize))
    end
    local tag = UI.pill(card, "Status", options.badge, UDim2.fromOffset(textX, layout.imageY), textW, C.yellow)
    tag.Size=UDim2.fromOffset(textW,tagH);tag.Label.TextSize=tagFont
    UI.label(card,"Title",options.title,UDim2.fromOffset(textX,layout.imageY+tagH+12),UDim2.fromOffset(textW,titleH),titleFont,C.ink,true)
    local note = UI.label(card, "Description", options.note, UDim2.fromOffset(16, layout.noteY), UDim2.new(1, -32, 0, layout.noteHeight), noteFont, C.muted)
    note.TextXAlignment = Enum.TextXAlignment.Center
    if options.action then
        local button = UI.button(card, "EmptyAction", options.actionText, UDim2.fromOffset(16, layout.actionY), UDim2.new(1, -32, 0, layout.actionHeight), C.mint, options.action)
        button.TextSize = actionFont; button.TextColor3 = C.panel;button.TextWrapped=true
    end
    return card
end
return Empty
