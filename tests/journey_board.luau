local Harness=require("./support/ui_harness")
local Logic=require("../src/shared/GameLogic")
local Catalog=require("../src/shared/Catalog")
local Locations=require("../src/shared/Locations")
local Ideas=require("../src/shared/JourneyIdeas")
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local roblox=require("@lune/roblox")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local character=Catalog[1]
local state={album={{key=character.id..":classic",characterId=character.id,variantId="classic",locationId="park",scores={}}},matches={}}
local suggestions=Ideas.build(state)
local rect=Harness.rect
test("Actual idea cards show their progress and keep all actions accessible on compact screens",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}} do
        local f=Harness.new(screen[1],screen[2]);local chosen={};local disposed=0;local mounts=0
        local icons=f.module("src/client/ToyIcons.luau")
        local board=f.module("src/client/JourneyBoard.luau",{Logic=Logic,Locations=Locations,Icons=icons})
        local options=f.options();options.scrollPosition=roblox.Vector2.new(0,80)
        options.choose=function(idea)table.insert(chosen,idea)end;options.back=function()end
        options.mount=function()mounts+=1;return{dispose=function()disposed+=1 end}end
        local controller=board.mount(f.root,suggestions,options);local box=controller.frame
        local w,h=box.Size.X.Offset,box.Size.Y.Offset
        assert(w*f.logical.scale<=screen[1] and h<=f.logical.height)
        local list,close=rect(box.Ideas,w,h),rect(box.CloseIdeas,w,h)
        assert(list.h>100 and list.y+list.h+8<=close.y and close.h*f.logical.scale>=44)
        local previousBottom=0
        for _,idea in suggestions do
            local card=box.Ideas["Idea_"..idea.kind];local r=rect(card,list.w,list.h)
            assert(r.x>=0 and r.x+r.w<=list.w and r.y+r.h<=box.Ideas.CanvasSize.Y.Offset)
            if f.logical.mobile then assert(r.y>=previousBottom);previousBottom=r.y+r.h end
            local previous=0
            for _,name in {"Title","Preview","Character","Note","ProgressBar","Progress","ChooseIdea"} do
                local child=card[name]
                if not child then continue end
                local bounds=rect(child,r.w,r.h)
                assert(bounds.y>=previous and bounds.y+bounds.h<=r.h,name)
                previous=bounds.y+bounds.h
            end
            local button=rect(card.ChooseIdea,r.w,r.h)
            assert(button.h*f.logical.scale>=44 and button.w*f.logical.scale>=44)
            card.ChooseIdea.action()
            if idea.total then assert(math.abs(card.ProgressBar.Fill.Size.X.Scale-idea.progress/idea.total)<1e-6)end
        end
        assert(#chosen==#suggestions and chosen[1]==suggestions[1] and box.Ideas.CanvasPosition.Y==80)
        controller.dispose();controller.dispose();assert(disposed==mounts)
    end
end)
test("Client idea choices route to the requested stage, place and remix only after a click",function()
    local source=fs.readFile("src/client/App.client.luau")
    local first=assert(source:find("showIdeas = function(",1,true))
    local last=assert(source:find("showStory = function(",first,true))
    local f={games={},tabs={},photos={},closed=0}
    local client=luau.load([[
        local showIdeas,modal,modalViewer,modalRebuild
        local busy=false
    ]]..source:sub(first,last-1)..[[
        return {open=showIdeas,busy=function(value)busy=value end,rebuild=function()modalRebuild()end}
    ]],{environment={
        state=state,JourneyIdeas=Ideas,mobile=true,height=760,UI={availableWidth=700,overlay=function()return{}end},
        closeModal=function()f.closed+=1 end,Feedback={pop=function()end},
        JourneyBoard={mount=function(_,_,options)f.options=options;return{frame={}}end},
        startGame=function(...)table.insert(f.games,table.pack(...))end,
        nav=function(tab)table.insert(f.tabs,tab)end,
        showPhotoStudio=function(key)table.insert(f.photos,key)end,
    }})()
    client.open();assert(#f.games==0 and #f.tabs==0 and #f.photos==0)
    f.options.choose({kind="continue",key="one"})
    f.options.choose({kind="travel",key="two",locationId="rooftop"})
    f.options.choose({kind="remix",key="three",locationId="cafe",remixId="reverse"})
    f.options.choose({kind="perfect",key="four",practiceStage=2})
    assert(f.games[1].n==1 and f.games[1][1]=="one")
    assert(f.games[2][2]==3 and f.games[2][3]=="rooftop")
    assert(f.games[3][2]==3 and f.games[3][3]=="cafe" and f.games[3][4]=="reverse")
    assert(f.games[4][1]=="four" and f.games[4][2]==2)
    f.options.choose({kind="photo",key="five"});f.options.choose({kind="discover"});f.options.choose({kind="inbox"})
    assert(f.photos[1]=="five" and f.tabs[1]=="feed" and f.tabs[2]=="matches")
    client.busy(true);f.options.choose({kind="continue",key="no"});assert(#f.games==4)
    f.options.scrolled({Y=240});client.rebuild();assert(f.options.scrollPosition.Y==240)
end)
fs.writeFile("prototype/evidence/journey-board-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production idea board geometry and route callbacks; controlled scene/UI, no live game test"},true))
print("Passed "..#tests.." journey board checks")
