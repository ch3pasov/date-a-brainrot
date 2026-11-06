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
    local title, titleFont = mode and mode.name or "Наш маленький план", UI.readableSize(25)
    local titleH = UI.textHeight(title,titleFont,w-40,true)
    local actionFont = UI.readableSize(21)
    local actionH = math.max(66, UI.touchMinimum or 0, UI.textHeight("Подключаемся…",actionFont,w-56,true)+20)
    local shade = UI.frame(parent, "DateBriefing", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.ink, 0)
    shade.BackgroundTransparency = .35; shade.ZIndex = 10; shade.Active = true
    local box = UI.frame(shade, "ReadyCard", UDim2.fromOffset((options.width-w)/2, safeTop + (options.height-safeTop-20-h)/2), UDim2.fromOffset(w,h), C.panel, 12)
    UI.stroke(box,C.ink).Thickness = 3
    UI.label(box, "Title", title, UDim2.fromOffset(20,14), UDim2.new(1,-40,0,titleH), titleFont, C.ink, true)
    local contentY, footerY = 26 + titleH, h-actionH-18
    local scroll = UI.new("ScrollingFrame", {
        Name="Rules", Position=UDim2.fromOffset(20,contentY), Size=UDim2.fromOffset(w-40,footerY-contentY-12),
        BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3,
        CanvasSize=UDim2.fromOffset(0,0), ScrollingEnabled=true,
    },box)
    local cursor = 0
    local function label(name,text,color,bold)
        local height = UI.textHeight(text,font,w-52,bold)
        UI.label(scroll,name,text,UDim2.fromOffset(0,cursor),UDim2.new(1,-12,0,height),font,color or C.ink,bold)
        cursor += height + 12
    end
    label("Place",Locations.get(session.locationId).name,C.purple,true)
    label("Rule",mode and mode.rule or "Запомни четыре предмета. Затем выбери их в том же порядке.")
    label("Target",("Нужно %d из %d. Ответы без таймера."):format(mode and mode.required or 3,mode and mode.total or 4),C.ink,true)
    label("Hint",options.mobile and "Показ начнётся по кнопке." or "Начать — Enter или кнопка. После показа выбирай предметы мышью или клавишами 1–4.",C.muted)
    scroll.CanvasSize = UDim2.fromOffset(0,cursor)
    local ready = UI.button(box,"ReadyDate","Начать →",UDim2.fromOffset(20,footerY),UDim2.new(1,-40,0,actionH),C.mint,options.ready)
    ready.TextSize = actionFont; ready.TextColor3 = C.panel
    return ready
end
return Briefing
