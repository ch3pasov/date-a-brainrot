local UI = require(script.Parent.UI)
local Feedback = require(script.Parent.Feedback)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Guide = {}
local instructions = {
    { "Прочитай сообщение собеседника.", "Выбери один из трёх ответов.", "Три тёплых ответа — шаг дальше." },
    { "Смотри жест в камере собеседника.", "Повтори его кнопкой внизу.", "Четыре совпадения из шести." },
    { "Запомни четыре подсветки.", "Нажимай предметы в том же порядке.", "Три совпадения — совместное селфи." },
}
function Guide.updatePreferences(overlay)
    local box = overlay and overlay:FindFirstChild("GuideDialog")
    if not box then return end
    local motion = box:FindFirstChild("MotionToggle", true)
    local sound = box:FindFirstChild("SoundToggle", true)
    if motion then motion.Text = Feedback.motionEnabled and "ОТКЛИК\nЖИВОЙ" or "ОТКЛИК\nТИХИЙ" end
    if sound then sound.Text = Feedback.soundEnabled and "♪ ЗВУК\nВКЛЮЧЁН" or "♪ ЗВУК\nВЫКЛЮЧЕН" end
end
function Guide.open(canvas, mobile, close, metadata)
    metadata = metadata or {}
    local overlay = UI.overlay(canvas, "GuideOverlay", .04)
    local w = mobile and 436 or 700
    local version = metadata.placeVersion
    local hasVersion = type(version)=="number" and version>=0 and version<math.huge and version%1==0
    local stage = metadata.stage
    local active = type(stage)=="number" and stage>=1 and stage<=3 and stage%1==0
    local steps = active and instructions[stage] or {
        "Сердце — лайк. Крестик — дальше.",
        "Ответ может прийти, пока тебя нет.",
        "Чат, жесты, свидание — ваше селфи.",
    }
    local font = UI.readableSize(17)
    local rowH = math.max(60,(font+3)*(font>24 and 3 or 2)+8)
    local buttonH = math.max(66,UI.touchMinimum or 0)
    local toggleY = 156+rowH*3+20
    local hintY = toggleY+buttonH+12
    local hintH = math.max(52,(UI.readableSize(16)+2)*2+4)
    local contentH = hintY+hintH
    local footer = hasVersion and 48 or 24
    local preferredH = 102+contentH+buttonH+footer
    local h = math.min(preferredH,(metadata.availableHeight or 760)-24)
    local closeY = h-buttonH-footer
    local scrollH = closeY-102
    local box = UI.frame(overlay,"GuideDialog",UDim2.new(.5,-w/2,.5,-h/2),UDim2.fromOffset(w,h),C.panel,4)
    box.ZIndex=2; Feedback.pop(box,.94)
    local title=active and ({"ПЕРЕПИСКА","ПОВТОРИ ЖЕСТ","ЗАПОМНИ ПОРЯДОК"})[stage] or "КАК ПОЙМАТЬ ВАЙБ"
    UI.label(box,"Title",title,UDim2.fromOffset(24,16),UDim2.new(1,-48,0,64),mobile and 28 or 35,C.ink,true)
    local content=UI.new("ScrollingFrame",{
        Name="GuideContent",Position=UDim2.fromOffset(24,90),Size=UDim2.fromOffset(w-48,scrollH),
        BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromOffset(0,contentH),
        ScrollingEnabled=contentH>scrollH,ScrollBarThickness=contentH>scrollH and 3 or 0,
    },box)
    local art=UI.frame(content,"Illustration",UDim2.fromOffset(0,0),UDim2.new(1,0,0,126),C.aqua,4)
    UI.stroke(art,C.ink).Thickness=2
    if not active then
        Icons.phone(art,UDim2.new(.17,-36,0,9),UDim2.fromOffset(72,106)).Rotation=-5
        Icons.clock(art,UDim2.new(.5,-42,0,20),UDim2.fromOffset(84,84))
        Icons.photo(art,UDim2.new(.83,-44,0,9),UDim2.fromOffset(88,108)).Rotation=5
    elseif stage==1 then
        Icons.phone(art,UDim2.new(.37,-42,0,4),UDim2.fromOffset(84,116)).Rotation=-4
        for i=1,3 do
            UI.frame(art,"Reply_"..i,UDim2.new(.57,0,0,16+(i-1)*32),UDim2.fromOffset(mobile and 112 or 180,23),i==2 and C.yellow or C.panel,5)
        end
    elseif stage==2 then
        Icons.video(art,UDim2.new(.5,-105,0,5),UDim2.fromOffset(210,116))
    else
        Icons.photo(art,UDim2.new(.5,-58,0,3),UDim2.fromOffset(116,120)).Rotation=-3
        for i=1,3 do
            local mark=UI.label(art,"Heart_"..i,"♥",UDim2.new(i==1 and .18 or .78,0,0,i==3 and 71 or 17),UDim2.fromOffset(40,42),34,C.pink,true)
            mark.Rotation=i%2==0 and 10 or -10
        end
    end
    for i,text in steps do
        local row=UI.frame(content,"Step_"..i,UDim2.fromOffset(0,140+(i-1)*(rowH+10)),UDim2.new(1,0,0,rowH),C.card,4)
        local number=UI.frame(row,"NumberSeal",UDim2.new(0,12,.5,-18),UDim2.fromOffset(36,36),i==2 and C.pink or C.mint,18)
        local n=UI.label(number,"Number",tostring(i),UDim2.fromScale(0,0),UDim2.fromScale(1,1),26,C.panel,true);n.TextXAlignment=Enum.TextXAlignment.Center
        UI.label(row,"Detail",text,UDim2.fromOffset(62,3),UDim2.new(1,-72,1,-6),font,C.ink,true)
    end
    local motion=UI.button(content,"MotionToggle","",UDim2.fromOffset(0,toggleY),UDim2.fromOffset((w-60)/2,buttonH),C.pink,function() metadata.setPreference("motionEnabled",not Feedback.motionEnabled) end)
    motion.TextColor3=C.panel;motion.TextSize=UI.readableSize(17)
    local sound=UI.button(content,"SoundToggle","",UDim2.fromOffset((w-48)/2+6,toggleY),UDim2.fromOffset((w-60)/2,buttonH),C.yellow,function() metadata.setPreference("soundEnabled",not Feedback.soundEnabled) end)
    sound.TextSize=UI.readableSize(17)
    local hint="Тихий отклик уменьшает движения."
    UI.label(content,"PreferenceHint",hint,UDim2.fromOffset(0,hintY),UDim2.new(1,0,0,hintH),UI.readableSize(16),C.muted)
    local done=UI.button(box,"CloseGuide",active and "ПРОДОЛЖИТЬ  →" or "ИДЁМ ЗНАКОМИТЬСЯ  ♥",UDim2.fromOffset(24,closeY),UDim2.new(1,-48,0,buttonH),C.mint,close)
    done.TextColor3=C.panel;done.TextSize=UI.readableSize(18)
    if hasVersion then
        local text=version==0 and "Локальная сборка" or "Тестовая версия Roblox: "..tostring(version)
        local label=UI.label(box,"PlaceVersion",text,UDim2.fromOffset(24,h-36),UDim2.new(1,-48,0,20),UI.readableSize(13,10),C.muted)
        label.TextXAlignment=Enum.TextXAlignment.Center
    end
    Guide.updatePreferences(overlay)
    return overlay
end
return Guide
