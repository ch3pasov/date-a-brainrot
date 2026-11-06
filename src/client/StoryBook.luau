local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Collection = require(Shared.Collection)
local Locations = require(Shared.Locations)
local Remix = require(Shared.DateRemix)
local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local Album = require(script.Parent.Album)
local Sticker = require(script.Parent.SouvenirSticker)
local PhotoFrame = require(script.Parent.PhotoFrame)
local C = UI.colors
local Book = {}
local function center(parent,name,text,position,size,font,color,bold)
    local label=UI.label(parent,name,text,position,size,font,color,bold)
    label.TextXAlignment=Enum.TextXAlignment.Center
    return label
end
function Book.mount(parent,character,variant,photo,options)
    local mobile=options.mobile
    local w=mobile and math.clamp((options.availableWidth or 480)-48,436,700) or 1020
    local innerW=w-48
    local nameFont=UI.readableSize(mobile and 26 or 31)
    local nameW=mobile and innerW or 690
    local nameH=math.max(44,UI.textHeight(character.name,nameFont,nameW,true))
    local perfect=Collection.perfect(photo)
    local themeText=variant.label..(perfect and " · ИДЕАЛЬНЫЙ ВАЙБ ♥" or " · НАША ИСТОРИЯ")
    local themeFont=UI.readableSize(12,10)
    local themeW=mobile and innerW or 258
    local themeH=math.max(28,UI.textHeight(themeText,themeFont,themeW-14,true)+8)
    local themeY=mobile and 18+nameH+10 or 35
    local progress=Remix.progress(photo)
    local backText,againText="← В альбом","РЕМИКСЫ · "..progress.collected.."/"..progress.total
    local actionFont=UI.readableSize(17)
    local backW=mobile and math.floor((w-60)*.42) or 252
    local againW=w-60-backW
    local actionH=math.max(66,UI.touchMinimum or 0,UI.textHeight(backText,actionFont,backW-16,true)+12,UI.textHeight(againText,actionFont,againW-16,true)+12)
    local h=math.min(mobile and 760 or 618+actionH,(options.availableHeight or 760)-24)
    local footerY=h-actionH-16
    local box=UI.frame(parent,"StoryDialog",UDim2.new(.5,-w/2,.5,-h/2),UDim2.fromOffset(w,h),C.card,4)
    box.ZIndex=2
    local paper=UI.frame(box,"Paper",UDim2.fromOffset(8,8),UDim2.new(1,-16,1,-16),C.panel,2)
    if not mobile then
        UI.frame(paper,"BookFold",UDim2.fromOffset(603,4),UDim2.new(0,2,1,-8),C.card,0)
        for i=1,8 do UI.frame(box,"Binding_"..i,UDim2.fromOffset(601,98+i*58),UDim2.fromOffset(20,3),C.ink,1).Rotation=-8 end
    end
    center(box,"Name",character.name,UDim2.fromOffset(24,18),UDim2.fromOffset(nameW,nameH),nameFont,C.ink,true)
    local badge=UI.pill(box,"Theme",themeText,UDim2.fromOffset(mobile and 24 or 738,themeY),themeW,perfect and C.yellow or UI.rgb(variant.color))
    badge.Size=UDim2.fromOffset(themeW,themeH);badge.Label.TextSize=themeFont
    local surface=box
    local viewportH
    if mobile then
        local top=themeY+themeH+14
        viewportH=footerY-top-12
        surface=UI.new("ScrollingFrame",{Name="StoryContent",Position=UDim2.fromOffset(24,top),Size=UDim2.fromOffset(innerW,viewportH),
            BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromOffset(0,0),ScrollBarThickness=3},box)
        if options.scrollPosition then surface.CanvasPosition=options.scrollPosition end
        if options.scrolled then surface:GetPropertyChangedSignal("CanvasPosition"):Connect(function()options.scrolled(surface.CanvasPosition)end)end
    end
    local memory=Collection.memento(character)
    local memoryFont=UI.readableSize(18)
    local memoryW=mobile and innerW or 546
    local memoryH=UI.textHeight(memory,memoryFont,memoryW,false)
    local photoY=mobile and 0 or math.max(120,18+nameH+20)
    local photoW=mobile and innerW or 570
    local photoH=mobile and math.max(260,math.min(360,math.ceil(120/(UI.scale or 1)))) or math.min(400,footerY-photoY-memoryH-30)
    local caption=Locations.get(photo.locationId).name
    local captionFont=UI.readableSize(mobile and 16 or 20)
    local captionH=math.max(31,UI.textHeight(caption,captionFont,photoW-24,true))
    local postcard=UI.frame(surface,"TogetherPostcard",UDim2.fromOffset(mobile and 0 or 24,photoY),UDim2.fromOffset(photoW,photoH),Color3.fromRGB(255,255,251),2)
    UI.stroke(postcard,C.ink).Thickness=2
    local art=UI.frame(postcard,"Photo",UDim2.fromOffset(9,9),UDim2.new(1,-18,1,-captionH-21),C.aqua,1)
    local viewer=options.mount(art,{modal=true,scene=true,photo=true,pair=true,locationId=photo.locationId or "park",
        userId=photo.avatarUserId or options.userId,avatarSnapshot=photo.avatarSnapshot,photoPose=photo.photoPose})
    Sticker.mount(art,photo);PhotoFrame.mount(art,photo)
    if options.editPhoto then
        local font=UI.readableSize(12,10)
        local text="ПОЗА И РАМКА →"
        local tagW=math.min(photoW-34,math.max(180,font*12))
        local tag=UI.pill(art,"PhotoStudioHint",text,UDim2.fromOffset(8,8),tagW,C.yellow)
        tag.Size=UDim2.fromOffset(tagW,UI.textHeight(text,font,tagW-14,true)+8);tag.Label.TextSize=font;tag.ZIndex=5
        local edit=UI.new("TextButton",{Name="EditPhoto",Text="",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=6},postcard)
        edit.Activated:Connect(options.editPhoto)
    end
    center(postcard,"PhotoLocation",caption,UDim2.new(0,12,1,-captionH-8),UDim2.new(1,-24,0,captionH),captionFont,C.ink,true)
    local tape=UI.frame(postcard,"Tape",UDim2.new(.5,-42,0,-8),UDim2.fromOffset(84,18),C.yellow,1)
    tape.Rotation=-4;tape.BackgroundTransparency=.18;tape.ZIndex=3
    local memoryY=photoY+photoH+14
    center(surface,"Memory",memory,UDim2.fromOffset(mobile and 0 or 36,memoryY),UDim2.fromOffset(memoryW,memoryH),memoryFont,C.muted)
    local stages={{"Переписка",Icons.phone},{"Звонок",Icons.video},{"Свидание",Icons.photo}}
    local stageFont=UI.readableSize(mobile and 14 or 19,10)
    local scoreFont=UI.readableSize(mobile and 24 or 29)
    local cellW=mobile and (innerW-16)/3 or 360
    local iconSize=mobile and UI.readableSize(38,18) or 62
    local stageNameY=mobile and iconSize+11 or 12
    local textW=mobile and cellW-4 or cellW-113
    local stageNameH=0
    for _,stage in stages do stageNameH=math.max(stageNameH,UI.textHeight(stage[1],stageFont,textW,true))end
    local scoreY=stageNameY+stageNameH+6
    local scoreH=UI.textHeight("100%",scoreFont,textW,true)
    local stageH=math.max(100,UI.touchMinimum or 0,scoreY+scoreH+10)
    local passportW=mobile and innerW or 360
    local passportH=Album.passportHeight(passportW)
    local passportY=mobile and memoryY+memoryH+14 or photoY+stageH*3+42
    local stageY=mobile and passportY+passportH+16 or photoY
    for i,stage in stages do
        local x=mobile and (i-1)*(cellW+8) or 636
        local y=mobile and stageY or stageY+(i-1)*(stageH+14)
        local panel=UI.button(surface,"ReplayStage_"..i,"",UDim2.fromOffset(x,y),UDim2.fromOffset(cellW,stageH),C.card,function()options.replay(i)end)
        stage[2](panel,UDim2.fromOffset(mobile and (cellW-iconSize)/2 or 17,mobile and 7 or 18),UDim2.fromOffset(iconSize,iconSize))
        local score=math.floor(((photo.scores or {})[tostring(i)] or 0)*100+.5)
        local textX=mobile and 2 or 99
        local name=UI.label(panel,"Stage",stage[1],UDim2.fromOffset(textX,stageNameY),UDim2.fromOffset(textW,stageNameH),stageFont,C.ink,true)
        local value=UI.label(panel,"BestScore",score.."%",UDim2.fromOffset(textX,scoreY),UDim2.fromOffset(textW,scoreH),scoreFont,C.mint,true)
        if mobile then name.TextXAlignment=Enum.TextXAlignment.Center;value.TextXAlignment=Enum.TextXAlignment.Center
        else UI.label(panel,"ReplayArrow","→",UDim2.new(1,-41,.5,-17),UDim2.fromOffset(29,34),27,C.pink,true)end
    end
    Album.passport(surface,photo,UDim2.fromOffset(mobile and 0 or 636,passportY),UDim2.fromOffset(passportW,passportH))
    local hint="Выбери этап — сыграем ещё?"
    local hintFont=UI.readableSize(12,10)
    local hintH=UI.textHeight(hint,hintFont,passportW,false)
    local hintY=mobile and stageY+stageH+10 or passportY+passportH+10
    center(surface,"ReplayHint",hint,UDim2.fromOffset(mobile and 0 or 636,hintY),UDim2.fromOffset(passportW,hintH),hintFont,C.muted)
    if mobile then
        local contentH=hintY+hintH+8
        surface.CanvasSize=UDim2.fromOffset(0,contentH);surface.ScrollingEnabled=contentH>viewportH
        surface.ScrollBarThickness=surface.ScrollingEnabled and 3 or 0
    end
    local back=UI.button(box,"CloseStory",backText,UDim2.fromOffset(24,footerY),UDim2.fromOffset(backW,actionH),C.card,options.back)
    back.TextSize=actionFont;back.TextWrapped=true
    local again=UI.button(box,"DateAgain",againText,UDim2.fromOffset(36+backW,footerY),UDim2.fromOffset(againW,actionH),C.mint,options.remixes or options.dateAgain)
    again.TextColor3=C.panel;again.TextSize=actionFont;again.TextWrapped=true
    return {frame=box,content=mobile and surface or nil,dispose=function()if viewer then viewer.dispose();viewer=nil end end}
end
return Book
