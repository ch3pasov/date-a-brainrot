local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Logic = require(Shared.GameLogic)
local Locations = require(Shared.Locations)
local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Board = {}
function Board.mount(parent, ideas, options)
    local w=options.mobile and math.clamp((options.availableWidth or 480)-48,436,700) or 1000
    local h=math.min(736,(options.availableHeight or 760)-24)
    local font=UI.readableSize(17)
    local actionH=math.max(66,UI.touchMinimum or 0)
    local titleH=UI.textHeight("КУДА ДАЛЬШЕ?",UI.readableSize(28),w-48,true)
    local hint="Выбери маленькое приключение. Прогресс уже с тобой."
    local hintH=UI.textHeight(hint,font,w-48,false)
    local headerH=titleH+hintH+36
    local footerY=h-actionH-18
    local box=UI.frame(parent,"JourneyDialog",UDim2.new(.5,-w/2,.5,-h/2),UDim2.fromOffset(w,h),C.panel,5)
    box.ZIndex=2
    UI.label(box,"Title","КУДА ДАЛЬШЕ?",UDim2.fromOffset(24,14),UDim2.new(1,-48,0,titleH),UI.readableSize(28),C.ink,true)
    UI.label(box,"Hint",hint,UDim2.fromOffset(24,titleH+22),UDim2.new(1,-48,0,hintH),font,C.muted)
    local list=UI.new("ScrollingFrame",{Name="Ideas",Position=UDim2.fromOffset(24,headerH),Size=UDim2.fromOffset(w-48,footerY-headerH-12),
        BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromOffset(0,0),ScrollBarThickness=4,ScrollingEnabled=true},box)
    local columns=options.mobile and 1 or math.min(3,#ideas)
    local cardW=(w-60-(columns-1)*14)/columns
    local layouts,maxH={},0
    for _,idea in ideas do
        local character=idea.characterId and Logic.character(idea.characterId)
        local l={character=character}
        l.titleH=UI.textHeight(idea.title,UI.readableSize(21),cardW-28,true)
        l.nameH=UI.textHeight(character and character.name or "ВПЕРЕДИ НОВАЯ ИСТОРИЯ",font,cardW-28,true)
        l.noteH=UI.textHeight(idea.note,font,cardW-28,false)
        l.progressH=idea.total and math.ceil(font*1.4)+20 or 0
        l.height=14+l.titleH+12+160+12+l.nameH+10+l.noteH+12+l.progressH+actionH+24
        maxH=math.max(maxH,l.height);table.insert(layouts,l)
    end
    local viewers,top={},0
    for i,idea in ideas do
        local l=layouts[i];local cardH=options.mobile and l.height or maxH
        local card=UI.frame(list,"Idea_"..idea.kind,UDim2.fromOffset((i-1)%columns*(cardW+14),options.mobile and top or 0),UDim2.fromOffset(cardW,cardH),C.card,5)
        UI.stroke(card,C.ink).Thickness=2
        UI.label(card,"Title",idea.title,UDim2.fromOffset(14,12),UDim2.new(1,-28,0,l.titleH),UI.readableSize(21),C.ink,true)
        local y=12+l.titleH+12
        local art=UI.frame(card,"Preview",UDim2.fromOffset(14,y),UDim2.new(1,-28,0,160),C.aqua,4)
        if l.character then
            local view=options.mount(art,l.character.id,idea.variantId,{modal=true,scene=true,portrait=true,portraitAim=l.character.cameraAim,locationId=idea.locationId or Locations.forPersonality(l.character.personality)})
            if view then table.insert(viewers,view) end
        else Icons.phone(art,UDim2.new(.5,-44,.5,-65),UDim2.fromOffset(88,130)) end
        y+=172
        UI.label(card,"Character",l.character and l.character.name or "ВПЕРЕДИ НОВАЯ ИСТОРИЯ",UDim2.fromOffset(14,y),UDim2.new(1,-28,0,l.nameH),font,C.ink,true)
        y+=l.nameH+10
        UI.label(card,"Note",idea.note,UDim2.fromOffset(14,y),UDim2.new(1,-28,0,l.noteH),font,C.muted)
        y+=l.noteH+12
        if idea.total then
            local bar=UI.frame(card,"ProgressBar",UDim2.fromOffset(14,y),UDim2.new(1,-28,0,8),C.panel,4)
            UI.frame(bar,"Fill",UDim2.fromScale(0,0),UDim2.fromScale(math.clamp(idea.progress/idea.total,0,1),1),C.mint,4)
            UI.label(card,"Progress",("%d / %d"):format(idea.progress,idea.total),UDim2.fromOffset(14,y+12),UDim2.new(1,-28,0,l.progressH-12),font,C.mint,true)
        end
        local button=UI.button(card,"ChooseIdea",idea.action,UDim2.fromOffset(14,cardH-actionH-12),UDim2.new(1,-28,0,actionH),C.mint,function()options.choose(idea)end)
        button.TextColor3=C.panel;button.TextSize=font;button.TextWrapped=true
        top+=cardH+14
    end
    list.CanvasSize=UDim2.fromOffset(0,options.mobile and top or maxH+14)
    list.CanvasPosition=options.scrollPosition or Vector2.new(0,0)
    if options.scrolled then list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()options.scrolled(list.CanvasPosition)end) end
    local footerW=options.more and (w-60)/2 or w-48
    local close=UI.button(box,"CloseIdeas","← В альбом",UDim2.fromOffset(24,footerY),UDim2.fromOffset(footerW,actionH),C.card,options.back)
    close.TextSize=font;close.TextWrapped=true
    if options.more then
        local more=UI.button(box,"MoreIdeas","Ещё идеи ↻",UDim2.fromOffset(36+footerW,footerY),UDim2.fromOffset(footerW,actionH),C.yellow,options.more)
        more.TextSize=font;more.TextWrapped=true
    end
    return {frame=box,dispose=function()for _,view in viewers do view.dispose()end;table.clear(viewers)end}
end
return Board
