local Harness=require("./support/ui_harness")
local Collection=require("../src/shared/Collection")
local Catalog=require("../src/shared/Catalog")
local Config=require("../src/shared/Config")
local Logic=require("../src/shared/GameLogic")
local Locations=require("../src/shared/Locations")
local Remix=require("../src/shared/DateRemix")
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local rect=Harness.rect
local screens={{240,320},{240,650},{280,320},{320,370},{320,480},{390,650},{1280,720}}
local function fixture(screen,character,variant)
    local f=Harness.new(screen[1],screen[2]);f.replays={};f.again=0;f.back=0;f.edits=0;f.disposed=0
    local icons=f.module("src/client/ToyIcons.luau")
    local album=f.module("src/client/Album.luau",{Collection=Collection,Locations=Locations})
    local sticker=f.module("src/client/SouvenirSticker.luau",{Remix=Remix,Icons=icons})
    local frame=f.module("src/client/PhotoFrame.luau",{Icons=icons})
    local book=f.module("src/client/StoryBook.luau",{Collection=Collection,Locations=Locations,Remix=Remix,Album=album,Icons=icons,Sticker=sticker,PhotoFrame=frame})
    local options=f.options()
    options.mount=function(_,settings)f.scene=settings;return {dispose=function()f.disposed+=1 end}end
    options.replay=function(stage)table.insert(f.replays,stage)end
    options.dateAgain=function()f.again+=1 end;options.back=function()f.back+=1 end;options.editPhoto=function()f.edits+=1 end
    options.scrollPosition=f.environment.Vector2.new(0,80);options.scrolled=function(value)f.reading=value end
    f.character=character or Catalog[1];f.variant=variant or Config.Variants[1]
    f.photo={key=Logic.key(f.character.id,f.variant.id),locationId="cafe",avatarUserId=42,avatarSnapshot={saved=true},photoPose="heart",photoFrame="perfect",
        scores={['1']=1,['2']=1,['3']=1},visitedLocations={cafe=true},remixScores={["cafe:long"]=1},pinnedSouvenir="cafe:long"}
    local before=serde.encode("json",f.photo)
    f.controller=book.mount(f.root,f.character,f.variant,f.photo,options)
    assert(serde.encode("json",f.photo)==before,"Opening a story mutates saved progress")
    f.box=f.controller.frame;f.content=f.controller.content or f.box
    return f
end
local function fits(f,node,pw,ph)
    local r=rect(node,pw,ph)
    assert(r.w>0 and f.ui.textHeight(node.Text,node.TextSize,r.w,node.Font=="bold")<=r.h,node.Name.." clips text")
    assert(r.x>=0 and r.y>=0 and r.x+r.w<=pw+1 and r.y+r.h<=ph+1,node.Name.." outside content")
    assert(node.TextSize*f.logical.scale>=9.9,node.Name.." too small")
    return r
