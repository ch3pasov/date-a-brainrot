local Harness=require("./support/ui_harness")
local Config=require("../src/shared/Config")
local Logic=require("../src/shared/GameLogic")
local Catalog=require("../src/shared/Catalog")
local Collection=require("../src/shared/Collection")
local Locations=require("../src/shared/Locations")
local Remix=require("../src/shared/DateRemix")
local ListLayout=require("../src/shared/ListLayout")
local FeedLayout=require("../src/shared/FeedLayout")
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local roblox=require("@lune/roblox")
local source=fs.readFile("src/client/App.client.luau")
local function section(first,last)
    local a=assert(source:find(first,1,true));local b=assert(source:find(last,a,true));return source:sub(a,b-1)
end
local nav=section("local function nav(","local function buildShell()")
local renderAlbum=section("local function renderAlbum()","showIdeas = function(")
local render=section("render = function(preserveModal)","actions.returnLater = function(")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture(w,h)
    local f=Harness.new(w,h);f.queued={};f.cancels=0
    local l=f.logical;local shell=FeedLayout.resolve(l.width,l.height,l.mobile,l.touchMinimum)
    local bodyW=l.mobile and 436 or l.width-52
    local bodyH=l.mobile and shell.dockY-shell.bodyY-18 or l.height-214
    local icons=f.module("src/client/ToyIcons.luau")
    local sticker=f.module("src/client/SouvenirSticker.luau",{Icons=icons,Remix=Remix})
    local frame=f.module("src/client/PhotoFrame.luau",{Icons=icons})
    local album=f.module("src/client/Album.luau",{Config=Config,Logic=Logic,Collection=Collection,Locations=Locations,ListLayout=ListLayout,Sticker=sticker,PhotoFrame=frame})
    f.state={album={},matches={},pending=0}
    for _,character in Catalog do for _,variant in Config.Variants do
        table.insert(f.state.album,{key=character.id..":"..variant.id,characterId=character.id,variantId=variant.id,locationId="park",scores={}})
    end end
    f.api=luau.load([[
        local albumPage,albumFocusKey,albumFocusTarget=22,nil,nil
        local activeTab,activeGame="album",nil
        local profileReady,busy,swiping,gameInputLocked=true,false,false,false
        local body,renderedListKey,modalRebuild
        local scrollPositions={["album:22"]=Vector2.new(0,77)}
        local render
        local function closeModal()end
        local function buildShell()
            if body then
                for _,child in body.children do child.Parent=nil end
                body:Destroy()
            end
            body=makeBody()
        end
    ]]..nav..renderAlbum..render..[[
        return {nav=nav,render=render,page=function()return albumPage end,body=function()return body end,
            focus=function()return albumFocusKey end,
            busy=function(value)busy=value end,ready=function(value)profileReady=value end,
            playing=function()activeGame={key="playing"}end}
    ]],{environment={
        state=f.state,mobile=l.mobile,Album=album,Vector2=roblox.Vector2,
        makeBody=function()return f.ui.frame(f.root,"Body",roblox.UDim2.fromOffset(0,0),roblox.UDim2.fromOffset(bodyW,bodyH))end,
        mount=function()end,showStory=function()end,showIdeas=function()end,cleanup=function()end,countUnread=function()return 0 end,
        rpc=function(action)assert(action=="cancelGame");f.cancels+=1 end,
        gui={SetAttribute=function()end},
        task={defer=function(callback)table.insert(f.queued,callback)end,wait=function()end},
    }})()
    function f.flush()
        local grid=f.api.body().AlbumGrid
        local layout=grid.UIGridLayout
        local columns=f.logical.mobile and 1 or 3
        local count=0;for _,child in grid.children do if child:GetAttribute("Focused")~=nil or child.Name:match("^Selfie_") then count+=1 end end
        local rows=math.ceil(count/columns)
        grid.CanvasPosition=grid.CanvasPosition or roblox.Vector2.zero
        grid.AbsolutePosition=roblox.Vector2.new(11,125)
        grid.AbsoluteWindowSize=roblox.Vector2.new(bodyW,Harness.rect(grid,bodyW,bodyH).h)*f.logical.scale
        grid.AbsoluteCanvasSize=roblox.Vector2.new(bodyW,rows*layout.CellSize.Y.Offset+math.max(0,rows-1)*layout.CellPadding.Y.Offset)*f.logical.scale
        for _,child in grid.children do
            local index=tonumber(child.Name:match("^Selfie_(%d+)$"))
            if index then
                local row=math.floor(((index-1)%6)/columns)
                child.AbsolutePosition=roblox.Vector2.new(11,125+row*(layout.CellSize.Y.Offset+layout.CellPadding.Y.Offset)*f.logical.scale-grid.CanvasPosition.Y)
            end
        end
        local callbacks=f.queued;f.queued={};for _,callback in callbacks do callback()end
    end
    f.api.render();f.flush()
    return f
