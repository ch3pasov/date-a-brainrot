local UI=require(script.Parent.UI)
local Icons=require(script.Parent.ToyIcons)
local C=UI.colors
local Card={}
function Card.mount(parent,options)
    local available=parent.Size.X.Offset
    local w=options.mobile and available-8 or math.min(640,available-8)
    local h=parent.Size.Y.Offset-8
    local font=UI.readableSize(18)
    local actionH=options.action and math.max(66,UI.touchMinimum or 0,UI.textHeight(options.actionText,font,w-40,true)+16) or 0
    local box=UI.frame(parent,"StateCard",UDim2.fromOffset((available-w)/2,4),UDim2.fromOffset(w,h),C.panel,5)
    UI.stroke(box,C.ink)
    local content=UI.new("ScrollingFrame",{Name="Content",Position=UDim2.fromOffset(16,16),Size=UDim2.fromOffset(w-32,h-32-(actionH>0 and actionH+12 or 0)),
        BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromOffset(0,0),ScrollBarThickness=3,ScrollingEnabled=true},box)
    local iconSize=math.max(64,math.ceil(24/(UI.scale or 1)))
    local titleFont=UI.readableSize(26)
    local titleH=UI.textHeight(options.title,titleFont,w-iconSize-56,true)
    local headingH=math.max(iconSize,titleH)
    local picture=UI.frame(content,"Picture",UDim2.fromOffset(0,0),UDim2.fromOffset(iconSize,iconSize),C.aqua,4)
    local draw=options.icon=="photo" and Icons.photo or Icons.clock
    draw(picture,UDim2.fromOffset(8,8),UDim2.fromOffset(iconSize-16,iconSize-16))
    UI.label(content,"Title",options.title,UDim2.fromOffset(iconSize+12,0),UDim2.fromOffset(w-iconSize-56,titleH),titleFont,C.ink,true)
    local noteH=UI.textHeight(options.note,font,w-40,false)
    UI.label(content,"Description",options.note,UDim2.fromOffset(0,headingH+12),UDim2.fromOffset(w-40,noteH),font,C.muted)
    content.CanvasSize=UDim2.fromOffset(0,headingH+noteH+28)
    content.CanvasPosition=options.scrollPosition or Vector2.new(0,0)
    if options.scrolled then content:GetPropertyChangedSignal("CanvasPosition"):Connect(function()options.scrolled(content.CanvasPosition)end)end
    if options.action then
        local button=UI.button(box,"StateAction",options.actionText,UDim2.fromOffset(16,h-actionH-16),UDim2.fromOffset(w-32,actionH),C.mint,options.action)
        button.TextSize=font;button.TextColor3=C.panel;button.TextWrapped=true
    end
    return box
end
return Card
