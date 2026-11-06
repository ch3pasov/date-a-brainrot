local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remix = require(Shared.DateRemix)
local Locations = require(Shared.Locations)
local UI = require(script.Parent.UI)
local C = UI.colors
local Briefing = {}
function Briefing.mount(parent, session, options)
    local mode = Remix.get(session.remixId)
    local w = math.min(options.width - 48, 560)
    local safeTop = math.max(114, (UI.touchMinimum or 66) + 48)
    local h = math.min(490, options.height - safeTop - 20)
    local font = UI.readableSize(18)
    local line = math.ceil(font * 1.4)
    local actionH = math.max(66, UI.touchMinimum or 0)
    local shade = UI.frame(parent, "DateBriefing", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.ink, 0)
    shade.BackgroundTransparency = .35; shade.ZIndex = 10; shade.Active = true
    local box = UI.frame(shade, "ReadyCard", UDim2.fromOffset((options.width-w)/2, safeTop + (options.height-safeTop-20-h)/2), UDim2.fromOffset(w,h), C.panel, 12)
    UI.stroke(box,C.ink).Thickness = 3
    UI.label(box, "Title", mode and mode.name or "Наш маленький план", UDim2.fromOffset(20,14), UDim2.new(1,-40,0,line*2), UI.readableSize(25), C.ink, true)
    local contentY, footerY = 26 + line*2, h-actionH-18
    local scroll = UI.new("ScrollingFrame", {
        Name="Rules", Position=UDim2.fromOffset(20,contentY), Size=UDim2.fromOffset(w-40,footerY-contentY-12),
        BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3,
        CanvasSize=UDim2.fromOffset(0,line*8+36), ScrollingEnabled=true,
    },box)
    local function label(name,text,y,lines,color,bold)
        return UI.label(scroll,name,text,UDim2.fromOffset(0,y),UDim2.new(1,-12,0,line*lines),font,color or C.ink,bold)
    end
    label("Place",Locations.get(session.locationId).name,0,2,C.purple,true)
    label("Rule",mode and mode.rule or "Запомни четыре предмета. Затем выбери их в том же порядке.",line*2+8,3)
    label("Target",("Нужно %d из %d. Ответы без таймера."):format(mode and mode.required or 3,mode and mode.total or 4),line*5+16,2,C.ink,true)
    label("Hint","Показ начнётся по кнопке.",line*7+24,1,C.muted)
    local ready = UI.button(box,"ReadyDate","Начать →",UDim2.fromOffset(20,footerY),UDim2.new(1,-40,0,actionH),C.mint,options.ready)
    ready.TextSize = UI.readableSize(21); ready.TextColor3 = C.panel
    return ready
end
return Briefing
