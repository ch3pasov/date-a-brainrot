local Harness=require("./support/ui_harness")
local Remix=require("../src/shared/DateRemix")
local Locations=require("../src/shared/Locations")
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local rect=Harness.rect
test("Briefing keeps rules scrollable and start/back controls separated on six screen sizes",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}} do
        for _,mode in {"normal","long","reverse"} do
          for _,place in Locations.list do
            local f=Harness.new(screen[1],screen[2]);local taps=0
            local briefing=f.module("src/client/DateBriefing.luau",{Remix=Remix,Locations=Locations})
            local ready=briefing.mount(f.root,{remixId=mode,locationId=place.id},{width=f.logical.width,height=f.logical.height,mobile=f.logical.mobile,ready=function()taps+=1 end})
            local box=f.root.DateBriefing.ReadyCard
            local card=rect(box,f.logical.width,f.logical.height)
            assert(card.x>=0 and card.x+card.w<=f.logical.width and card.y+card.h<=f.logical.height)
            assert(card.y>=math.max(114,(f.ui.touchMinimum or 66)+48))
            local title,rules,button=rect(box.Title,card.w,card.h),rect(box.Rules,card.w,card.h),rect(ready,card.w,card.h)
            assert(title.y+title.h+8<=rules.y and rules.h>=100 and rules.y+rules.h+8<=button.y)
            assert(button.y+button.h<=card.h and button.h*f.logical.scale>=44)
            assert(f.ui.textHeight(box.Title.Text,box.Title.TextSize,title.w,true)<=title.h)
            assert(f.ui.textHeight("Подключаемся…",ready.TextSize,button.w-16,true)+20<=button.h)
            assert((box.Rules.Hint.Text:find("Enter",1,true)~=nil)==not f.logical.mobile)
            local previousBottom=0
            for _,node in {box.Rules.Place,box.Rules.Rule,box.Rules.Target,box.Rules.Hint}do
                local r=rect(node,rules.w,box.Rules.CanvasSize.Y.Offset)
                assert(r.y>=previousBottom);previousBottom=r.y+r.h
                assert(f.ui.textHeight(node.Text,node.TextSize,r.w,node.Font=="bold")<=r.h,node.Name.." clips its instructions")
            end
            local hint=rect(box.Rules.Hint,rules.w,rules.h)
            assert(hint.y+hint.h<=box.Rules.CanvasSize.Y.Offset and box.Rules.ScrollingEnabled)
            assert(box.Rules.Target.Text:find(mode=="long" and "5 из 6" or "3 из 4",1,true))
            ready.action();assert(taps==1)
          end
        end
    end
end)
test("Presentation mounts a locked briefing without starting a reveal, while start remains retryable",function()
    local source=fs.readFile("src/client/GamePresentation.luau")
    local first=assert(source:find("        if session.awaitingReady then",1,true))
    local last=assert(source:find("\n    end\n    function controller.setLocked",first,true))
    local lockStart=assert(source:find("    function controller.setLocked",last,true))
    local lockEnd=assert(source:find("    local function releasePreview",lockStart,true))
    local f=Harness.new(390,650)
    local briefing=f.module("src/client/DateBriefing.luau",{Remix=Remix,Locations=Locations})
    local controller={buttons={{},{},{},{}}};local cue={Visible=true};local revealing=false
    luau.load(source:sub(first,last-1).."\n"..source:sub(lockStart,lockEnd-1),{environment={
        session={awaitingReady=true,stage=3,locationId="park",token="t",step=1},controller=controller,
        root=f.root,cue=cue,Briefing=briefing,w=f.logical.width,h=f.logical.height,mobile=f.logical.mobile,
        options={revealing=function(value)revealing=value end,ready=function()end},
    }})()
    assert(revealing and controller.revealing and not cue.Visible and controller.readyButton)
    controller.setLocked(false)
    for _,button in controller.buttons do assert(not button.Active and not button.Selectable) end
    assert(controller.readyButton.Active and controller.readyButton.Selectable)
    controller.setLocked(true);assert(not controller.readyButton.Active and controller.readyButton.Text=="Подключаемся…")
    controller.setLocked(false);assert(controller.readyButton.Active and controller.readyButton.Text=="Начать →")
end)
fs.writeFile("prototype/evidence/date-briefing-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production briefing geometry and controller wiring; controlled instances, no Roblox rendering"},true))
print("Passed "..#tests.." date briefing checks")
