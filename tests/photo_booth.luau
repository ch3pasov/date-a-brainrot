local Harness=require("./support/ui_harness")
local Style=require("../src/shared/PhotoStyle")
local Remix=require("../src/shared/DateRemix")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local roblox=require("@lune/roblox")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture(width,height,locked)
    local f=Harness.new(width,height);f.poses={};f.saves={};f.changes={};f.cancelled=0;f.disposed=0
    local icons=f.module("src/client/ToyIcons.luau")
    local decor=f.module("src/client/PhotoFrame.luau",{Icons=icons})
    local sticker=f.module("src/client/SouvenirSticker.luau",{Icons=icons,Remix=Remix})
    local booth=f.module("src/client/PhotoBooth.luau",{Style=Style,Icons=icons,Decor=decor,Sticker=sticker})
    local photo={locationId="park",avatarUserId=42,avatarSnapshot="saved",photoPose="heart",scores={},visitedLocations={},remixScores={}}
    if not locked then
        photo.scores={['1']=1,['2']=1,['3']=1};photo.visitedLocations={cafe=true,rooftop=true}
        for _,location in {"cafe","park","rooftop"} do for _,mode in Remix.list do photo.remixScores[location..":"..mode.id]=1 end end
        photo.pinnedSouvenir="cafe:long"
    end
    local options=f.options();options.selection={poseId="wave",frameId="classic",scrollPosition=roblox.Vector2.new(0,90)}
    options.mount=function(_,settings)
        f.scene=settings
        return {setPhotoPose=function(id)table.insert(f.poses,id)end,dispose=function()f.disposed+=1 end}
    end
    options.changed=function(value)table.insert(f.changes,value)end
    options.back=function()f.cancelled+=1 end
    options.save=function(pose,frame)table.insert(f.saves,{pose=pose,frame=frame})end
    f.controller=booth.mount(f.root,photo,options);f.photo=photo
    return f
end
test("Photo booth offers all poses and frame goals in scrollable content with fixed 44px actions",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}} do
        local f=fixture(screen[1],screen[2],false);local box=f.controller.frame
        local w,h=box.Size.X.Offset,box.Size.Y.Offset
        assert(w*f.logical.scale<=screen[1] and h<=f.logical.height)
        local content=box.BoothContent;local r=Harness.rect(content,w,h)
        local preview=Harness.rect(box.Preview,w,h)
        local save,back=Harness.rect(box.SavePhoto,w,h),Harness.rect(box.CancelPhoto,w,h)
        assert(r.h>100 and r.y+r.h+12<=save.y and back.x+back.w+8<=save.x)
        assert(preview.x>=0 and preview.x+preview.w<=w and preview.y+preview.h<save.y)
        if f.logical.mobile then assert(preview.y+preview.h+12<=r.y)
        else assert(preview.x+preview.w+12<=r.x)end
        assert(box.Preview.Parent==box and not content.Preview,"The preview must remain outside the scrolling controls")
        assert(save.h*f.logical.scale>=44 and back.h*f.logical.scale>=44)
        for _,name in {"Pose_idle","Pose_wave","Pose_heart","Pose_dance","Frame_classic","Frame_travel","Frame_perfect","Frame_souvenirs"} do
            local button=content[name];local b=Harness.rect(button,r.w,r.h)
            assert(b.w*f.logical.scale>=44 and b.h*f.logical.scale>=44)
            assert(b.x>=0 and b.x+b.w<=r.w and b.y+b.h<=content.CanvasSize.Y.Offset)
            local label=Harness.rect(button.Label,b.w,b.h)
            assert(label.h>=button.Label.TextSize*1.15 and label.y+label.h<=b.h)
        end
        local last=Harness.rect(content.Frame_souvenirs,r.w,r.h)
        assert(last.y+last.h<=content.CanvasSize.Y.Offset and content.CanvasPosition.Y==90)
        assert(f.scene.userId==42 and f.scene.avatarSnapshot=="saved" and f.scene.photoPose=="wave")
    end
end)
test("Choosing a pose or earned frame changes only the preview until save and preserves the pinned sticker",function()
    local f=fixture(390,650,false);local box=f.controller.frame;local content=box.BoothContent
    for _,id in {"heart","dance","idle","wave"} do content["Pose_"..id].action();assert(content["Pose_"..id]:GetAttribute("Selected")) end
    for _,id in {"perfect","travel","souvenirs","classic"} do
        content["Frame_"..id].action();assert(content["Frame_"..id]:GetAttribute("Selected"))
        assert(box.Preview.PinnedSouvenir:GetAttribute("SouvenirId")=="cafe:long")
        if id=="classic" then assert(box.Preview.PhotoFrame==nil) else assert(box.Preview.PhotoFrame:GetAttribute("FrameId")==id) end
    end
    assert(#f.saves==0 and f.photo.photoPose=="heart" and f.photo.photoFrame==nil and #f.poses==4)
    content.Frame_perfect.action();box.SavePhoto.action()
    assert(#f.saves==1 and f.saves[1].pose=="wave" and f.saves[1].frame=="perfect")
    content.CanvasPosition=roblox.Vector2.new(0,180);content.signals.CanvasPosition()
    assert(f.changes[#f.changes].scrollPosition.Y==180 and f.changes[#f.changes].frameId=="perfect")
    box.CancelPhoto.action();assert(f.cancelled==1 and f.photo.photoPose=="heart")
    f.controller.dispose();f.controller.dispose();assert(f.disposed==1)
end)
test("Locked frames display progress and saving disables preview, cancel and duplicate saves",function()
    local f=fixture(320,480,true);local box=f.controller.frame;local content=box.BoothContent
    for _,id in {"travel","perfect","souvenirs"} do
        local button=content["Frame_"..id];assert(not button.Active and not button:GetAttribute("Unlocked"))
        button.action();assert(not button:GetAttribute("Selected"))
    end
    assert(content.Frame_travel.Progress.Text:find("Места 1/3",1,true))
    f.controller.setSaving(true)
    content.Pose_dance.action();content.Frame_classic.action();box.SavePhoto.action();box.CancelPhoto.action()
    assert(#f.poses==0 and #f.changes==0 and #f.saves==0 and f.cancelled==0)
    assert(not box.SavePhoto.Active and box.SavePhoto.Text=="Сохраняем…")
    f.controller.setSaving(false)
    assert(box.SavePhoto.Active and content.Pose_heart.Active and not content.Frame_perfect.Active)
    box.SavePhoto.action();assert(f.saves[1].pose=="wave" and f.saves[1].frame=="classic")
end)
fs.writeFile("prototype/evidence/photo-booth-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production booth controls, geometry and preview callbacks with controlled UI/scene; no engine rendering"},true))
print("Passed "..#tests.." photo booth checks")
