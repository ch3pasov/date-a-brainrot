local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local serde=require("@lune/serde")
local Logic=require("../src/shared/GameLogic")
local source=fs.readFile("src/client/App.client.luau")
local first=assert(source:find("render = function(preserveModal)",1,true));local last=assert(source:find("actions.returnLater = function(",first,true))
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture()
    local f={range=1000,queued={},surfaces={}}
    local function makeBody()
        local b={Parent={},CanvasPosition=roblox.Vector2.zero,AbsoluteCanvasSize=roblox.Vector2.new(400,f.range+200),AbsoluteWindowSize=roblox.Vector2.new(400,200)}
        function b:FindFirstChild()return nil end
        table.insert(f.surfaces,b);return b
    end
    f.api=luau.load([[
        local body,render,renderedListKey,renderedFeedKey,pendingFeedRestore,modalRebuild
        local scrollPositions={}
        local currentCard={characterId="first",variantId="classic"}
        local activeTab,activeGame,mobile="feed",nil,true
        local inboxFilter,listPage="matches",1
        local profileReady=true
        local function buildShell()
            if body then body.Parent=nil end
            body=makeBody()
        end
    ]]..source:sub(first,last-1)..[[
        return {render=render,body=function()return body end,
            card=function(id,variant)currentCard={characterId=id,variantId=variant or "classic"}end,
            game=function(value)activeGame=value end,mobile=function(value)mobile=value end,
            ready=function(value)profileReady=value end}
    ]],{environment={
        makeBody=makeBody,Logic=Logic,Vector2=roblox.Vector2,state={matches={},album={},pending=0},
        cleanup=function()end,closeModal=function()end,renderFeed=function()end,renderGame=function()end,renderLoadScreen=function()end,
        gui={SetAttribute=function()end},task={wait=function()end,defer=function(fn)table.insert(f.queued,fn)end},
    }})()
    function f.flush()local queued=f.queued;f.queued={};for _,fn in queued do fn()end end
    f.api.render();return f
end
test("Feed reading progress follows a resized card and survives another rebuild before layout",function()
    local f=fixture();f.api.body().CanvasPosition=roblox.Vector2.new(0,350)
    f.range=2000;f.api.render(true);assert(f.api.body().CanvasPosition.Y==0)
    f.flush();assert(f.api.body().CanvasPosition.Y==700)
    f.api.body().CanvasPosition=roblox.Vector2.new(0,800)
    f.range=3000;f.api.render(true);local discarded=f.api.body()
    f.range=4000;f.api.render(true);f.flush()
    assert(discarded.Parent==nil and discarded.CanvasPosition.Y==0)
    assert(f.api.body().CanvasPosition.Y==1600)
end)
test("Different cards and variants start at the top and retain separate reading positions",function()
    local f=fixture();f.api.body().CanvasPosition=roblox.Vector2.new(0,700)
    f.api.card("second");f.api.render();f.flush();assert(f.api.body().CanvasPosition.Y==0)
    f.api.body().CanvasPosition=roblox.Vector2.new(0,300)
    f.api.card("first","gold");f.api.render();f.flush();assert(f.api.body().CanvasPosition.Y==0)
    f.api.card("first");f.api.render();f.flush();assert(f.api.body().CanvasPosition.Y==700)
    f.api.card("second");f.api.render();f.flush();assert(f.api.body().CanvasPosition.Y==300)
end)
test("Overscroll clamps to the new range and stale callbacks cannot scroll a game or desktop screen",function()
    for _,position in {-50,1500}do
        local f=fixture();f.api.body().CanvasPosition=roblox.Vector2.new(0,position)
        f.range=500;f.api.render(true);f.flush()
        assert(f.api.body().CanvasPosition.Y==(position<0 and 0 or 500))
        f.range=0;f.api.render(true);f.flush();assert(f.api.body().CanvasPosition.Y==0)
    end
    for _,kind in {"game","desktop","loading"}do
        local f=fixture();f.api.body().CanvasPosition=roblox.Vector2.new(0,300)
        f.api.render(true)
        if kind=="game"then f.api.game({stage=2})elseif kind=="desktop"then f.api.mobile(false)else f.api.ready(false)end
        f.api.render();f.flush();assert(f.api.body().CanvasPosition.Y==0)
        if kind=="loading"then
            f.api.body().AbsoluteCanvasSize=nil;f.api.body().AbsoluteWindowSize=nil
            f.api.ready(true);f.api.render();f.flush();assert(f.api.body().CanvasPosition.Y==300)
        end
    end
end)
fs.writeFile("prototype/evidence/feed-scroll-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production render orchestration with controlled scrolling geometry and deferred callbacks; no live layout timing"},true))
print("Passed "..#tests.." feed reading position checks")
