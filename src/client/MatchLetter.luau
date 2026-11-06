local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Letter = {}
local function center(parent, name, text, position, size, font, color)
    local label = UI.label(parent, name, text, position, size, font, color, true)
    label.TextXAlignment = Enum.TextXAlignment.Center
    return label
end

function Letter.mount(parent, character, variant, options)
    local mobile, returning = options.mobile, options.returning
    local compact=mobile and (UI.scale or 1)<.5
    local w=compact and math.clamp((options.availableWidth or 480)-48,436,700) or (mobile and 436 or 760)
    local buttonH = math.max(66, UI.touchMinimum or 0)
    local h=math.min(736,(options.availableHeight or 760)-24)
    local footerY=h-buttonH-18
    local box = UI.frame(parent, returning and "ReturnDialog" or "MatchDialog", UDim2.new(.5, -w / 2, .5, -h / 2), UDim2.fromOffset(w, h), C.panel, 4)
    box.ZIndex = 2
    local content=UI.new("ScrollingFrame",{Name="LetterContent",Position=UDim2.fromOffset(24,20),Size=UDim2.fromOffset(w-48,footerY-36),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0),ScrollingEnabled=true},box)
    local innerW=w-56
    local stamp = UI.frame(content, "HeartStamp", UDim2.fromOffset(innerW-64,4), UDim2.fromOffset(64, 64), C.yellow, 2)
    stamp.Rotation = 7; UI.stroke(stamp, C.ink).Thickness = 2
    center(stamp, "Heart", "♥", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 47, C.pink)
    local badgeText=returning and "ПОКА ТЕБЯ НЕ БЫЛО" or "ОТВЕТНЫЙ ЛАЙК"
    local badgeFont=UI.readableSize(12,10)
    local badgeW=math.min(innerW-84,math.max(mobile and 250 or 310,badgeFont*13))
    local badgeH=UI.textHeight(badgeText,badgeFont,badgeW-14,true)+6
    local badge=UI.pill(content,"LetterType",badgeText,UDim2.fromOffset(0,6),badgeW,C.aqua)
    badge.Size=UDim2.fromOffset(badgeW,badgeH);badge.Label.TextSize=badgeFont
    local y=math.max(68,badgeH+6)+16
    local function text(name,value,font,color)
        local height=UI.textHeight(value,font,innerW,true)
        center(content,name,value,UDim2.fromOffset(0,y),UDim2.fromOffset(innerW,height),font,color)
        y+=height+12
    end
    text("Title",returning and "ТЕБЯ ДОСВАЙПАЛИ!" or "ЭТО ВЗАИМНО!",UI.readableSize(mobile and 29 or 42),C.pink)
    text("Name",character.name,UI.readableSize(mobile and 27 or 32),C.ink)
    local photoW=math.min(innerW,560)
    local artH=mobile and 240 or 270
    local caption=returning and ("НОВЫХ ОТВЕТОВ: " .. (options.count or 1)) or (variant.label .. " · ВАШ ПЕРВЫЙ ПРИВЕТ")
    local captionFont=UI.readableSize(14,10)
    local captionH=UI.textHeight(caption,captionFont,photoW-16,true)
    local photoH=artH+captionH+26
    local photo = UI.frame(content, "ReplyPostcard", UDim2.fromOffset((innerW-photoW)/2,y), UDim2.fromOffset(photoW,photoH), C.card, 2)
    UI.stroke(photo, C.ink).Thickness = 2
    local art = UI.frame(photo, "Photo", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, artH), C.aqua, 1)
    local viewer = options.mount(art, { modal = true, scene = true, pair = true, locationId = "park" })
    viewer.greet()
    center(photo,"Caption",caption,UDim2.fromOffset(8,artH+16),UDim2.new(1,-16,0,captionH),captionFont,C.ink)
    y+=photoH+14
    local message=returning and "Ответы уже ждут в знакомствах." or "Первое «привет» — за тобой."
    local messageFont=UI.readableSize(18)
    local messageH=math.max(48,UI.textHeight(message,messageFont,innerW-58,true))
    if returning then
        Icons.clock(content,UDim2.fromOffset(4,y+3),UDim2.fromOffset(40,40))
    else
        Icons.phone(content,UDim2.fromOffset(8,y+3),UDim2.fromOffset(32,42))
    end
    center(content,"Message",message,UDim2.fromOffset(58,y),UDim2.fromOffset(innerW-58,messageH),messageFont,C.muted)
    content.CanvasSize=UDim2.fromOffset(0,y+messageH+12)
    content.CanvasPosition=options.scrollPosition or Vector2.new(0,0)
    if options.scrolled then content:GetPropertyChangedSignal("CanvasPosition"):Connect(function()options.scrolled(content.CanvasPosition)end)end
    local perforationY=footerY-8
    for i = 0, math.floor((w - 48) / 20) do
        UI.frame(box, "TearLine_" .. i, UDim2.fromOffset(24 + i * 20, perforationY), UDim2.fromOffset(9, 2), C.ink, 0)
    end
    local backW=(w-60)/2
    local back = UI.button(box, "ContinueSwiping", "К свайпам", UDim2.fromOffset(24, footerY), UDim2.fromOffset(backW, buttonH), C.card, options.back)
    back.TextSize = UI.readableSize(17)
    local accept = UI.button(box, returning and "OpenMatches" or "StartChat", returning and "К ОТВЕТАМ →" or "НАПИСАТЬ →", UDim2.fromOffset(36 + backW, footerY), UDim2.fromOffset(w - backW - 60, buttonH), C.mint, options.accept)
    accept.TextColor3 = C.panel; accept.TextSize = UI.readableSize(18)
    return { frame = box, dispose = function() if viewer then viewer.dispose(); viewer = nil end end }
end
return Letter
