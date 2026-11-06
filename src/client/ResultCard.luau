local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Locations = require(Shared.Locations)
local Album = require(script.Parent.Album)
local RemixResult = require(script.Parent.RemixResult)
local Sticker = require(script.Parent.SouvenirSticker)
local PhotoFrame = require(script.Parent.PhotoFrame)
local UI = require(script.Parent.UI)
local C = UI.colors
local Result = {}

function Result.mount(parent, result, options)
    if result.remixId then return RemixResult.mount(parent, result, options) end
    local stage, mobile = options.stage, options.mobile
    local selfie = result.passed and stage == 3 and options.character ~= nil
    local compact = mobile and (UI.scale or 1) < .5
    local w = compact and math.clamp((options.availableWidth or 480)-48,436,700) or (mobile and 436 or 650)
    local h = math.min(736,(options.availableHeight or 760)-24)
    local buttonH = math.max(66,UI.touchMinimum or 0)
    local footerY = h-buttonH-20
    local innerW = w-48
    local box = UI.frame(parent,"ResultDialog",UDim2.new(.5,-w/2,.5,-h/2),UDim2.fromOffset(w,h),C.panel,4)
    box.ZIndex=2
    local content=UI.new("ScrollingFrame",{
        Name="ResultContent",Position=UDim2.fromOffset(24,20),Size=UDim2.fromOffset(innerW,footerY-34),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0),ScrollingEnabled=true,
    },box)
    local usableW=innerW-8
    local font=UI.readableSize(18)
    local function text(parent,name,value,x,y,width,size,color,bold)
        local height=UI.textHeight(value,size,width,bold)
        local label=UI.label(parent,name,value,UDim2.fromOffset(x,y),UDim2.fromOffset(width,height),size,color or C.ink,bold)
        return height,label
    end
    local stageFont=UI.readableSize(12,10)
    local stageH=math.ceil(stageFont*1.4)
    local badge=UI.pill(content,"Stage",({"01  /  ПЕРЕПИСКА","02  /  НА СВЯЗИ","03  /  СВИДАНИЕ"})[stage],UDim2.fromOffset(0,0),math.min(usableW,math.max(190,stageFont*13)),C.pink)
    badge.Size=UDim2.fromOffset(badge.Size.X.Offset,stageH);badge.Label.TextSize=stageFont
    local title=not result.passed and "БЫВАЕТ!\nПОПРОБУЕМ ЕЩЁ?" or (result.practice and (result.improved and "НОВЫЙ\nРЕКОРД!" or "ЕЩЁ ОДИН\nОБЩИЙ ВАЙБ") or (selfie and "ВАШЕ\nПЕРВОЕ СЕЛФИ!" or (result.score==1 and "ИДЕАЛЬНЫЙ\nВАЙБ!" or "ЕСТЬ\nКОНТАКТ!")))
    local scoreFont=UI.readableSize(34)
    local scoreW=math.max(110,math.ceil(scoreFont*3.6))
    local scoreH=math.ceil(scoreFont*1.4)
    local captionH=math.ceil(stageFont*1.4)
    local sealH=scoreH+captionH+12
    local titleY=stageH+16
    local titleH=text(content,"Title",title,0,titleY,usableW-scoreW-18,UI.readableSize(mobile and 28 or 32),C.ink,true)
    local seal=UI.frame(content,"ScoreSeal",UDim2.fromOffset(usableW-scoreW,titleY),UDim2.fromOffset(scoreW,sealH),result.passed and C.yellow or C.card,8)
    seal.Rotation=3;UI.stroke(seal,C.ink).Thickness=2
    UI.label(seal,"Score",math.floor(result.score*100+.5).."%",UDim2.fromOffset(3,3),UDim2.new(1,-6,0,scoreH),scoreFont,C.ink,true).TextXAlignment=Enum.TextXAlignment.Center
    UI.label(seal,"Caption","ВАЙБ",UDim2.fromOffset(3,scoreH+5),UDim2.new(1,-6,0,captionH),stageFont,C.ink,true).TextXAlignment=Enum.TextXAlignment.Center
    local y=titleY+math.max(titleH,sealH)+20
    if selfie then
        local locationId=(options.photo and options.photo.locationId) or options.locationId or "park"
        local captionFont=UI.readableSize(17)
        local caption=Locations.get(locationId).name.."  ♥"
        local captionH=UI.textHeight(caption,captionFont,usableW-24,true)
        local artH=mobile and 240 or 272
        local photoH=artH+captionH+30
        local photo=UI.frame(content,"ResultPhoto",UDim2.fromOffset(0,y),UDim2.fromOffset(usableW,photoH),C.panel,2)
        UI.stroke(photo,C.ink).Thickness=2
        local art=UI.frame(photo,"ResultSelfie",UDim2.fromOffset(8,8),UDim2.new(1,-16,0,artH),C.aqua,1)
        options.mount(art,{modal=true,scene=true,photo=true,pair=true,locationId=locationId,
            userId=options.photo and options.photo.avatarUserId,avatarSnapshot=options.photo and options.photo.avatarSnapshot,photoPose=options.photo and options.photo.photoPose})
        PhotoFrame.mount(art,options.photo)
        Sticker.mount(art,options.photo)
        UI.label(photo,"PhotoCaption",caption,UDim2.fromOffset(12,artH+18),UDim2.new(1,-24,0,captionH),captionFont,C.pink,true).TextXAlignment=Enum.TextXAlignment.Center
        local tape=UI.frame(photo,"PhotoTape",UDim2.new(.5,-42,0,-7),UDim2.fromOffset(84,18),C.yellow,1)
        tape.Rotation=-4;tape.BackgroundTransparency=.2;tape.ZIndex=4
        y+=photoH+14
        if options.photo then
            local passportH=math.max(30,math.ceil(UI.readableSize(11,10)*1.5))
            Album.passport(content,options.photo,UDim2.fromOffset(0,y),UDim2.fromOffset(usableW,passportH))
            y+=passportH+16
        end
    else
        local senderH=text(content,"Sender",options.character and options.character.name or "Наш общий вайб",0,y,usableW,font,C.ink,true)
        y+=senderH+12
        local portraitW=math.floor(usableW*.34)
        local response=result.response or "Каждый раунд — ещё одна маленькая история."
        local bubbleW=usableW-portraitW-12
        local replyH=UI.textHeight(response,font,bubbleW-24,false)
        local rowH=math.max(186,replyH+24)
        local portrait=UI.frame(content,"ReactionPortrait",UDim2.fromOffset(0,y),UDim2.fromOffset(portraitW,rowH),C.aqua,3)
        UI.stroke(portrait,C.ink).Thickness=2
        if options.character then options.mount(portrait,{modal=true,scene=true,portrait=true,portraitAim=options.character.cameraAim,radius=3,locationId=Locations.forPersonality(options.character.personality)}) end
        local bubble=UI.frame(content,"LastReaction",UDim2.fromOffset(portraitW+12,y),UDim2.fromOffset(bubbleW,rowH),result.passed and C.aqua or C.card,9)
        UI.stroke(bubble,C.ink).Thickness=2
        UI.label(bubble,"Reply",response,UDim2.fromOffset(12,12),UDim2.new(1,-24,1,-24),font,C.ink)
        y+=rowH+18
    end
    if result.recap then
        local count=result.recap.total
        local cellW=(usableW-(count-1)*8)/count
        local cellH=math.max(36,math.ceil(UI.readableSize(24)*1.4))
        for i=1,count do
            local hit=result.recap.hits[i]
            local cell=UI.frame(content,"ResultAttempt_"..i,UDim2.fromOffset((i-1)*(cellW+8),y),UDim2.fromOffset(cellW,cellH),hit and C.mint or C.card,4)
            UI.stroke(cell,C.ink).Thickness=1
            UI.label(cell,"Mark",hit and "♥" or "×",UDim2.fromScale(0,0),UDim2.fromScale(1,1),UI.readableSize(24),hit and C.panel or C.pink,true).TextXAlignment=Enum.TextXAlignment.Center
        end
        y+=cellH+14
    end
    local total=result.recap and result.recap.total or (stage==2 and 6 or 4)
    local required=math.ceil(Config.MinigameThreshold*total)
    local goal=({"тёплые ответы","совпавшие жесты","совпадения"})[stage]
    local description
    if result.practice then
        description=result.passed and ("Рекорд: "..math.floor(result.best*100+.5).."%. Ваша история остаётся в альбоме.") or ("Рекорд: %d%%. Нужно %d из %d. Селфи сохранено — попробуем ещё?"):format(math.floor(result.best*100+.5),required,total)
    elseif result.passed then
        description=selfie and "Вы вдвоём, это место, этот момент. Забирай снимок в альбом!" or (stage==1 and "Переписка удалась. Пора увидеть друг друга — впереди видеозвонок." or "Есть общий ритм. Впереди свидание — выберем место?")
    else
        description=("Нужны %s: %d из %d. Можно повторить — мэтч остаётся с тобой."):format(goal,required,total)
    end
    y+=text(content,"Description",description,0,y,usableW,font,C.muted)+16
    content.CanvasSize=UDim2.fromOffset(0,y)
    content.CanvasPosition=options.scrollPosition or Vector2.new(0,0)
    if options.scrolled then content:GetPropertyChangedSignal("CanvasPosition"):Connect(function() options.scrolled(content.CanvasPosition) end) end
    UI.button(box,"BackToMatches",result.practice and "К истории" or "К мэтчам",UDim2.fromOffset(24,footerY),UDim2.fromOffset((w-60)/2,buttonH),C.card,options.back).TextSize=UI.readableSize(17)
    local nextText=result.practice and "Ещё раунд" or (result.passed and (result.result=="album" and "В альбом ♥" or (stage==1 and "Звонок →" or "Свидание →")) or "Ещё раз →")
    local nextButton=UI.button(box,"ResultContinue",nextText,UDim2.fromOffset(w/2+6,footerY),UDim2.fromOffset((w-60)/2,buttonH),C.mint,options.continue)
    nextButton.TextColor3=C.panel;nextButton.TextSize=UI.readableSize(17)
    return box
end
return Result
