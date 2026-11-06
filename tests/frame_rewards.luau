local Harness=require("./support/ui_harness")
local Style=require("../src/shared/PhotoStyle")
local Collection=require("../src/shared/Collection")
local Config=require("../src/shared/Config")
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
local function fixture(w,h)
    local f=Harness.new(w,h)
    f.reward=f.module("src/client/FrameReward.luau",{Style=Style})
    local icons=f.module("src/client/ToyIcons.luau")
    local sticker=f.module("src/client/SouvenirSticker.luau",{Icons=icons,Remix=Remix})
    local decor=f.module("src/client/PhotoFrame.luau",{Icons=icons})
    local review=f.module("src/client/DateReview.luau",{Locations=Locations})
    local album=f.module("src/client/Album.luau",{Collection=Collection,Locations=Locations})
    f.result=f.module("src/client/ResultCard.luau",{FrameReward=f.reward,Collection=Collection,Config=Config,Locations=Locations,Album=album,Sticker=sticker,PhotoFrame=decor,DateReview=review})
    f.remix=f.module("src/client/RemixResult.luau",{FrameReward=f.reward,Remix=Remix,Locations=Locations,Icons=icons,DateReview=review})
    f.photo={locationId="park",visitedLocations={cafe=true,rooftop=true},scores={['1']=1,['2']=1,['3']=1},remixScores={}}
    for _,place in Locations.list do for _,mode in Remix.list do f.photo.remixScores[place.id..":"..mode.id]=1 end end
    return f
end
test("New frame cards fit actual result screens and keep a usable preview action",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}}do
        for _,remix in {false,true}do
            local f=fixture(screen[1],screen[2]);local options=f.options();local opened={}
            options.stage=3;options.photo=f.photo;options.character={name="Tung",personality="chill"}
            options.mount=function()end;options.back=function()end;options.continue=function()end
            options.editPhoto=function(id)table.insert(opened,id)end
            local response={passed=true,score=1,best=1,result="album",newFrames={"travel","perfect"}}
            if remix then response.remixId="long";response.locationId="park" end
            local box=(remix and f.remix or f.result).mount(f.root,response,options)
            local content=remix and box.RemixResultContent or box.ResultContent
            local reward=content.FrameReward
            local r=Harness.rect(reward,content.Size.X.Offset,content.Size.Y.Offset)
            assert(r.x>=0 and r.x+r.w<=content.Size.X.Offset and r.y+r.h<content.CanvasSize.Y.Offset)
            local nextBlock=remix and content.SouvenirSeal or content.ResultPhoto
            assert(r.y+r.h+12<=nextBlock.Position.Y.Offset)
            local previous=0
            for _,name in {"Title","Frames","TryFrame"}do
                local node=reward[name];local b=Harness.rect(node,r.w,r.h)
                assert(b.y>=previous and b.y+b.h<=r.h)
                assert(b.h>=f.ui.textHeight(node.Text,node.TextSize,b.w,node.Font=="bold"))
                previous=b.y+b.h
            end
            local action=Harness.rect(reward.TryFrame,r.w,r.h)
            assert(action.h*f.logical.scale>=44 and #opened==0)
            reward.TryFrame.action();assert(opened[1]=="travel" and f.photo.photoFrame==nil)
        end
    end
end)
test("Unknown, duplicate, default and locked frame IDs never invent a reward",function()
    local f=fixture(390,650)
    assert(f.reward.mount(f.root,{"classic","unknown","travel"},{},380,0,function()end)==0)
    assert(f.reward.mount(f.root,{"travel"},nil,380,0,function()end)==0)
    assert(f.reward.mount(f.root,{"travel"},f.photo,380,0,nil)==0)
    assert(f.reward.mount(f.root,{"travel","travel","unknown"},f.photo,380,0,function()end)>0)
    assert(f.root.FrameReward.Title.Text=="НОВАЯ РАМКА!")
    assert(f.root.FrameReward.Frames.Text==Style.frame("travel").name)
end)
test("Result preview routes on click with the new frame, survives rebuild and respects an active request",function()
    local source=fs.readFile("src/client/App.client.luau")
    local a=assert(source:find("showResult = function(",1,true))
    local b=assert(source:find("local function syncGameControls()",a,true))
    local f={options={},opened={},tabs={},focusKeys={}}
    local api=luau.load([[
        local showResult,modal,modalRebuild,modalViewer
        local busy=false
    ]]..source:sub(a,b-1)..[[
        return {show=showResult,rebuild=function()modalRebuild()end,busy=function(value)busy=value end}
    ]],{environment={
        closeModal=function()end,UI={overlay=function()return{}end,availableWidth=480},canvas={},C={},
        getMatch=function()return{characterId="a",variantId="classic"}end,
        Logic={character=function()return{id="a"}end},state={album={{key="story"}}},mobile=true,height=760,width=480,
        ResultCard={mount=function(_,_,options)table.insert(f.options,options);return{}end},
        Feedback={pop=function()end,play=function()end,burst=function()end},
        nav=function(tab,key)table.insert(f.tabs,tab);table.insert(f.focusKeys,key)end,
        showPhotoStudio=function(key,selection)table.insert(f.opened,{key=key,selection=selection})end,
    }})()
    api.show({passed=true,result="album",newFrames={"travel"}},"story",3,"park")
    api.rebuild();assert(#f.opened==0 and #f.tabs==0)
    api.busy(true);f.options[2].editPhoto("travel");assert(#f.opened==0)
    api.busy(false);f.options[2].editPhoto("travel")
    assert(f.tabs[1]=="album" and f.opened[1].key=="story" and f.opened[1].selection.frameId=="travel")
    assert(f.focusKeys[1]=="story")
    assert(f.opened[1].selection.poseId==nil)
    f.options[2].continue();assert(f.tabs[2]=="album" and f.focusKeys[2]=="story")
end)
fs.writeFile("prototype/evidence/frame-reward-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production reward/result geometry and preview route callbacks; no live render or service test"},true))
print("Passed "..#tests.." new frame reward checks")
