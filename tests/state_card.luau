local Harness=require("./support/ui_harness")
local FeedLayout=require("../src/shared/FeedLayout")
local Logic=require("../src/shared/GameLogic")
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local roblox=require("@lune/roblox")
local source=fs.readFile("src/client/App.client.luau")
local function section(a,b)local first=assert(source:find(a,1,true));local last=assert(source:find(b,first,true));return source:sub(first,last-1)end
local empty=section("local function empty(","local function setCardVariant(")
local feed=section("local function renderFeed()","local listPage, inboxFilter")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture(w,h)
    local f=Harness.new(w,h);local l=f.logical;f.ui.availableWidth=w/l.scale
    local layout=FeedLayout.resolve(l.width,l.height,l.mobile,l.touchMinimum)
    f.body=f.ui.new(l.mobile and "ScrollingFrame" or "Frame",{Name="Body",Position=roblox.UDim2.fromOffset(22,layout.bodyY),
        Size=roblox.UDim2.fromOffset(l.mobile and 436 or l.width-52,layout.bodyHeight),CanvasSize=roblox.UDim2.fromOffset(0,0)},f.root)
    local card=f.module("src/client/StateCard.luau",{Icons=f.module("src/client/ToyIcons.luau")},"local C=UI.colors")
    f.state={feed={},matches={},album={},pending=0};f.events={}
    f.api=luau.load([[
        local emptyReading={}
        local currentCard,lastLoadError,renderLoadScreen
        local profileReady=false
    ]]..empty..feed..[[
        return {load=function(err)profileReady=false;lastLoadError=err;renderLoadScreen()end,
            feed=function()profileReady=true;UI.clear(body);renderFeed()end}
    ]],{environment={UI=f.ui,StateCard=card,FeedLayout=FeedLayout,body=f.body,mobile=l.mobile,width=l.width,height=l.height,UDim2=roblox.UDim2,
        state=f.state,Logic=Logic,gui={SetAttribute=function()end},
        errors={load_failed="Не удалось загрузить историю. Попробуй ещё раз."},
        beginLoad=function(retry)assert(retry);table.insert(f.events,"retry")end,
        actions={undoPass=function()table.insert(f.events,"undo")end},nav=function(tab)table.insert(f.events,tab)end,
    }})()
    return f
end
local function verify(f,hasAction)
    local card=f.body.StateCard;local w,h=card.Size.X.Offset,card.Size.Y.Offset
    local content=Harness.rect(card.Content,w,h)
    assert(content.h*f.logical.scale>=40 and content.x+content.w<=w and content.y+content.h<=h-16)
    for _,node in {card.Content.Title,card.Content.Description}do
        local r=Harness.rect(node,content.w,content.h)
        assert(r.x+r.w<=content.w and r.y+r.h<=card.Content.CanvasSize.Y.Offset)
        assert(f.ui.textHeight(node.Text,node.TextSize,r.w,node.Font=="bold")<=r.h and node.TextSize*f.logical.scale>=12)
    end
    if hasAction then
        local button=card.StateAction;local r=Harness.rect(button,w,h)
        assert(content.y+content.h+10<=r.y and r.y+r.h<=h-16)
        assert(r.h*f.logical.scale>=44 and f.ui.textHeight(button.Text,button.TextSize,r.w-8,true)<=r.h)
    else assert(card.StateAction==nil)end
    if f.logical.mobile then assert(not f.body.ScrollingEnabled and f.body.CanvasSize.Y.Offset==0)end
end
test("Loading, retry and exhausted feed cards keep readable text and fixed actions on six screens",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}}do
        local f=fixture(screen[1],screen[2]);f.api.load();verify(f,false)
        f.api.load("load_failed");verify(f,true);assert(#f.events==0)
        f.body.StateCard.StateAction.action();assert(f.events[1]=="retry")
        f.state.lastPass={};f.api.feed();verify(f,true)
        f.body.StateCard.StateAction.action();assert(f.events[2]=="undo")
        f.state.lastPass=nil;f.state.matches={{stage=4}};f.state.album={{key="saved"}};f.api.feed();verify(f,true)
        f.body.StateCard.StateAction.action();assert(f.events[3]=="album")
        f.state.matches={{stage=2}};f.api.feed();f.body.StateCard.StateAction.action();assert(f.events[4]=="matches")
        f.state.matches={};f.state.pending=2;f.api.feed();verify(f,true);f.body.StateCard.StateAction.action();assert(f.events[5]=="matches")
    end
end)
test("Reading position survives a rebuild of the same message and resets for another message",function()
    local f=fixture(240,320);f.api.load("load_failed")
    local content=f.body.StateCard.Content;content.CanvasPosition=roblox.Vector2.new(0,80);content.signals.CanvasPosition()
    f.api.load("load_failed");assert(f.body.StateCard.Content.CanvasPosition.Y==80)
    f.api.load("unknown");assert(f.body.StateCard.Content.CanvasPosition.Y==0)
    f.api.load("load_failed");assert(f.body.StateCard.Content.CanvasPosition.Y==80)
end)
fs.writeFile("prototype/evidence/state-card-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production loading and exhausted-feed handlers and status UI with controlled geometry; no live network or render"},true))
print("Passed "..#tests.." loading and exhausted feed checks")
