local Harness=require("./support/ui_harness")
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
test("General and stage guides keep measured text and fixed closing actions across six screens",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}}do
        for _,mode in {{},{stage=1},{stage=2},{stage=3},{stage=3,remixId="long"},{stage=3,remixId="reverse"}}do
            local h=Harness.new(screen[1],screen[2]);local u=h.environment.UDim2
            h.ui.overlay=function(parent,name)return h.ui.frame(parent,name,u.fromScale(0,0),u.fromScale(1,1))end
            local feedback={motionEnabled=true,soundEnabled=true,pop=function()end}
            local guide=h.module("src/client/Guide.luau",{Icons=h.module("src/client/ToyIcons.luau"),Remix=Remix,Feedback=feedback})
            local metadata=table.clone(mode)
            metadata.availableHeight=h.logical.height;metadata.availableWidth=screen[1]/h.logical.scale;metadata.placeVersion=29
            local events={};local overlay
            metadata.setPreference=function(key,value)feedback[key]=value;table.insert(events,key);guide.updatePreferences(overlay)end
            metadata.ideas=function()table.insert(events,"ideas")end
            metadata.scrollPosition=h.environment.Vector2.new(0,80)
            metadata.scrolled=function(value)metadata.scrollPosition=value end
            overlay=guide.open(h.root,h.logical.mobile,function()table.insert(events,"close")end,metadata)
            local box=overlay.GuideDialog;local w,hh=box.Size.X.Offset,box.Size.Y.Offset
            local title=rect(box.Title,w,hh);local content=rect(box.GuideContent,w,hh);local close=rect(box.CloseGuide,w,hh)
            assert(title.y+title.h+10<=content.y and content.y+content.h+10<=close.y)
            assert(content.h*h.logical.scale>=60 and close.h*h.logical.scale>=44)
            assert(close.y+close.h<rect(box.PlaceVersion,w,hh).y)
            local function fits(node,pw,ph)
                local r=rect(node,pw,ph)
                assert(r.x>=0 and r.y>=0 and r.x+r.w<=pw+1 and r.y+r.h<=ph+1,node.Name.." outside container")
                assert(h.ui.textHeight(node.Text,node.TextSize,r.w,node.Font=="bold")<=r.h,node.Name.." clips text")
                assert(node.TextSize*h.logical.scale>=9.9,node.Name.." too small")
                return r
            end
            fits(box.Title,w,hh);fits(box.CloseGuide,w,hh);fits(box.PlaceVersion,w,hh)
            local area=box.GuideContent;local ch=area.CanvasSize.Y.Offset
            assert(area.CanvasPosition.Y==80)
            area.CanvasPosition=h.environment.Vector2.new(0,120);area.signals.CanvasPosition();assert(metadata.scrollPosition.Y==120)
            local bottom=126
            for i=1,3 do
                local row=area.children["Step_"..i];local r=rect(row,content.w,ch)
                assert(r.y>=bottom);bottom=r.y+r.h
                fits(row.Detail,r.w,r.h)
                local seal=rect(row.NumberSeal,r.w,r.h);fits(row.NumberSeal.Number,seal.w,seal.h)
            end
            if not mode.stage then
                local r=fits(area.CollectionTitle,content.w,ch);assert(r.y>=bottom);bottom=r.y+r.h
                for i=1,3 do
                    local row=area.children["CollectionNote_"..i];r=rect(row,content.w,ch)
                    assert(r.y>=bottom);bottom=r.y+r.h;fits(row.Detail,r.w,r.h)
                end
                r=fits(area.OpenIdeas,content.w,ch);assert(r.y>=bottom);bottom=r.y+r.h
                assert(#events==0);area.OpenIdeas.action();assert(events[1]=="ideas")
            else assert(area.CollectionTitle==nil and area.OpenIdeas==nil)end
            local motion=fits(area.MotionToggle,content.w,ch);local sound=fits(area.SoundToggle,content.w,ch)
            assert(motion.y>=bottom and motion.x+motion.w+8<=sound.x)
            local hint=fits(area.PreferenceHint,content.w,ch);assert(hint.y>=motion.y+motion.h+10)
            area.MotionToggle.action();area.SoundToggle.action()
            assert(not feedback.motionEnabled and not feedback.soundEnabled)
            fits(area.MotionToggle,content.w,ch);fits(area.SoundToggle,content.w,ch)
            box.CloseGuide.action();assert(events[#events]=="close")
            if mode.remixId then
                local remix=Remix.get(mode.remixId)
                assert(area.Step_3.Detail.Text:find(tostring(remix.required),1,true) and area.Step_3.Detail.Text:find(tostring(remix.total),1,true))
            end
        end
    end
end)
test("Guide retains reading on rebuild and opens ideas only after an available explicit action",function()
    local source=fs.readFile("src/client/App.client.luau")
    local first=assert(source:find("showGuide = function(",1,true));local last=assert(source:find("\nlocal function renderAlbum()",first,true))
    local capture={events={}}
    local api=luau.load([[
        local modal,modalRebuild,showGuide
        local activeGame,busy,swiping,gameInputLocked
    ]]..source:sub(first,last-1)..[[
        return {open=showGuide,rebuild=function()modalRebuild()end,
            lock=function(value)busy=value end,game=function(value)activeGame=value end}
    ]],{environment={UI={availableWidth=652},state={placeVersion=29},mobile=true,height=760,actions={},
        closeModal=function()table.insert(capture.events,"close")end,
        showIdeas=function()table.insert(capture.events,"ideas")end,render=function()end,setPreference=function()end,
        Guide={open=function(_,_,_,metadata)capture.metadata=metadata;return {}end},
    }})()
    api.open();assert(capture.metadata.ideas and not capture.metadata.stage)
    capture.metadata.scrolled({Y=80});api.rebuild();assert(capture.metadata.scrollPosition.Y==80)
    local action=capture.metadata.ideas;local before=#capture.events
    api.lock(true);action();assert(#capture.events==before)
    api.lock(false);action();assert(capture.events[#capture.events]=="ideas")
    api.game({stage=3,remixId="reverse"});before=#capture.events;action();assert(#capture.events==before)
    api.open();assert(capture.metadata.stage==3 and capture.metadata.remixId=="reverse" and capture.metadata.ideas==nil)
end)
fs.writeFile("prototype/evidence/guide-readability-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production guide and client handlers, controlled overlay/fonts; no Roblox rendering"},true))
print("Passed "..#tests.." guide readability and discovery checks")
