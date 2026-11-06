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
        local f=Harness.new(screen[1],screen[2]);local l=f.logical
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
        local title,description,counts,grid=rect(body.Title,bodyW,bodyH),rect(body.Description,bodyW,bodyH),rect(body.Count_classic,bodyW,bodyH),rect(body.AlbumGrid,bodyW,bodyH)
        assert(title.y+title.h<=description.y and description.y+description.h<=counts.y and counts.y+counts.h<grid.y)
        assert(grid.h>100 and grid.y+grid.h<=bodyH)
        local button=rect(body.JourneyIdeas,bodyW,bodyH)
        assert(description.x+description.w+8<=button.x and button.y+button.h<=counts.y)
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
fs.writeFile("prototype/evidence/album-ui-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Actual album builder/UI and measured logical rectangles; no live font rasterization or Roblox rendering"},true))
print("Passed "..#tests.." album UI integration checks")