end
test("Every character and variant keeps complete story text and personal memory on seven screens",function()
    for _,screen in screens do for _,character in Catalog do for _,variant in Config.Variants do
        local f=fixture(screen,character,variant);local box=f.box;local w,h=box.Size.X.Offset,box.Size.Y.Offset
        fits(f,box.children.Name,w,h)
        local theme=rect(box.Theme,w,h);fits(f,box.Theme.Label,theme.w,theme.h)
        local surface=f.content;local sw=f.logical.mobile and surface.Size.X.Offset or w
        local sh=f.logical.mobile and surface.CanvasSize.Y.Offset or h
        local photo=rect(surface.TogetherPostcard,sw,sh)
        fits(f,surface.TogetherPostcard.PhotoLocation,photo.w,photo.h)
        local art=rect(surface.TogetherPostcard.Photo,photo.w,photo.h)
        assert(art.h*f.logical.scale>=80)
        local tag=rect(surface.TogetherPostcard.Photo.PhotoStudioHint,art.w,art.h)
        fits(f,surface.TogetherPostcard.Photo.PhotoStudioHint.Label,tag.w,tag.h)
        fits(f,surface.Memory,sw,sh);assert(surface.Memory.Text==Collection.memento(character))
        local passport=rect(surface.DatePassport,sw,sh);fits(f,surface.DatePassport.Progress,passport.w,passport.h)
        local stamps=rect(surface.DatePassport.Stamps,passport.w,passport.h)
        for _,place in Locations.list do
            local stamp=surface.DatePassport.Stamps.children["Place_"..place.id];local r=rect(stamp,stamps.w,stamps.h)
            fits(f,stamp.Place,r.w,r.h)
        end
        for i=1,3 do
            local button=surface.children["ReplayStage_"..i];local r=rect(button,sw,sh)
            fits(f,button.Stage,r.w,r.h);fits(f,button.BestScore,r.w,r.h)
        end
        fits(f,surface.ReplayHint,sw,sh);fits(f,box.CloseStory,w,h);fits(f,box.DateAgain,w,h)
    end end end
end)
test("Short stories scroll complete photo content while all footer actions remain fixed and readable",function()
    for _,screen in screens do
        local longest=Catalog[1];for _,character in Catalog do if #character.name>#longest.name then longest=character end end
        local f=fixture(screen,longest);local box=f.box;local w,h=box.Size.X.Offset,box.Size.Y.Offset
        local back,again=rect(box.CloseStory,w,h),rect(box.DateAgain,w,h)
        assert(w*f.logical.scale<=screen[1] and h<=f.logical.height)
        assert(back.w*f.logical.scale>=44 and back.h*f.logical.scale>=44 and again.w*f.logical.scale>=44 and again.h*f.logical.scale>=44)
        assert(back.x+back.w+8<=again.x and again.y+again.h<=h-12)
        if f.logical.mobile then
            local view=rect(f.content,w,h);local title=rect(box.children.Name,w,h);local theme=rect(box.Theme,w,h)
            assert(title.y+title.h+8<=theme.y and theme.y+theme.h+12<=view.y)
            assert(view.h*f.logical.scale>=60 and view.y+view.h+10<=back.y)
            local previous=0
            for _,name in {"TogetherPostcard","Memory","DatePassport","ReplayStage_1","ReplayHint"}do
                local r=rect(f.content.children[name],view.w,f.content.CanvasSize.Y.Offset)
                assert(r.y>=previous and r.y+r.h<=f.content.CanvasSize.Y.Offset,name.." overlaps story content")
                previous=r.y+r.h
            end
            assert(f.content.CanvasPosition.Y==80)
            f.content.CanvasPosition=f.environment.Vector2.new(0,180);f.content.signals.CanvasPosition();assert(f.reading.Y==180)
            if f.content.CanvasSize.Y.Offset>view.h then assert(f.content.ScrollingEnabled and f.content.ScrollBarThickness>0)end
        else
            assert(f.controller.content==nil)
            for _,name in {"Memory","ReplayHint","DatePassport"}do local r=rect(box.children[name],w,h);assert(r.y+r.h+8<=back.y)end
        end
        local sw=f.logical.mobile and f.content.Size.X.Offset or w
        local sh=f.logical.mobile and f.content.CanvasSize.Y.Offset or h
        for i=1,3 do local r=rect(f.content.children["ReplayStage_"..i],sw,sh);assert(r.w*f.logical.scale>=44 and r.h*f.logical.scale>=44)end
    end
end)
test("Story actions preserve saved photo identity, decoration and a single viewer disposal",function()
    for _,screen in {{240,320},{390,650},{1280,720}}do
        local f=fixture(screen)
        for i=1,3 do f.content.children["ReplayStage_"..i].action()end
        f.box.DateAgain.action();f.box.CloseStory.action();f.content.TogetherPostcard.EditPhoto.action()
        f.controller.dispose();f.controller.dispose()
        assert(f.replays[1]==1 and f.replays[2]==2 and f.replays[3]==3 and f.again==1 and f.back==1 and f.edits==1)
        assert(f.scene.userId==42 and f.scene.avatarSnapshot==f.photo.avatarSnapshot and f.scene.locationId=="cafe" and f.scene.photoPose=="heart" and f.disposed==1)
        assert(f.content.TogetherPostcard.Photo.PinnedSouvenir:GetAttribute("SouvenirId")=="cafe:long")
        assert(f.content.TogetherPostcard.Photo.PhotoFrame:GetAttribute("FrameId")=="perfect")
    end
end)
test("Actual client restores story reading and rejects secondary actions while a request is pending",function()
    local source=fs.readFile("src/client/App.client.luau")
    local first=assert(source:find("showStory = function(",1,true));local last=assert(source:find("showPhotoStudio = function(",first,true))
    local capture={events={}};local photo={key=Logic.key(Catalog[1].id,"classic"),characterId=Catalog[1].id,variantId="classic"}
    local function record(...)table.insert(capture.events,{...})end
    local api=luau.load([[
        local showStory,modal,modalViewer,modalRebuild,busy
    ]]..source:sub(first,last-1)..[[
        return {open=showStory,rebuild=function()modalRebuild()end,lock=function(value)busy=value end}
    ]],{environment={Logic=Logic,state={album={photo}},UI={availableWidth=652,overlay=function()return {}end},height=760,mobile=true,
        closeModal=function()record("close")end,Feedback={pop=function()end},
        showPhotoStudio=function(key)record("photo",key)end,showRemixes=function(key)record("remixes",key)end,startGame=function(key,stage)record("play",key,stage)end,
        StoryBook={mount=function(_,_,_,_,options)capture.options=options;return {frame={}}end},
    }})()
    api.open(photo.key);capture.options.scrolled({Y=160});api.rebuild();assert(capture.options.scrollPosition.Y==160)
    local options=capture.options;local before=#capture.events
    api.lock(true);options.back();options.editPhoto();options.remixes();options.replay(2);options.dateAgain();assert(#capture.events==before)
    api.rebuild();assert(capture.options.scrollPosition.Y==160,"A busy resize loses the story")
    api.lock(false);options.replay(2);assert(capture.events[#capture.events][1]=="play" and capture.events[#capture.events][2]==photo.key and capture.events[#capture.events][3]==2)
    options.editPhoto();assert(capture.events[#capture.events][1]=="photo")
    options.remixes();assert(capture.events[#capture.events][1]=="remixes")
    before=#capture.events;api.open("missing");assert(#capture.events==before)
end)
fs.writeFile("prototype/evidence/story-book-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production book, UI and client handlers with controlled geometry/fonts/viewer; no Roblox rendering"},true))
print("Passed "..#tests.." actual story book checks")
