local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Style = require(Shared.PhotoStyle)
local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local Decor = require(script.Parent.PhotoFrame)
local Sticker = require(script.Parent.SouvenirSticker)
local C = UI.colors
local Booth = {}
function Booth.mount(parent, photo, options)
    local compact=options.mobile and (UI.scale or 1)<.5
    local w=compact and math.clamp((options.availableWidth or 480)-48,436,700) or (options.mobile and 436 or 1000)
    local h=math.min(736,(options.availableHeight or 760)-24)
    local actionH=math.max(66,UI.touchMinimum or 0)
    local font=UI.readableSize(18)
    local titleH=math.ceil(UI.readableSize(28)*1.4)
    local bodyTop=titleH+30
    local footerY=h-actionH-18
    local box=UI.frame(parent,"PhotoBoothDialog",UDim2.new(.5,-w/2,.5,-h/2),UDim2.fromOffset(w,h),C.panel,5)
    box.ZIndex=2
    UI.label(box,"Title","ФОТОБУДКА",UDim2.fromOffset(24,14),UDim2.new(1,-48,0,titleH),UI.readableSize(28),C.ink,true)
    local scroll=UI.new("ScrollingFrame",{Name="BoothContent",Position=UDim2.fromOffset(24,bodyTop),Size=UDim2.fromOffset(w-48,footerY-bodyTop-14),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,0),ScrollingEnabled=true},box)
    local selected=options.selection or {}
    local poseId=selected.poseId or photo.photoPose or "idle"
    local frameId=selected.frameId or photo.photoFrame or "classic"
    local saving=false
    local innerW=w-56
    local previewW=options.mobile and innerW or 430
    local previewH=options.mobile and 265 or 350
    local art=UI.frame(scroll,"Preview",UDim2.fromOffset(0,4),UDim2.fromOffset(previewW,previewH),C.aqua,4)
    UI.stroke(art,C.ink).Thickness=2
    local viewer=options.mount(art,{modal=true,scene=true,photo=true,pair=true,locationId=photo.locationId or "park",
        userId=photo.avatarUserId,avatarSnapshot=photo.avatarSnapshot,photoPose=poseId})
    Sticker.mount(art,photo)
    local frame=Decor.mount(art,{photoFrame=frameId})
    local controlsX=options.mobile and 0 or previewW+24
    local controlsW=innerW-controlsX
    local y=options.mobile and previewH+22 or 4
    local noteH=UI.textHeight("Выбери позу и рамку. Сохраним только по кнопке.",font,previewW,false)
    UI.label(scroll,"PreviewHint","Выбери позу и рамку. Сохраним только по кнопке.",UDim2.fromOffset(0,previewH+16),UDim2.fromOffset(previewW,noteH),font,C.muted)
    if options.mobile then y=previewH+noteH+30 end
    local headingH=math.ceil(font*1.4)
    UI.label(scroll,"PoseTitle","ПОЗА",UDim2.fromOffset(controlsX,y),UDim2.fromOffset(controlsW,headingH),font,C.ink,true)
    y+=headingH+8
    local poseH=math.max(82,UI.touchMinimum or 0,headingH+44)
    local poseW=(controlsW-10)/2
    local poseButtons,frameButtons={},{}
    local function changed()
        if options.changed then options.changed({poseId=poseId,frameId=frameId,scrollPosition=scroll.CanvasPosition}) end
    end
    local function updateButtons()
        for id,button in poseButtons do
            button.BackgroundColor3=id==poseId and C.yellow or C.card
            button:SetAttribute("Selected",id==poseId)
            button.Active=not saving;button.Selectable=button.Active
        end
        for id,button in frameButtons do
            local unlocked=Style.unlocked(photo,id)
            button.BackgroundColor3=id==frameId and C.yellow or C.card
            button:SetAttribute("Selected",id==frameId);button:SetAttribute("Unlocked",unlocked)
            button.Active=not saving and unlocked;button.Selectable=button.Active
        end
    end
    for i,pose in Style.poses do
        local button=UI.button(scroll,"Pose_"..pose.id,"",UDim2.fromOffset(controlsX+((i-1)%2)*(poseW+10),y+math.floor((i-1)/2)*(poseH+10)),UDim2.fromOffset(poseW,poseH),C.card,function()
            if saving then return end
            poseId=pose.id;viewer.setPhotoPose(poseId);updateButtons();changed()
        end)
        local iconSize=math.max(30,math.ceil(12/(UI.scale or 1)))
        if pose.id=="idle" then Icons.photo(button,UDim2.new(.5,-iconSize/2,0,8),UDim2.fromOffset(iconSize,iconSize))
        else Icons.gesture(button,pose.gesture,UDim2.new(.5,-iconSize/2,0,8),UDim2.fromOffset(iconSize,iconSize)) end
        UI.label(button,"Label",pose.name,UDim2.fromOffset(2,iconSize+12),UDim2.new(1,-4,1,-iconSize-16),font,C.ink,true).TextXAlignment=Enum.TextXAlignment.Center
        poseButtons[pose.id]=button
    end
    y+=2*(poseH+10)+8
    UI.label(scroll,"FrameTitle","РАМКА",UDim2.fromOffset(controlsX,y),UDim2.fromOffset(controlsW,headingH),font,C.ink,true)
    y+=headingH+8
    local hintFont=UI.readableSize(14,10)
    for _,style in Style.frames do
        local unlocked=Style.unlocked(photo,style.id)
        local hint=unlocked and "Открыта ✓" or style.goal.." · "..Style.progress(photo,style.id)
        local nameH=UI.textHeight(style.name,font,controlsW-24,true)
        local hintH=UI.textHeight(hint,hintFont,controlsW-24,false)
        local cardH=math.max(actionH,nameH+hintH+24)
        local button=UI.button(scroll,"Frame_"..style.id,"",UDim2.fromOffset(controlsX,y),UDim2.fromOffset(controlsW,cardH),C.card,function()
            if saving or not Style.unlocked(photo,style.id) then return end
            frameId=style.id
            if frame then frame:Destroy() end
            frame=Decor.mount(art,{photoFrame=frameId});updateButtons();changed()
        end)
        UI.label(button,"Label",style.name,UDim2.fromOffset(12,8),UDim2.new(1,-24,0,nameH),font,C.ink,true)
        UI.label(button,"Progress",hint,UDim2.fromOffset(12,nameH+12),UDim2.new(1,-24,0,hintH),hintFont,unlocked and C.mint or C.muted)
        frameButtons[style.id]=button;y+=cardH+10
    end
    scroll.CanvasSize=UDim2.fromOffset(0,math.max(y+8,previewH+noteH+24))
    scroll.CanvasPosition=selected.scrollPosition or Vector2.new(0,0)
    scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(changed)
    local back=UI.button(box,"CancelPhoto","Отмена",UDim2.fromOffset(24,footerY),UDim2.fromOffset((w-60)/2,actionH),C.card,function()if not saving then options.back() end end)
    back.TextSize=UI.readableSize(17)
    local save=UI.button(box,"SavePhoto","Сохранить ♥",UDim2.fromOffset(w/2+6,footerY),UDim2.fromOffset((w-60)/2,actionH),C.mint,function()if not saving then options.save(poseId,frameId) end end)
    save.TextSize=UI.readableSize(17);save.TextColor3=C.panel
    updateButtons()
    return {frame=box,dispose=function()if viewer then viewer.dispose();viewer=nil end end,
        setSaving=function(value)
            saving=value==true;updateButtons()
            back.Active=not saving;back.Selectable=back.Active;save.Active=not saving;save.Selectable=save.Active
            save.Text=saving and "Сохраняем…" or "Сохранить ♥"
        end}
end
return Booth
