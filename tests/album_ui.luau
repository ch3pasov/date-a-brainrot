local Harness=require("./support/ui_harness")
local Config=require("../src/shared/Config")
local Logic=require("../src/shared/GameLogic")
local Catalog=require("../src/shared/Catalog")
local Collection=require("../src/shared/Collection")
local Locations=require("../src/shared/Locations")
local ListLayout=require("../src/shared/ListLayout")
local FeedLayout=require("../src/shared/FeedLayout")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local roblox=require("@lune/roblox")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local rect=Harness.rect
test("Album keeps larger text, passport, goal and scroll area separate on compact screens",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}} do
        local f=Harness.new(screen[1],screen[2]);local l=f.logical;f.ui.availableWidth=screen[1]/l.scale
        local shell=FeedLayout.resolve(l.width,l.height,l.mobile,l.touchMinimum)
        local bodyW=l.mobile and 436 or l.width-52
        local bodyH=l.mobile and shell.dockY-shell.bodyY-18 or l.height-214
        local body=f.ui.frame(f.root,"Body",roblox.UDim2.fromOffset(0,0),roblox.UDim2.fromOffset(bodyW,bodyH))
        local remix=require("../src/shared/DateRemix")
        local icons=f.module("src/client/ToyIcons.luau")
        local sticker=f.module("src/client/SouvenirSticker.luau",{Remix=remix,Icons=icons})
        local frame=f.module("src/client/PhotoFrame.luau",{Icons=icons})
        local album=f.module("src/client/Album.luau",{Config=Config,Logic=Logic,Collection=Collection,Locations=Locations,ListLayout=ListLayout,Empty={},Sticker=sticker,PhotoFrame=frame})
        local photo={key=Catalog[1].id..":cosmic",characterId=Catalog[1].id,variantId="cosmic",locationId="cafe",scores={['1']=1,['2']=1,['3']=1},remixScores={["cafe:long"]=1},pinnedSouvenir="cafe:long",photoPose="dance",photoFrame="perfect"}
        local opened,scene,ideas
        album.render(body,{album={photo}},l.mobile,1,{mount=function(_,_,_,options)scene=options end,open=function(key)opened=key end,ideas=function()ideas=true end})
        bodyW=body.Size.X.Offset
        local title,description,grid=rect(body.Title,bodyW,bodyH),rect(body.Description,bodyW,bodyH),rect(body.AlbumGrid,bodyW,bodyH)
        assert(title.y+title.h<=description.y and description.y+description.h<grid.y)
        if body.Count_classic then
            local counts=rect(body.Count_classic,bodyW,bodyH)
            assert(description.y+description.h<=counts.y and counts.y+counts.h<grid.y)
        end
        assert(grid.h>100 and grid.y+grid.h<=bodyH)
        local button=rect(body.JourneyIdeas,bodyW,bodyH)
        assert(description.x+description.w+8<=button.x and button.y+button.h<grid.y)
        assert(button.w*l.scale>=44 and button.h*l.scale>=44)
        body.JourneyIdeas.action();assert(ideas)
        local photoNode=body.AlbumGrid.Selfie_1
        local cell=body.AlbumGrid.UIGridLayout.CellSize
        local w=grid.w*cell.X.Scale+cell.X.Offset;local h=cell.Y.Offset
        local previous=0
        for _,name in {"Photo","Name","Caption","DatePassport","OpenHint"} do
            local child=photoNode.children[name];local r=rect(child,w,h)
            assert(r.y>=previous and r.y+r.h<=h,name.." overlaps another album element")
            if child.TextSize then assert(r.h>=child.TextSize*1.2,name.." cannot fit its font") end
            previous=r.y+r.h
        end
        assert(photoNode.OpenHint.Text:find("Парк",1,true))
        local art=rect(photoNode.Photo,w,h);local pinned=rect(photoNode.Photo.PinnedSouvenir,art.w,art.h)
        assert(pinned.x>=0 and pinned.y>=0 and pinned.x+pinned.w<=art.w and pinned.y+pinned.h<=art.h)
        assert(photoNode.Photo.PinnedSouvenir:GetAttribute("SouvenirId")=="cafe:long")
        assert(scene.photoPose=="dance" and photoNode.Photo.PhotoFrame:GetAttribute("FrameId")=="perfect")
        assert(body.Description.Text:find("Сувениров: 1",1,true))
        photoNode.OpenStory.action();assert(opened==photo.key)
    end
