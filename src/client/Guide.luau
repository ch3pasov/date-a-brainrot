local UI = require(script.Parent.UI)
local Feedback = require(script.Parent.Feedback)
local Icons = require(script.Parent.ToyIcons)
local Remix = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").DateRemix)
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
    local w = mobile and math.max(436,math.min(700,(metadata.availableWidth or 480)-44)) or 700
    local version = metadata.placeVersion
    local hasVersion = type(version)=="number" and version>=0 and version<math.huge and version%1==0
    local stage = metadata.stage
    local active = type(stage)=="number" and stage>=1 and stage<=3 and stage%1==0
    local remix = active and stage == 3 and Remix.get(metadata.remixId)
    local steps = active and instructions[stage] or {
        "Сердце — лайк. Крестик — дальше.",
        "Ответ может прийти, пока тебя нет.",
        "Чат, жесты, свидание — ваше селфи.",
    }
    if remix then steps = {
        remix.id == "long" and "Запомни шесть предметов. Это большой заказ!" or "Запомни четыре предмета. Сейчас будет перемотка!",
        remix.id == "reverse" and "Повтори от последнего предмета к первому." or "Повтори предметы в том же порядке.",
        ("Нужно %d из %d — и сувенир ваш!"):format(remix.required, remix.total),
    } end
    local title=active and ({"ПЕРЕПИСКА","ПОВТОРИ ЖЕСТ","ЗАПОМНИ ПОРЯДОК"})[stage] or "КАК ПОЙМАТЬ ВАЙБ"
    local titleFont=UI.readableSize(mobile and 28 or 35)
    local titleH=UI.textHeight(title,titleFont,w-48,true)
    local contentTop=16+titleH+12
    local font=UI.readableSize(17)
    local numberFont=UI.readableSize(21,10)
    local sealW=math.max(36,math.ceil(numberFont*1.5))
    local detailX=sealW+26
    local rowHeights={};local rowTops={};local y=140
    for i,text in steps do
        rowTops[i]=y
        rowHeights[i]=math.max(60,sealW+12,UI.textHeight(text,font,w-48-detailX-10,true)+12)
        y+=rowHeights[i]+10
    end
    local collectionTitle="ПОСЛЕ ПЕРВОГО СЕЛФИ"
    local collectionNotes={
        "Открой фото в альбоме. В ремиксах ждут шесть сувениров — любимый можно прикрепить к фото.",
        "Три места, шесть сувениров и 100% на трёх этапах открывают разные рамки для этой истории.",
        "В фотобудке выбирай позу и рамку. Кнопка «Идеи» поможет найти следующее занятие.",
    }
    local sectionY,sectionH,noteTops,noteHeights,ideasY
    if not active then
        sectionY=y+8;sectionH=UI.textHeight(collectionTitle,font,w-48,true)
        y=sectionY+sectionH+12;noteTops={};noteHeights={}
        for i,text in collectionNotes do
            noteTops[i]=y;noteHeights[i]=UI.textHeight(text,font,w-72,false)+20
            y+=noteHeights[i]+10
        end
    end
    local toggleFont=UI.readableSize(17)
    local buttonH=math.max(66,UI.touchMinimum or 0,UI.textHeight("♪ ЗВУК\nВКЛЮЧЁН",toggleFont,(w-60)/2-16,true)+12)
    if not active and metadata.ideas then ideasY=y+2;y=ideasY+buttonH+16 end
    local toggleY=y+10
    local hintY=toggleY+buttonH+12
    local hint="Тихий отклик уменьшает движения."
    local hintH=UI.textHeight(hint,UI.readableSize(16),w-48,false)
    local contentH=hintY+hintH+8
    local doneText=active and "ПРОДОЛЖИТЬ  →" or "ИДЁМ ЗНАКОМИТЬСЯ  ♥"
    local doneFont=UI.readableSize(18)
    local doneH=math.max(66,UI.touchMinimum or 0,UI.textHeight(doneText,doneFont,w-64,true)+12)
    local versionText=hasVersion and (version==0 and "Локальная сборка" or "Тестовая версия Roblox: "..tostring(version))
    local versionFont=UI.readableSize(13,10)
    local versionH=hasVersion and UI.textHeight(versionText,versionFont,w-48,false) or 0
    local footer=hasVersion and versionH+24 or 20
    local preferredH=contentTop+contentH+doneH+footer+12
    local h=math.min(preferredH,(metadata.availableHeight or 760)-24)
    local closeY=h-doneH-footer
    local scrollH=closeY-contentTop-12
    local box = UI.frame(overlay,"GuideDialog",UDim2.new(.5,-w/2,.5,-h/2),UDim2.fromOffset(w,h),C.panel,4)
    box.ZIndex=2; Feedback.pop(box,.94)
    UI.label(box,"Title",title,UDim2.fromOffset(24,16),UDim2.new(1,-48,0,titleH),titleFont,C.ink,true)
    local content=UI.new("ScrollingFrame",{
        Name="GuideContent",Position=UDim2.fromOffset(24,contentTop),Size=UDim2.fromOffset(w-48,scrollH),
        BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromOffset(0,contentH),
        ScrollingEnabled=contentH>scrollH,ScrollBarThickness=contentH>scrollH and 3 or 0,
    },box)
    if metadata.scrollPosition then content.CanvasPosition=metadata.scrollPosition end
    if metadata.scrolled then content:GetPropertyChangedSignal("CanvasPosition"):Connect(function()metadata.scrolled(content.CanvasPosition)end)end
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
        local row=UI.frame(content,"Step_"..i,UDim2.fromOffset(0,rowTops[i]),UDim2.new(1,0,0,rowHeights[i]),C.card,4)
        local number=UI.frame(row,"NumberSeal",UDim2.new(0,12,.5,-sealW/2),UDim2.fromOffset(sealW,sealW),i==2 and C.pink or C.mint,18)
        local n=UI.label(number,"Number",tostring(i),UDim2.fromScale(0,0),UDim2.fromScale(1,1),numberFont,C.panel,true);n.TextXAlignment=Enum.TextXAlignment.Center
        UI.label(row,"Detail",text,UDim2.fromOffset(detailX,6),UDim2.new(1,-detailX-10,1,-12),font,C.ink,true)
    end
    if not active then
        UI.label(content,"CollectionTitle",collectionTitle,UDim2.fromOffset(0,sectionY),UDim2.new(1,0,0,sectionH),font,C.ink,true)
        for i,text in collectionNotes do
            local note=UI.frame(content,"CollectionNote_"..i,UDim2.fromOffset(0,noteTops[i]),UDim2.new(1,0,0,noteHeights[i]),C.card,4)
            UI.label(note,"Detail",text,UDim2.fromOffset(12,10),UDim2.new(1,-24,1,-20),font,C.ink)
        end
        if ideasY then
            local button=UI.button(content,"OpenIdeas","Подобрать идею →",UDim2.fromOffset(0,ideasY),UDim2.new(1,0,0,buttonH),C.mint,metadata.ideas)
            button.TextColor3=C.panel;button.TextSize=font;button.TextWrapped=true
        end
    end
    local motion=UI.button(content,"MotionToggle","",UDim2.fromOffset(0,toggleY),UDim2.fromOffset((w-60)/2,buttonH),C.pink,function() metadata.setPreference("motionEnabled",not Feedback.motionEnabled) end)
    motion.TextColor3=C.panel;motion.TextSize=toggleFont;motion.TextWrapped=true
    local sound=UI.button(content,"SoundToggle","",UDim2.fromOffset((w-48)/2+6,toggleY),UDim2.fromOffset((w-60)/2,buttonH),C.yellow,function() metadata.setPreference("soundEnabled",not Feedback.soundEnabled) end)
    sound.TextSize=toggleFont;sound.TextWrapped=true
    UI.label(content,"PreferenceHint",hint,UDim2.fromOffset(0,hintY),UDim2.new(1,0,0,hintH),UI.readableSize(16),C.muted)
    local done=UI.button(box,"CloseGuide",doneText,UDim2.fromOffset(24,closeY),UDim2.new(1,-48,0,doneH),C.mint,close)
    done.TextColor3=C.panel;done.TextSize=doneFont;done.TextWrapped=true
    if hasVersion then
        local label=UI.label(box,"PlaceVersion",versionText,UDim2.fromOffset(24,h-versionH-12),UDim2.new(1,-48,0,versionH),versionFont,C.muted)
        label.TextXAlignment=Enum.TextXAlignment.Center
    end
    Guide.updatePreferences(overlay)
    return overlay
end
return Guide
