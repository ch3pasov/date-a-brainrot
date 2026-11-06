-- Real empty album/inbox content with controlled instances and fonts.
local Harness=require("./support/ui_harness")
local Catalog=require("../src/shared/Catalog")
local Config=require("../src/shared/Config")
local Logic=require("../src/shared/GameLogic")
local Collection=require("../src/shared/Collection")
local Locations=require("../src/shared/Locations")
local Feed=require("../src/shared/FeedLayout")
local Layout=require("../src/shared/ListLayout")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local rect=Harness.rect
local function fixture(screen,kind,character)
    local h=Harness.new(screen[1],screen[2]);local l=h.logical;local u=h.environment.UDim2
    h.ui.availableWidth=screen[1]/l.scale
    local shell=Feed.resolve(l.width,l.height,l.mobile,l.touchMinimum)
    local bh=l.mobile and shell.dockY-shell.bodyY-18 or l.height-214
    local body=h.ui.new(l.mobile and "ScrollingFrame" or "Frame",{Name="Body",Position=u.fromOffset(22,shell.bodyY),
        Size=l.mobile and u.new(1,-44,0,bh) or u.fromOffset(l.width-52,bh),CanvasSize=u.fromOffset(0,0),ScrollingEnabled=false},h.root)
    local empty=h.module("src/client/EmptyPostcard.luau",{Layout=Layout,Icons=h.module("src/client/ToyIcons.luau")})
    local state={matches={},sentLikes={},feed={},swipes={},album={},pending=0,now=1000}
    local events={};local function record(...)table.insert(events,{...})end
    if kind=="waiting"then
        state.pending=1;state.sentLikes={{characterId=character.id,variantId="cosmic",status="pending"}}
    elseif kind=="exhausted"then state.sentLikes={{characterId=Catalog[1].id,variantId="classic",status="declined"}}
    elseif kind=="new" or kind=="sent"then state.feed={{characterId=Catalog[1].id,variantId="classic"}}end
    local before=serde.encode("json",state)
    if kind=="album"then
        h.module("src/client/Album.luau",{Config=Config,Logic=Logic,Collection=Collection,Locations=Locations,ListLayout=Layout,Empty=empty}).render(body,state,l.mobile,1,
            {matches=function()record("matches")end,ideas=function()record("ideas")end})
    else
        h.module("src/client/MatchInbox.luau",{Logic=Logic,Layout=Layout,Empty=empty}).render(body,state,l.mobile,kind=="sent" and "sent" or "matches",1,
            {feed=function()record("feed")end,filter=function(value)record("filter",value)end,
                mount=function(_,id,variant,options)record("mount",id,variant,options)end})
    end
    assert(serde.encode("json",state)==before,"Rendering changes saved progress")
    return h,body,events
end
local function verify(h,body)
    local bw=body.Size.X.Scale*h.logical.width+body.Size.X.Offset;local bh=body.Size.Y.Offset
    local card=body.EmptyPostcard;local c=rect(card,bw,bh)
    assert(c.x>=0 and c.x+c.w<=bw and c.y>=0)
    local function fits(node,pw,ph)
        local r=rect(node,pw,ph)
        assert(r.x>=0 and r.y>=0 and r.x+r.w<=pw+1 and r.y+r.h<=ph+1,node.Name.." outside postcard")
        assert(h.ui.textHeight(node.Text,node.TextSize,r.w,node.Font=="bold")<=r.h,node.Name.." clips text")
        assert(node.TextSize*h.logical.scale>=9.9,node.Name.." too small")
        return r
    end
    local pic=rect(card.Picture,c.w,c.h);local tag=rect(card.Status,c.w,c.h)
    fits(card.Status.Label,tag.w,tag.h)
    local title=fits(card.Title,c.w,c.h);local note=fits(card.Description,c.w,c.h)
    assert(not card.Title.TextScaled and pic.w>0 and pic.h>0)
    assert(pic.x+pic.w<title.x and tag.y+tag.h+10<=title.y)
    assert(pic.y+pic.h+10<=note.y and title.y+title.h+10<=note.y)
    if card.EmptyAction then
        local action=fits(card.EmptyAction,c.w,c.h)
        assert(note.y+note.h+12<=action.y and action.h*h.logical.scale>=44)
    end
    if c.y+c.h>bh then
        assert(h.logical.mobile and body.ScrollingEnabled and body.ScrollBarThickness>0)
        assert(body.CanvasSize.Y.Offset>=c.y+c.h,"Cannot scroll to the end")
    else assert(not body.ScrollingEnabled)end
end
local screens={{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}}
test("Actual album and inbox invitations keep readable text, reachable actions and correct destinations",function()
    for _,screen in screens do
        for _,kind in {"album","new","sent","exhausted","none"}do
            local h,body,events=fixture(screen,kind);verify(h,body)
            assert(#events==0)
            local button=body.EmptyPostcard.EmptyAction
            if kind=="none"then assert(not button)
            else
                button.action()
                if kind=="album"then assert(events[1][1]=="matches")
                elseif kind=="exhausted"then assert(events[1][1]=="filter" and events[1][2]=="sent")
                else assert(events[1][1]=="feed")end
            end
        end
    end
end)
test("Every pending character fits the real waiting postcard and keeps its portrait and sent likes",function()
    for _,screen in screens do
        for _,character in Catalog do
            local h,body,events=fixture(screen,"waiting",character);verify(h,body)
            assert(#events==1 and events[1][1]=="mount" and events[1][2]==character.id and events[1][3]=="cosmic" and events[1][4].portrait)
            assert(body.EmptyPostcard.Title.Text==character.name)
            body.EmptyPostcard.EmptyAction.action();assert(events[2][1]=="filter" and events[2][2]=="sent")
        end
    end
end)
fs.writeFile("prototype/evidence/empty-postcard-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Actual empty album/inbox builders, real UI with controlled geometry/fonts; no Roblox rendering"},true))
print("Passed "..#tests.." actual empty postcard geometry checks")