end
test("Navigation locates every target page and restores the actual grid row after rendering",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}}do
        local f=fixture(screen[1],screen[2]);assert(f.api.page()==22)
        for _,index in {1,6,7,12,136}do
            local key=f.state.album[index].key
            f.api.nav("album",key);f.flush()
            local body=f.api.body();local grid=body.AlbumGrid;local photo=grid["Selfie_"..index]
            assert(f.api.page()==math.ceil(index/6) and photo:GetAttribute("Focused") and f.api.focus()==nil)
            local layout=grid.UIGridLayout
            local row=math.floor(((index-1)%6)/(f.logical.mobile and 1 or 3))
            local maximum=math.max(0,grid.AbsoluteCanvasSize.Y-grid.AbsoluteWindowSize.Y)
            local expected=math.min(row*(layout.CellSize.Y.Offset+layout.CellPadding.Y.Offset)*f.logical.scale,maximum)
            assert(math.abs(grid.CanvasPosition.Y-expected)<.001)
            assert(photo.UIStroke.Color==f.ui.colors.pink)
        end
    end
end)
test("Focus is consumed once so later resizing preserves the player's reading position",function()
    local f=fixture(390,650);f.api.nav("album",f.state.album[12].key);f.flush()
    local grid=f.api.body().AlbumGrid;grid.CanvasPosition=roblox.Vector2.new(0,333)
    f.api.render(true);f.flush()
    assert(f.api.page()==2 and f.api.body().AlbumGrid.CanvasPosition.Y==333)
    assert(not f.api.body().AlbumGrid.Selfie_12:GetAttribute("Focused"))
    f.api.nav("album");f.flush();assert(f.api.body().AlbumGrid.CanvasPosition.Y==333)
end)
test("A rebuild before layout keeps focus pending and a short album clamps to the visible canvas",function()
    local f=fixture(390,650);f.api.nav("album",f.state.album[12].key)
    local oldGrid=f.api.body().AlbumGrid
    f.api.render(true);f.flush()
    assert(oldGrid.Parent==nil and f.api.focus()==nil)
    assert(f.api.body().AlbumGrid.CanvasPosition.Y>0 and f.api.body().AlbumGrid.Selfie_12:GetAttribute("Focused"))
    local desktop=fixture(1280,720)
    local photo=desktop.state.album[1];desktop.state.album={photo}
    desktop.api.nav("album",photo.key);desktop.flush()
    assert(desktop.api.body().AlbumGrid.CanvasPosition.Y==0 and desktop.api.focus()==nil)
end)
test("A newly reordered selfie is found by key while blocked or missing targets leave browsing intact",function()
    local f=fixture(390,650);local photo=table.remove(f.state.album,100);table.insert(f.state.album,1,photo)
    f.api.busy(true);f.api.nav("album",photo.key);assert(f.api.page()==22)
    f.api.busy(false);f.api.ready(false);f.api.nav("album",photo.key);assert(f.api.page()==22)
    f.api.ready(true);f.api.playing();f.api.nav("album",photo.key);f.flush()
    assert(f.api.page()==1 and f.cancels==1 and f.api.body().AlbumGrid.Selfie_1:GetAttribute("Focused"))
    f.api.body().AlbumGrid.CanvasPosition=roblox.Vector2.new(0,88)
    f.api.nav("album","missing");f.flush()
    assert(f.api.page()==1 and f.api.body().AlbumGrid.CanvasPosition.Y==88 and f.api.focus()==nil)
end)
fs.writeFile("prototype/evidence/album-focus-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production navigation, render orchestration and album builder with controlled GUI/deferred callbacks; no live layout timing test"},true))
print("Passed "..#tests.." album focus navigation checks")