end)
test("Full albums keep a usable list, complete captions and correct photo actions on every page",function()
    local Remix=require("../src/shared/DateRemix")
    local albumData={}
    for _,character in Catalog do
        for index,variant in Config.Variants do
            local photo={key=Logic.key(character.id,variant.id),characterId=character.id,variantId=variant.id,
                locationId=Locations.list[(#albumData)%3+1].id,scores={},remixScores={}}
            if index==2 then photo.scores={['1']=1,['2']=1,['3']=1}end
            if index>=3 then photo.visitedLocations={};for _,place in Locations.list do photo.visitedLocations[place.id]=true end end
            if index==4 then
                for _,place in Locations.list do for _,mode in Remix.list do photo.remixScores[Remix.key(place.id,mode.id)]=1 end end
                photo.photoFrame="souvenirs";photo.pinnedSouvenir="cafe:long"
            end
            table.insert(albumData,photo)
        end
    end
    for _,screen in {{240,320},{240,650},{280,320},{320,370},{320,480},{390,650},{1280,720}}do
        for page=1,math.ceil(#albumData/6)do
            local h=Harness.new(screen[1],screen[2]);local l=h.logical
            h.ui.availableWidth=screen[1]/l.scale
            local shell=FeedLayout.resolve(l.width,l.height,l.mobile,l.touchMinimum)
            local bh=l.mobile and shell.dockY-shell.bodyY-18 or l.height-214
            local body=h.ui.frame(h.root,"Body",roblox.UDim2.fromOffset(22,shell.bodyY),roblox.UDim2.fromOffset(l.mobile and 436 or l.width-52,bh))
            local icons=h.module("src/client/ToyIcons.luau")
            local album=h.module("src/client/Album.luau",{Config=Config,Logic=Logic,Collection=Collection,Locations=Locations,ListLayout=ListLayout,
                Sticker=h.module("src/client/SouvenirSticker.luau",{Remix=Remix,Icons=icons}),PhotoFrame=h.module("src/client/PhotoFrame.luau",{Icons=icons})})
            local opened,selected,ideas
            local result=album.render(body,{album=albumData},l.mobile,page,{mount=function()end,open=function(key)opened=key end,
                page=function(value)selected=value end,ideas=function()ideas=true end,focusKey=albumData[#albumData].key})
            local bw=body.Size.X.Offset;local grid=rect(body.AlbumGrid,bw,bh)
            assert(grid.h*l.scale>=44,string.format("%dx%d full album has %.2f pixels of list",screen[1],screen[2],grid.h*l.scale))
            local pager=rect(body.PreviousAlbum,bw,bh)
            assert(grid.y+grid.h+8<=pager.y and pager.y+pager.h<=bh)
            local function fits(node,pw,ph)
                local r=rect(node,pw,ph)
                assert(r.w>0 and r.h>=h.ui.textHeight(node.Text,node.TextSize,r.w,node.Font=="bold"),node.Name.." clips text")
                assert(r.x>=0 and r.y>=0 and r.x+r.w<=pw+1 and r.y+r.h<=ph+1,node.Name.." outside container")
                return r
            end
            fits(body.Title,bw,bh);fits(body.Description,bw,bh)
            local action=fits(body.JourneyIdeas,bw,bh);assert(action.y+action.h<grid.y)
            for _,variant in Config.Variants do
                local counter=body.children["Count_"..variant.id]
                if counter then local r=rect(counter,bw,bh);fits(counter.Label,r.w,r.h);assert(r.y+r.h<grid.y)end
            end
            local cell=body.AlbumGrid.UIGridLayout.CellSize;local cw,ch=grid.w*cell.X.Scale+cell.X.Offset,cell.Y.Offset
            for i=(page-1)*6+1,math.min(page*6,#albumData)do
                local photo=body.AlbumGrid.children["Selfie_"..i]
                local previous=rect(photo.Photo,cw,ch);local bottom=previous.y+previous.h
                for _,name in {"Name","Caption","DatePassport","OpenHint"}do
                    local child=photo.children[name];local r=rect(child,cw,ch)
                    assert(r.y>=bottom and r.y+r.h<=ch,name.." overlaps another photo element")
                    if child.Text then fits(child,cw,ch)end
                    bottom=r.y+r.h
                end
                local art=rect(photo.Photo,cw,ch);local tag=rect(photo.Photo.Together,art.w,art.h)
                fits(photo.Photo.Together.Label,tag.w,tag.h)
                local passport=rect(photo.DatePassport,cw,ch);fits(photo.DatePassport.Progress,passport.w,passport.h)
                local stamps=rect(photo.DatePassport.Stamps,passport.w,passport.h)
                for _,place in Locations.list do
                    local stamp=photo.DatePassport.Stamps.children["Place_"..place.id];local r=rect(stamp,stamps.w,stamps.h)
                    fits(stamp.Place,r.w,r.h)
                end
                photo.OpenStory.action();assert(opened==albumData[i].key)
            end
            body.JourneyIdeas.action();assert(ideas)
            body.PreviousAlbum.action();assert(selected==math.max(1,page-1))
            body.NextAlbum.action();assert(selected==math.min(math.ceil(#albumData/6),page+1))
            if page==math.ceil(#albumData/6)then assert(result.focusFrame:GetAttribute("Focused"))end
        end
    end
end)
fs.writeFile("prototype/evidence/album-ui-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Actual album builder/UI and measured logical rectangles; no live font rasterization or Roblox rendering"},true))
print("Passed "..#tests.." album UI integration checks")
