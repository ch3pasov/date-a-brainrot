local Harness=require("./support/ui_harness")
local Logic=require("../src/shared/GameLogic")
local Catalog=require("../src/shared/Catalog")
local Config=require("../src/shared/Config")
local Games=require("../src/shared/Minigames")
local Layout=require("../src/shared/ListLayout")
local Feed=require("../src/shared/FeedLayout")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local rect=Harness.rect
local function fixture(screen,state,filter,page)
    local h=Harness.new(screen[1],screen[2]);local l=h.logical
    h.ui.availableWidth=screen[1]/l.scale
    local shell=Feed.resolve(l.width,l.height,l.mobile,l.touchMinimum)
    local bh=l.mobile and shell.dockY-shell.bodyY-18 or l.height-214
    local body=h.ui.frame(h.root,"Body",h.environment.UDim2.fromOffset(22,shell.bodyY),h.environment.UDim2.fromOffset(l.mobile and 436 or l.width-52,bh))
    local events={};local function record(kind,...)table.insert(events,{kind,...})end
    local inbox=h.module("src/client/MatchInbox.luau",{Logic=Logic,Games=Games,Layout=Layout,Empty={}})
    inbox.render(body,state,l.mobile,filter,page,{mount=function()end,open=function(...)record("open",...)end,
        filter=function(...)record("filter",...)end,page=function(...)record("page",...)end})
    return h,body,events
end
local function textFits(h,node,w,hh)
    local r=rect(node,w,hh)
    assert(r.w>0 and r.h>=h.ui.textHeight(node.Text,node.TextSize,r.w,node.Font=="bold"),node.Name.." clips text")
    assert(node.TextSize*h.logical.scale>=8.9,node.Name.." too small")
    assert(r.x>=0 and r.y>=0 and r.x+r.w<=w+1 and r.y+r.h<=hh+1,node.Name.." outside container")
    return r
end
local screens={{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}}
test("Every character, variant and stage fits real inbox rows and opens the correct story",function()
    for _,screen in screens do
        for _,character in Catalog do
            local state={matches={},sentLikes={},pending=136,now=2000000000}
            for stage,variant in Config.Variants do
                table.insert(state.matches,{key=Logic.key(character.id,variant.id),characterId=character.id,variantId=variant.id,stage=stage,unread=stage%2==0})
            end
            local h,body,events=fixture(screen,state,"matches",1)
            local bw,bh=body.Size.X.Offset,body.Size.Y.Offset
            local grid=rect(body.MatchList,bw,bh)
            local filter=rect(body.Filter_matches,bw,bh)
            assert(filter.y+filter.h+10<=grid.y and grid.h*h.logical.scale>=40 and grid.y+grid.h<=bh)
            if body.Title then textFits(h,body.Title,bw,bh);textFits(h,body.Description,bw,bh)end
            for _,name in {"Filter_matches","Filter_sent"}do
                local r=textFits(h,body.children[name],bw,bh);assert(r.h*h.logical.scale>=44)
            end
            local cell=body.MatchList.UIGridLayout.CellSize
            local w,hh=grid.w*cell.X.Scale+cell.X.Offset,cell.Y.Offset
            for i,match in state.matches do
                local row=body.MatchList.children["Match_"..i]
                local name=textFits(h,row.children.Name,w,hh)
                local stage=textFits(h,row.Stage,w,hh)
                local action=textFits(h,row.Continue,w,hh)
                assert(name.y+name.h+6<=stage.y and stage.y+stage.h+10<=action.y)
                assert(action.h*h.logical.scale>=44)
                local art=rect(row.Avatar,w,hh)
                local figure=rect(row.Avatar.Figure,art.w,art.h)
                assert(figure.w*h.logical.scale>=60 and figure.h*h.logical.scale>=79,string.format("%dx%d %s figure %.2fx%.2f",screen[1],screen[2],character.id,figure.w*h.logical.scale,figure.h*h.logical.scale))
                for _,tagName in {"Variant","Unread"}do
                    local tag=row.Avatar.children[tagName]
                    if tag then
                        local r=rect(tag,art.w,art.h);textFits(h,tag.Label,r.w,r.h)
                        assert(r.y+r.h<=figure.y or r.y>=figure.y+figure.h,"Tag overlaps portrait")
                    end
                end
                row.Continue.action();local event=events[#events]
                assert(event[1]=="open" and event[2]==match.key and event[3]==match.stage)
            end
            body.Filter_sent.action();assert(events[#events][1]=="filter" and events[#events][2]=="sent")
        end
    end
end)
test("Sent statuses, long timestamps and page actions stay separated on compact windows",function()
    for _,screen in screens do
        local state={matches={},sentLikes={},pending=136,now=2000000000}
        local statuses={"pending","matched","declined","unanswered"}
        for i=1,136 do
            local character=Catalog[(i-1)%#Catalog+1];local variant=Config.Variants[(i-1)%4+1]
            local item={key=Logic.key(character.id,variant.id),characterId=character.id,variantId=variant.id,status=statuses[(i-1)%4+1],likedAt=0}
            table.insert(state.sentLikes,item)
            if item.status=="matched"then table.insert(state.matches,{key=item.key,stage=4})end
        end
        for _,page in {1,17}do
            local h,body,events=fixture(screen,state,"sent",page)
            local bw,bh=body.Size.X.Offset,body.Size.Y.Offset
            local grid=rect(body.MatchList,bw,bh);local pager=rect(body.PreviousPage,bw,bh)
            assert(grid.h*h.logical.scale>=40,"Too little room to browse the list")
            assert(grid.y+grid.h+8<=pager.y and pager.y+pager.h<=bh)
            assert(pager.h*h.logical.scale>=44)
            local cell=body.MatchList.UIGridLayout.CellSize;local w,hh=grid.w*cell.X.Scale+cell.X.Offset,cell.Y.Offset
            for i=(page-1)*8+1,page*8 do
                local row=body.MatchList.children["Match_"..i]
                local name=textFits(h,row.children.Name,w,hh);local status=textFits(h,row.Status,w,hh);local at=textFits(h,row.SentAt,w,hh)
                assert(name.y+name.h<status.y and status.y+status.h<at.y)
                if row.Continue then local action=textFits(h,row.Continue,w,hh);assert(at.y+at.h+10<=action.y)end
            end
            body.PreviousPage.action();assert(events[#events][2]==math.max(1,page-1))
            body.NextPage.action();assert(events[#events][2]==math.min(17,page+1))
            assert(body.PageNumber.Text==page.." / 17")
        end
    end
end)
fs.writeFile("prototype/evidence/inbox-readability-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production inbox and UI with controlled geometry/fonts; no live Roblox rendering"},true))
print("Passed "..#tests.." inbox readability integration checks")
